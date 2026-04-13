import 'package:flutter/material.dart';
import '../config/game_config.dart';

class AnimatedInstructionBanner extends StatefulWidget {
  final String instruction;
  final int durationInSeconds;
  final String lastResult; // New parameter to drive the flash logic
  final VoidCallback onTimeExpired;

  const AnimatedInstructionBanner({
    super.key,
    required this.instruction,
    required this.durationInSeconds,
    required this.lastResult,
    required this.onTimeExpired,
  });

  @override
  State<AnimatedInstructionBanner> createState() => _AnimatedInstructionBannerState();
}

class _AnimatedInstructionBannerState extends State<AnimatedInstructionBanner> with TickerProviderStateMixin {
  late AnimationController _timerController;
  late Animation<Color?> _timerColorAnimation;

  // Controller for the Success/Fail flash
  late AnimationController _flashController;
  late Animation<double> _flashOpacity;
  Color _flashColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _setupTimer();
    _setupFlash();
  }

  void _setupTimer() {
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationInSeconds),
    );

    _timerColorAnimation = TweenSequence<Color?>(
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
    ).animate(_timerController);

    _timerController.reverse(from: 1.0);

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        // Note: The InstructionService now handles signaling 'fail' to the DB,
        // which triggers the flash via didUpdateWidget.
        widget.onTimeExpired();
      }
    });
  }

  void _setupFlash() {
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: GameConfig.feedbackAnimationMs),
    );

    // Creates two flashes (0 -> 1 -> 0 -> 1 -> 0)
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_flashController);
  }

  void _triggerFlash(Color color) {
    setState(() => _flashColor = color);
    _flashController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(AnimatedInstructionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 1. Trigger Flash based on the 'lastResult' signal from InstructionService
    if (oldWidget.lastResult != widget.lastResult) {
      if (widget.lastResult == 'success') {
        _timerController.stop(); // Stop the countdown during success flash
        _triggerFlash(Colors.green);
      } else if (widget.lastResult == 'fail') {
        _timerController.stop(); // Stop the countdown during fail flash
        _triggerFlash(Colors.red);
      } else if (widget.lastResult == 'none' && oldWidget.lastResult != 'none') {
        // If we transitioned back to 'none' but the instruction is still the same, 
        // you could resume here, but usually, a new instruction follows immediately.
      }
    }

    // 2. Handle standard instruction/timer reset
    if (oldWidget.instruction != widget.instruction) {
      _timerController.duration = Duration(seconds: widget.durationInSeconds);
      _timerController.reverse(from: 1.0);
    }
  }

  @override
  void dispose() {
    _timerController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_timerController, _flashController]),
      builder: (context, child) {
        return Stack(
          children: [
            // 1. Dark Background
            Container(
              width: double.infinity,
              height: 75,
              color: Colors.grey.shade900,
            ),

            // 2. Shrinking Progress Bar
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _timerController.value,
                child: Container(
                  height: 75,
                  color: _timerColorAnimation.value,
                ),
              ),
            ),

            // 3. The Flash Overlay (Success/Fail)
            Opacity(
              opacity: _flashOpacity.value,
              child: Container(
                width: double.infinity,
                height: 75,
                color: _flashColor,
              ),
            ),

            // 4. The Instruction Text
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