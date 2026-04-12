enum ControlType { toggle, slider, button, dial, choice, sequence, }

class GameControl {
  final String id;
  final ControlType type;
  final String label;
  double value;
  final String onAction;
  final String offAction;
  final double min;
  final double max;
  final double step;
  final String unit; 
  final String ownerId;
  final List<String>? options; // NEW: Holds non-numerical labels

  GameControl({
    required this.id,
    required this.type,
    required this.label,
    this.value = 0.0,
    this.onAction = 'Turn On',
    this.offAction = 'Turn Off',
    this.min = 0.0,
    this.max = 1.0,
    this.step = 0.1,
    this.unit = '',
    this.ownerId = '',
    this.options, // Added to constructor
  });
}