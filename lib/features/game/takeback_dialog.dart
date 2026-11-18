import 'dart:async';
import 'package:flutter/material.dart';

/// Non-intrusive Takeback Request Dialog with 15-second auto-dismiss.
class TakebackDialog extends StatefulWidget {
  final String requesterName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const TakebackDialog({
    super.key,
    required this.requesterName,
    required this.onAccept,
    required this.onDecline,
  });

  /// Displays the takeback dialog as an alert or sheet.
  static Future<bool?> show(
    BuildContext context, {
    required String requesterName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TakebackDialog(
        requesterName: requesterName,
        onAccept: () => Navigator.of(ctx).pop(true),
        onDecline: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  State<TakebackDialog> createState() => _TakebackDialogState();
}

class _TakebackDialogState extends State<TakebackDialog> {
  int _secondsLeft = 15;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        widget.onDecline();
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF45475A)),
      ),
      title: const Row(
        children: [
          Icon(Icons.undo, color: Color(0xFFF9E2AF)),
          SizedBox(width: 10),
          Text(
            'Takeback Request',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFCDD6F4),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.requesterName} is requesting to take back their last move.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFBAC2DE),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Auto-declining in $_secondsLeft seconds...',
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Color(0xFF6C7086),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onDecline,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFF38BA8),
          ),
          child: const Text('Decline'),
        ),
        ElevatedButton(
          onPressed: widget.onAccept,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA6E3A1),
            foregroundColor: const Color(0xFF11111B),
          ),
          child: const Text('Accept'),
        ),
      ],
    );
  }
}
