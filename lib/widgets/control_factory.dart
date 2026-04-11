import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_control.dart';

Widget controlFactory(
  GameControl control, 
  Function(double) onChanged, 
  Function(double) onCommitted,
) {
  switch (control.type) {
    case ControlType.toggle:
      return SwitchListTile(
        title: Text(control.label),
        value: control.value > 0,
        onChanged: (val) {
          double numVal = val ? 1.0 : 0.0;
          onChanged(numVal);
          onCommitted(numVal);
        },
      );

    case ControlType.slider:
    case ControlType.dial:
      String displayVal;
      if (control.options != null && control.options!.isNotEmpty) {
        int index = control.value.round().clamp(0, control.options!.length - 1);
        displayVal = control.options![index];
      } else {
        displayVal = control.value == control.value.truncateToDouble() 
            ? control.value.toInt().toString() 
            : control.value.toString();
        displayVal = "$displayVal${control.unit}";
      }

      if (control.type == ControlType.slider) {
        int divisions = ((control.max - control.min) / control.step).round();
        return Column(
          children: [
            Text('${control.label} ($displayVal)'),
            Slider(
              value: control.value.clamp(control.min, control.max),
              min: control.min,
              max: control.max,
              divisions: divisions > 0 ? divisions : null,
              label: displayVal,
              onChanged: onChanged,
              onChangeEnd: onCommitted,
            ),
          ],
        );
      } else {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            children: [
              Text('${control.label} ($displayVal)'),
              const SizedBox(height: 8),
              RotaryDial(
                value: control.value.clamp(control.min, control.max),
                min: control.min,
                max: control.max,
                step: control.step,
                options: control.options, // Pass the options down to the dial
                onChanged: onChanged,
                onCommitted: onCommitted,
              ),
            ],
          ),
        );
      }

    case ControlType.button:
      return ElevatedButton(
        onPressed: () {
          onChanged(1.0);
          onCommitted(1.0);
        },
        child: Text(control.label),
      );

    default:
      return const SizedBox.shrink();
  }
}

class RotaryDial extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final List<String>? options;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onCommitted;

  const RotaryDial({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    this.options,
    required this.onChanged,
    required this.onCommitted,
  });

  @override
  State<RotaryDial> createState() => _RotaryDialState();
}

class _RotaryDialState extends State<RotaryDial> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant RotaryDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    double sensitivity = (widget.max - widget.min) / 150; 
    double delta = -details.delta.dy + details.delta.dx; 
    
    double rawValue = _currentValue + (delta * sensitivity);
    rawValue = rawValue.clamp(widget.min, widget.max);

    double snappedValue = ((rawValue - widget.min) / widget.step).round() * widget.step + widget.min;

    if (snappedValue != _currentValue) {
      setState(() {
        _currentValue = snappedValue;
      });
      widget.onChanged(_currentValue);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    widget.onCommitted(_currentValue);
  }

  @override
  Widget build(BuildContext context) {
    double normalized = (_currentValue - widget.min) / (widget.max - widget.min);
    double angle = (-135 + (normalized * 270)) * (pi / 180);

    const double dialSize = 100.0;
    const double boxSize = 220.0; // Total bounding box for the dial and text
    const double radius = dialSize / 2 + 35.0; // Distance from center to text

    List<Widget> children = [];

    // 1. Draw the labels around the outside if they exist
    if (widget.options != null && widget.options!.isNotEmpty) {
      int numOptions = widget.options!.length;
      int selectedIndex = ((_currentValue - widget.min) / widget.step).round();

      for (int i = 0; i < numOptions; i++) {
        // Calculate the angular sweep for this specific option
        double optNormalized = numOptions > 1 ? i / (numOptions - 1) : 0.0;
        double optAngle = (-135 + (optNormalized * 270)) * (pi / 180);

        // Convert polar coordinates to Cartesian (x,y)
        double x = (boxSize / 2) + radius * sin(optAngle);
        double y = (boxSize / 2) - radius * cos(optAngle);

        bool isSelected = (i == selectedIndex);

        children.add(
          Positioned(
            left: x - 40, // Shift left by half the width to center it on the point
            top: y - 15,  // Shift up by half the height to center it
            width: 80,
            height: 30,
            child: Center(
              child: Text(
                widget.options![i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.orangeAccent : Colors.grey.shade500,
                ),
              ),
            ),
          ),
        );
      }
    }

    // 2. Draw the interactive dial in the exact center
    children.add(
      Align(
        alignment: Alignment.center,
        child: GestureDetector(
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          child: Container(
            width: dialSize,
            height: dialSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade800,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10.0,
                  offset: Offset(4, 4),
                ),
                BoxShadow(
                  color: Colors.white12,
                  blurRadius: 10.0,
                  offset: Offset(-4, -4),
                ),
              ],
            ),
            child: Transform.rotate(
              angle: angle,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 10,
                    child: Container(
                      width: 6,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Stack(
        children: children,
      ),
    );
  }
}