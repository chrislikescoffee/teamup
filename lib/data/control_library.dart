import '../models/game_control.dart';

class ControlLibrary {
  static List<GameControl> laboratoryPool = [
    // Toggles with custom states
    GameControl(id: 'power', type: ControlType.toggle, label: 'Main Power', onAction: 'Engage', offAction: 'Disengage'),
    GameControl(id: 'shield', type: ControlType.toggle, label: 'Radiation Shield', onAction: 'Raise', offAction: 'Lower'),
    GameControl(id: 'coolant', type: ControlType.toggle, label: 'Coolant Pump', onAction: 'Activate', offAction: 'Deactivate'),
    GameControl(id: 'seatbelt', type: ControlType.toggle, label: 'Seatbelt', onAction: 'Fasten', offAction: 'Unfasten'),
    GameControl(id: 'ewok_detector', type: ControlType.toggle, label: 'Ewok Detector', onAction: 'Scaning', offAction: 'Idle'),
    
    // Sliders with specific ranges
    GameControl(id: 'laser', type: ControlType.slider, label: 'Laser Intensity', min: 0, max: 100, step: 10, unit: '%'),
    GameControl(id: 'temp', type: ControlType.slider, label: 'Thruster Temperature', min: 500, max: 1000, step: 50, unit: '°C'),
    GameControl(id: 'pressure', type: ControlType.slider, label: 'Steam Pressure', min: 0, max: 500, step: 100, unit: 'kPa'),
    GameControl(id: 'gravity', type: ControlType.slider, label: 'Gravity Level', min: 0, max: 2, step: 0.5, unit: 'G'),
    
    // Buttons
    GameControl(id: 'vent_pressure', type: ControlType.button, label: 'Pressure Vent', onAction: 'Release'),
    GameControl(id: 'flush_toilet', type: ControlType.button, label: 'Flush Toilet', onAction: 'Flush'),
    GameControl(id: 'pop_toaster', type: ControlType.button, label: 'Toast Popper', onAction: 'Raise'),
    GameControl(id: 'Acknowledge_warnings', type: ControlType.button, label: 'Warnings', onAction: 'Acknowledge'),

    // Dials
    GameControl(id: 'frequency', type: ControlType.dial, label: 'Signal Frequency', min: 80, max: 120, step: 1, unit: ' MHz'),
    GameControl(id: 'voltage', type: ControlType.dial, label: 'Grid Voltage', min: 0, max: 240, step: 20, unit: 'V'),
    GameControl(id: 'radio_volume', type: ControlType.dial, label: 'Radio Volume', min: 1, max: 11, step: 1, unit: 'Loudness'),

    // Compass Dial
    GameControl(
      id: 'navigation', 
      type: ControlType.dial, 
      label: 'Navigation Heading', 
      min: 0, 
      max: 7, 
      step: 1, 
      options: ['North', 'North-East', 'East', 'South-East', 'South', 'South-West', 'West', 'North-West'],
    ),
  ];
}