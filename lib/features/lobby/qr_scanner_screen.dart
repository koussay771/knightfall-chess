import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants/theme_constants.dart';

/// Standalone QR scanner screen with robust lifecycle management,
/// camera permission error handling, and clean restart capability.
///
/// Implements [WidgetsBindingObserver] so the camera pauses on
/// app backgrounding and resumes on return — preventing black-screen issues.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _cameraError = false;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      returnImage: false,
    );
    _startCamera();
  }

  Future<void> _startCamera() async {
    try {
      await _controller.start();
      if (mounted) setState(() => _cameraError = false);
    } catch (e) {
      if (mounted) setState(() => _cameraError = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _controller.stop();
        break;
      case AppLifecycleState.resumed:
        _startCamera();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _hasScanned = true;
        _controller.stop();
        // Return the raw QR value to the caller.
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

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
          IconButton(
            icon: const Icon(Icons.flash_on, color: AppColors.textSecondary),
            tooltip: 'Toggle flash',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: _cameraError ? _buildError() : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) {
            // If the scanner reports an error (e.g. permission denied post-build),
            // switch to the error UI immediately.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _cameraError = true);
            });
            return _buildError();
          },
        ),
        // Scan overlay frame
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.neonGreen,
                width: 2.5,
              ),
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
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined,
                size: 64, color: AppColors.textDim),
            const SizedBox(height: 20),
            const Text(
              'Camera Unavailable',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Camera permission was denied or the camera failed to initialise.'
              '\nGrant permission in device Settings and retry.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Camera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonGreen,
                foregroundColor: AppColors.bg0,
              ),
              onPressed: () {
                setState(() {
                  _cameraError = false;
                  _hasScanned = false;
                });
                _startCamera();
              },
            ),
          ],
        ),
      ),
    );
  }
}
