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

    case ControlType.sequence:
      return _SequencePad(
        control: control,
        onChanged: onChanged,
        onComplete: onCommitted,
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
            : control.value.toStringAsFixed(1);
        displayVal = "$displayVal${control.unit}";
      }

      if (control.type == ControlType.slider) {
        int divisions = ((control.max - control.min) / control.step).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${control.label} ($displayVal)', style: const TextStyle(fontWeight: FontWeight.bold)),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${control.label} ($displayVal)', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              RotaryDial(
                value: control.value.clamp(control.min, control.max),
                min: control.min,
                max: control.max,
                step: control.step,
                options: control.options,
                onChanged: onChanged,
                onCommitted: onCommitted,
              ),
            ],
          ),
        );
      }

    case ControlType.choice:
      final List<String> options = control.options ?? [];
      int selectedIndex = control.value.toInt().clamp(0, options.length - 1);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(control.label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(options.length, (index) {
              bool isSelected = selectedIndex == index;
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.orangeAccent : Colors.grey.shade800,
                  foregroundColor: isSelected ? Colors.black : Colors.white,
                ),
                onPressed: () {
                  double indexAsValue = index.toDouble();
                  onChanged(indexAsValue);
                  onCommitted(indexAsValue);
                },
                child: Text(options[index]),
              );
            }),
          ),
        ],
      );

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
    double normalized = (widget.max - widget.min) == 0 ? 0 : (_currentValue - widget.min) / (widget.max - widget.min);
    double angle = (-135 + (normalized * 270)) * (pi / 180);

    const double dialSize = 100.0;
    const double boxSize = 220.0;
    const double radius = dialSize / 2 + 35.0;

    List<Widget> children = [];

    if (widget.options != null && widget.options!.isNotEmpty) {
      int numOptions = widget.options!.length;
      int selectedIndex = ((_currentValue - widget.min) / widget.step).round();

      for (int i = 0; i < numOptions; i++) {
        double optNormalized = numOptions > 1 ? i / (numOptions - 1) : 0.0;
        double optAngle = (-135 + (optNormalized * 270)) * (pi / 180);

        double x = (boxSize / 2) + radius * sin(optAngle);
        double y = (boxSize / 2) - radius * cos(optAngle);

        bool isSelected = (i == selectedIndex);

        children.add(
          Positioned(
            left: x - 40,
            top: y - 15,
            width: 80,
            height: 30,
            child: Center(
              child: Text(
                widget.options![i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.orangeAccent : Colors.grey.shade500,
                ),
              ),
            ),
          ),
        );
      }
    }

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
                BoxShadow(color: Colors.black54, blurRadius: 10.0, offset: Offset(4, 4)),
                BoxShadow(color: Colors.white12, blurRadius: 10.0, offset: Offset(-4, -4)),
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

class _SequencePad extends StatefulWidget {
  final GameControl control;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onComplete;

  const _SequencePad({
    required this.control, 
    required this.onChanged, 
    required this.onComplete
  });

  @override
  State<_SequencePad> createState() => _SequencePadState();
}

class _SequencePadState extends State<_SequencePad> {
  String _currentInput = "";

  @override
  void didUpdateWidget(covariant _SequencePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // IF THE TARGET VALUE IN THE DATABASE CHANGES:
    // This means the InstructionService has acknowledged a success 
    // and assigned a new task. We should clear the pad now.
    if (oldWidget.control.value != widget.control.value) {
      setState(() {
        _currentInput = "";
      });
    }
  }

  void _handleTap(String char, int index) {
    setState(() {
      _currentInput += (index + 1).toString();
    });

    // We calculate the length of the code we are currently typing towards
    int targetLength = widget.control.value.toInt().toString().length;
    if (targetLength < 3) targetLength = 3; 

    // Once we reach the length, we submit it for verification
    if (_currentInput.length >= targetLength) {
      try {
        double val = double.parse(_currentInput);
        widget.onChanged(val);
        widget.onComplete(val);
        
        // AUTO-RESET REMOVED FROM HERE:
        // We no longer clear here. If the code is wrong, it stays on screen.
        // If it is correct, 'didUpdateWidget' will catch the change and clear it.
      } catch (e) {
        debugPrint("Error parsing sequence: $e");
      }
    }
  }

  void _clearInput() {
    setState(() {
      _currentInput = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> keypadChars = widget.control.options ?? ['1', '2', '3', '4'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.control.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 48), 
            Expanded(
              child: Text(
                _currentInput.isEmpty ? "READY" : _currentInput.split('').map((char) {
                  int idx = int.parse(char) - 1;
                  return keypadChars[idx];
                }).join(' '),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.orange, 
                  letterSpacing: 4, 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.backspace_outlined, color: Colors.redAccent, size: 20),
              onPressed: _currentInput.isEmpty ? null : _clearInput,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 160, 
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: keypadChars.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: keypadChars.length > 4 ? 3 : 2, 
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade800,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _handleTap(keypadChars[index], index),
                child: Text(keypadChars[index], style: const TextStyle(fontSize: 18)),
              );
            },
          ),
        ),
      ],
    );
  }
}