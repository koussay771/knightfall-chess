import 'package:flutter/material.dart';

/// High-precision Chess Clock widget.
class ClockWidget extends StatelessWidget {
  final int timeMs;
  final bool isActive;
  final bool isUnlimited;
  final String playerName;
  final bool isWhite;

  const ClockWidget({
    super.key,
    required this.timeMs,
    required this.isActive,
    this.isUnlimited = false,
    required this.playerName,
    required this.isWhite,
  });

  @override
  Widget build(BuildContext context) {
    final isLowTime = !isUnlimited && timeMs <= 30000 && timeMs > 0;
    final isExpired = !isUnlimited && timeMs <= 0;

    Color backgroundColor;
    Color textColor;
    Color borderColor;

    if (isExpired) {
      backgroundColor = const Color(0xFFB71C1C);
      textColor = Colors.white;
      borderColor = Colors.redAccent;
    } else if (isLowTime) {
      backgroundColor = isActive ? const Color(0xFF4A1414) : const Color(0xFF2C1010);
      textColor = const Color(0xFFFF5252);
      borderColor = const Color(0xFFFF5252);
    } else if (isActive) {
      backgroundColor = const Color(0xFF2E382E);
      textColor = const Color(0xFF81C784);
      borderColor = const Color(0xFF66BB6A);
    } else {
      backgroundColor = const Color(0xFF1E1E2E);
      textColor = const Color(0xFFB0BEC5);
      borderColor = Colors.transparent;
    }

    final formattedTime = _formatTime(timeMs, isUnlimited);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: isActive ? 2.0 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: borderColor.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player indicator icon
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isWhite ? Colors.white : Colors.black,
              border: Border.all(
                color: isWhite ? Colors.black45 : Colors.white60,
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Player name
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              playerName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor.withOpacity(0.9),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Clock digits
          Text(
            formattedTime,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(int ms, bool unlimited) {
    if (unlimited) return '∞';
    if (ms <= 0) return '0:00';

    final totalSeconds = (ms / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remMinutes = minutes % 60;
      return '$hours:${remMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    // Under 10 seconds: show tenth of seconds if desired e.g. 9.4s
    if (totalSeconds < 10 && ms > 0) {
      final tenths = (ms % 1000) ~/ 100;
      return '$seconds.$tenths';
    }

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
