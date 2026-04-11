import 'dart:math';
import '../models/game_control.dart';
import 'firebase_service.dart';

class InstructionService {
  final FirebaseService _firebaseService = FirebaseService();
  final Random _random = Random();

  Future<void> handleInstructionTimeout(String sessionId, String playerId, List<GameControl> activeControls, Map<dynamic, dynamic> playersData) async {
    print('\n=========================================');
    print('TIMEOUT: Player $playerId missed instruction!');
    print('=========================================\n');
    
    await _firebaseService.incrementMissedCount(sessionId);
    await generateInstructionForPlayer(sessionId, playerId, activeControls, playersData);
  }

  Future<void> verifyInteraction({
    required String sessionId,
    required GameControl control,
    required double newValue,
    required Map<dynamic, dynamic> playersData, 
    required List<GameControl> allRoomControls,
  }) async {
    
    _firebaseService.updateControl(sessionId, control.id, newValue);

    List<String> completedPlayerIds = [];

    playersData.forEach((playerId, data) {
      if (data is Map) {
        String tId = data['target_id']?.toString() ?? '';
        double tVal = (data['target_value'] as num? ?? -1).toDouble();

        if (control.id == tId && (newValue - tVal).abs() < 0.001) {
          completedPlayerIds.add(playerId.toString());
        }
      }
    });

    if (completedPlayerIds.isNotEmpty) {
      for (String pId in completedPlayerIds) {
        print('\n=========================================');
        print('SUCCESS: Instruction completed for Player $pId!');
        print('=========================================\n');
        
        await generateInstructionForPlayer(
          sessionId, 
          pId, 
          allRoomControls, 
          playersData, // Pass active players
          completedControlId: control.id,
        );
      }
    } else {
      print('INCIDENTAL: Interacted with ${control.label} (Value: $newValue)');
    }
  }

  Future<void> generateInstructionForPlayer(
    String sessionId, 
    String playerId,
    List<GameControl> allRoomControls, 
    Map<dynamic, dynamic> playersData, // NEW: Required to filter ghost controls
    {String? completedControlId}
  ) async {
    if (allRoomControls.isEmpty) return;

    // FILTER: Only look at controls whose owner is currently in the players list
    List<GameControl> validControls = allRoomControls.where((c) => playersData.containsKey(c.ownerId)).toList();
    if (validControls.isEmpty) return; // Failsafe if everyone left

    final freshControls = await _firebaseService.getRoomControls(sessionId);
    
    List<GameControl> availableControls = validControls.where((c) => c.id != completedControlId).toList();
    if (availableControls.isEmpty) availableControls = validControls;

    if (freshControls != null) {
      for (var c in availableControls) {
        if (freshControls[c.id] != null) {
          c.value = (freshControls[c.id]['value'] as num? ?? 0).toDouble();
        }
      }
    }

    List<GameControl> selfControls = availableControls.where((c) => c.ownerId == playerId).toList();
    List<GameControl> teamControls = availableControls.where((c) => c.ownerId != playerId).toList();

    GameControl? targetControl;
    
    if (_random.nextDouble() < 0.30 && selfControls.isNotEmpty) {
      targetControl = selfControls[_random.nextInt(selfControls.length)];
    } else if (teamControls.isNotEmpty) {
      targetControl = teamControls[_random.nextInt(teamControls.length)];
    } else {
      targetControl = selfControls[_random.nextInt(selfControls.length)];
    }

    String text = "";
    double targetValue = 0.0;

    switch (targetControl.type) {
      case ControlType.toggle:
        bool isCurrentlyOn = targetControl.value >= 0.5;
        targetValue = isCurrentlyOn ? 0.0 : 1.0;
        text = targetValue == 1.0 ? "${targetControl.onAction} ${targetControl.label}" : "${targetControl.offAction} ${targetControl.label}";
        break;



      case ControlType.slider:
      case ControlType.dial:
        double current = targetControl.value;
        double next;
        int totalSteps = ((targetControl.max - targetControl.min) / targetControl.step).round();
        do {
          int randomStep = _random.nextInt(totalSteps + 1);
          next = targetControl.min + (randomStep * targetControl.step);
          next = double.parse(next.toStringAsFixed(2));
        } while ((next - current).abs() < 0.001);
        
        targetValue = next;

        // NEW: Check for string options
        if (targetControl.options != null && targetControl.options!.isNotEmpty) {
          int index = targetValue.round().clamp(0, targetControl.options!.length - 1);
          String optionText = targetControl.options![index];
          text = "Set ${targetControl.label} to $optionText";
        } else {
          String displayValue = targetValue == targetValue.truncateToDouble() ? targetValue.toInt().toString() : targetValue.toStringAsFixed(1);
          text = "Set ${targetControl.label} to $displayValue${targetControl.unit}";
        }
        break;

      case ControlType.button:
        targetValue = 1.0;
        text = "${targetControl.onAction} ${targetControl.label}";
        break;
    }

    await _firebaseService.setPlayerInstruction(
      sessionId, 
      playerId, 
      text, 
      targetControl.id, 
      targetValue
    );
  }
}