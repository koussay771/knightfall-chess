import 'dart:async';
import 'package:flutter/material.dart';

/// Automatically cross-fades between the two lobby background images
/// in `assets/backgound_app` every 30 seconds with a rich dark scrim.
class AnimatedBackgroundSwitcher extends StatefulWidget {
  final Widget child;

  const AnimatedBackgroundSwitcher({
    super.key,
    required this.child,
  });

  @override
  State<AnimatedBackgroundSwitcher> createState() =>
      _AnimatedBackgroundSwitcherState();
}

class _AnimatedBackgroundSwitcherState extends State<AnimatedBackgroundSwitcher>
    with SingleTickerProviderStateMixin {
  static const String _bg1 = 'assets/backgound_app/background1.jpg';
  static const String _bg2 = 'assets/backgound_app/background2.jpg';

  late final AnimationController _controller;
  late final Animation<double> _animation;
  Timer? _switchTimer;
  bool _showingFirst = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    // Pre-cache images after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        precacheImage(const AssetImage(_bg1), context);
        precacheImage(const AssetImage(_bg2), context);
      }
    });

    // Start 30-second cycle
    _switchTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) return;
      if (_showingFirst) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      setState(() {
        _showingFirst = !_showingFirst;
      });
    });
  }

  @override
  void dispose() {
    _switchTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background 1 (Base layer)
        Image.asset(
          _bg1,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF0E141C)),
        ),

        // Background 2 (Cross-fade layer on top)
        FadeTransition(
          opacity: _animation,
          child: Image.asset(
            _bg2,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),

        // Dark charcoal overlay ensuring crisp HUD text & cards contrast
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xD90D0D11), // 85% opacity dark
                  Color(0xF2090D14), // 95% opacity deep dark
                ],
              ),
            ),
          ),
        ),

        // Foreground content (Lobby UI)
        widget.child,
      ],
    );
  }
}
