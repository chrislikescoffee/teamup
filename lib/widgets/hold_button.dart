// lib/widgets/hold_button.dart
import 'package:flutter/material.dart';
import '../config/game_config.dart';

class HoldButton extends StatefulWidget {
  final String label;
  final Color meterColor;
  final VoidCallback onComplete;

  const HoldButton({
    super.key,
    required this.label,
    this.meterColor = Colors.cyanAccent,
    required this.onComplete,
  });

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: GameConfig.buttonHoldMs),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
        _reset();
      }
    });
  }

  void _reset() {
    setState(() => _isPressed = false);
    _controller.reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) => _reset(),
      onTapCancel: () => _reset(),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              children: [
                // The Filling Meter
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return FractionallySizedBox(
                      widthFactor: _controller.value,
                      child: Container(color: widget.meterColor.withOpacity(0.4)),
                    );
                  },
                ),
                // Bottom progress line for extra visual feedback
                Align(
                  alignment: Alignment.bottomLeft,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Container(
                        height: 4,
                        width: MediaQuery.of(context).size.width * _controller.value,
                        color: widget.meterColor,
                      );
                    },
                  ),
                ),
                // Button Text
                Center(
                  child: Text(
                    widget.label.toUpperCase(),
                    style: TextStyle(
                      color: _isPressed ? widget.meterColor : Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}