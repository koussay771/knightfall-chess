import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/theme_constants.dart';

/// QR scanner screen with full runtime permission lifecycle:
///   - Requests CAMERA permission before starting the scanner.
///   - Distinguishes "denied once" (show Retry) from "permanently denied /
///     never-ask-again" (show Open Settings).
///   - On retry: fully disposes and recreates the MobileScannerController so
///     the camera actually reinitialises rather than replaying the cached error.
///   - Pauses camera on app background, resumes on foreground.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

enum _CameraState { checking, denied, permanentlyDenied, ready, error }

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  _CameraState _cameraState = _CameraState.checking;
  bool _hasScanned = false;
  String _errorDetail = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  // ── Permission + camera initialisation ─────────────────────────────────────

  Future<void> _initCamera() async {
    if (!mounted) return;
    setState(() => _cameraState = _CameraState.checking);

    final status = await Permission.camera.status;

    if (status.isGranted) {
      await _startController();
      return;
    }

    if (status.isPermanentlyDenied) {
      if (mounted) setState(() => _cameraState = _CameraState.permanentlyDenied);
      return;
    }

    // Not yet asked or denied once — request now.
    final result = await Permission.camera.request();

    if (!mounted) return;

    if (result.isGranted) {
      await _startController();
    } else if (result.isPermanentlyDenied) {
      setState(() => _cameraState = _CameraState.permanentlyDenied);
    } else {
      setState(() => _cameraState = _CameraState.denied);
    }
  }

  Future<void> _startController() async {
    // Dispose any stale controller before creating a new one.
    // This is essential: MobileScannerController v5 caches the previous error
    // state internally and will never recover without full recreation.
    await _disposeController();

    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      returnImage: false,
    );
    _controller = controller;

    try {
      await controller.start();
      if (mounted) setState(() => _cameraState = _CameraState.ready);
    } catch (e) {
      _errorDetail = e.toString();
      if (mounted) setState(() => _cameraState = _CameraState.error);
    }
  }

  Future<void> _disposeController() async {
    final old = _controller;
    _controller = null;
    if (old != null) {
      try {
        await old.stop();
      } catch (_) {}
      try {
        old.dispose();
      } catch (_) {}
    }
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _controller?.stop();
        break;
      case AppLifecycleState.resumed:
        // Only restart if we were in a good state before backgrounding.
        if (_cameraState == _CameraState.ready) {
          _controller?.start();
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  // ── Detection ───────────────────────────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _hasScanned = true;
        _controller?.stop();
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        title: const Text('Scan Host QR Code'),
        backgroundColor: AppColors.bg0,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_cameraState == _CameraState.ready)
            IconButton(
              icon: const Icon(Icons.flash_on, color: AppColors.textSecondary),
              tooltip: 'Toggle flash',
              onPressed: () => _controller?.toggleTorch(),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_cameraState) {
      case _CameraState.checking:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.neonGreen),
              SizedBox(height: 16),
              Text('Requesting camera access…',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        );

      case _CameraState.ready:
        final ctrl = _controller;
        if (ctrl == null) return _buildErrorCard();
        return Stack(
          children: [
            MobileScanner(
              controller: ctrl,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _errorDetail = error.errorDetails?.message ?? '';
                    setState(() => _cameraState = _CameraState.error);
                  }
                });
                return _buildErrorCard();
              },
            ),
            // Scan frame overlay
            Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neonGreen, width: 2.5),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Point at the Host QR code',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        );

      case _CameraState.denied:
        return _buildPermissionCard(
          icon: Icons.no_photography_outlined,
          title: 'Camera Permission Required',
          message:
              'Camera access is needed to scan the host QR code.\n'
              'Tap Retry to grant permission.',
          primaryLabel: 'Retry',
          primaryIcon: Icons.refresh,
          onPrimary: _initCamera,
          secondaryLabel: null,
          onSecondary: null,
        );

      case _CameraState.permanentlyDenied:
        return _buildPermissionCard(
          icon: Icons.block_outlined,
          title: 'Camera Access Blocked',
          message:
              'Camera permission was permanently denied.\n'
              'Open device Settings and enable Camera for this app.',
          primaryLabel: 'Open Settings',
          primaryIcon: Icons.settings_outlined,
          onPrimary: () async {
            await openAppSettings();
            // After returning from Settings, re-check permission state.
            if (mounted) _initCamera();
          },
          secondaryLabel: null,
          onSecondary: null,
        );

      case _CameraState.error:
        return _buildErrorCard();
    }
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String message,
    required String primaryLabel,
    required IconData primaryIcon,
    required VoidCallback onPrimary,
    required String? secondaryLabel,
    required VoidCallback? onSecondary,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textDim),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: Icon(primaryIcon),
              label: Text(primaryLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonGreen,
                foregroundColor: AppColors.bg0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onPrimary,
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onSecondary,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Text(secondaryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return _buildPermissionCard(
      icon: Icons.camera_alt_outlined,
      title: 'Camera Unavailable',
      message: _errorDetail.isNotEmpty
          ? 'Camera failed to start: $_errorDetail\n\nRetry or check Settings.'
          : 'The camera failed to initialise.\nRetry or grant camera permission in Settings.',
      primaryLabel: 'Retry Camera',
      primaryIcon: Icons.refresh,
      onPrimary: _initCamera,
      secondaryLabel: 'Open Settings',
      onSecondary: () async {
        await openAppSettings();
        if (mounted) _initCamera();
      },
    );
  }
}
