import 'package:flutter/material.dart';

class AnimatedInstructionBanner extends StatefulWidget {
  final String instruction;
  final int durationInSeconds;
  final VoidCallback onTimeExpired;

  const AnimatedInstructionBanner({
    super.key,
    required this.instruction,
    required this.durationInSeconds,
    required this.onTimeExpired,
  });

  @override
  State<AnimatedInstructionBanner> createState() => _AnimatedInstructionBannerState();
}

class _AnimatedInstructionBannerState extends State<AnimatedInstructionBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  void _setupAnimation() {
    // The controller governs the total time
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationInSeconds),
    );

    // This sequence maps the controller's value (0.0 to 1.0) to specific colors.
    // Since we are running the animation in reverse (1.0 down to 0.0), 
    // it starts at green, hits orange in the middle, and ends at red.
    _colorAnimation = TweenSequence<Color?>(
      [
        TweenSequenceItem(
          weight: 1.0,
          tween: ColorTween(begin: Colors.redAccent, end: Colors.orangeAccent),
        ),
        TweenSequenceItem(
          weight: 1.0,
          tween: ColorTween(begin: Colors.orangeAccent, end: Colors.greenAccent),
        ),
      ],
    ).animate(_controller);

    // Start the countdown
    _controller.reverse(from: 1.0);

    // Listen for when the timer hits zero
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        widget.onTimeExpired();
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedInstructionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If Firebase sends a new instruction, or the difficulty/duration changes, reset the bar
    if (oldWidget.instruction != widget.instruction || oldWidget.durationInSeconds != widget.durationInSeconds) {
      _controller.duration = Duration(seconds: widget.durationInSeconds);
      _controller.reverse(from: 1.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // 1. The empty background track (dark grey)
            Container(
              width: double.infinity,
              height: 75,
              color: Colors.grey.shade900,
            ),
            // 2. The shrinking colored progress bar
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _controller.value,
                child: Container(
                  height: 75,
                  color: _colorAnimation.value,
                ),
              ),
            ),
            // 3. The Instruction Text (layered on top)
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    widget.instruction.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      // Adding a subtle shadow ensures the text is readable against both green and red backgrounds
                      shadows: [
                        Shadow(
                          offset: Offset(1.0, 1.0),
                          blurRadius: 4.0,
                          color: Colors.black87,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}