import 'dart:async';
import 'package:flutter/material.dart';

class RoundTimerBanner extends StatefulWidget {
  final int endTimestamp;
  final int totalDurationMs;
  final VoidCallback onFinished;
  final bool isActive; // Added to control animation state

  const RoundTimerBanner({
    super.key,
    required this.endTimestamp,
    required this.totalDurationMs,
    required this.onFinished,
    this.isActive = true, // Default to true
  });

  @override
  State<RoundTimerBanner> createState() => _RoundTimerBannerState();
}

class _RoundTimerBannerState extends State<RoundTimerBanner> {
  Timer? _timer;
  double _percent = 1.0;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _startCountdown();
    }
  }

  @override
  void didUpdateWidget(RoundTimerBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Start the timer if it was inactive and is now active
    if (widget.isActive && !oldWidget.isActive) {
      _startCountdown();
    } 
    // Cancel the timer if it was active and is now inactive
    else if (!widget.isActive && oldWidget.isActive) {
      _timer?.cancel();
    }
  }

  void _startCountdown() {
    _timer?.cancel(); // Clear existing timer if any
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final remaining = widget.endTimestamp - now;

      if (remaining <= 0) {
        timer.cancel();
        widget.onFinished();
      } else {
        setState(() {
          _percent = (remaining / widget.totalDurationMs).clamp(0.0, 1.0);
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
    return Container(
      height: 30, // Half the height of the standard instruction banner
      width: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          LinearProgressIndicator(
            // If inactive, we show the bar as full (1.0) but static
            value: widget.isActive ? _percent : 1.0,
            backgroundColor: Colors.grey.shade900,
            valueColor: AlwaysStoppedAnimation<Color>(
              _percent > 0.2 ? Colors.cyanAccent : Colors.redAccent,
            ),
            minHeight: 30,
          ),
          const Center(
            child: Text(
              'ROUND PROGRESS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}