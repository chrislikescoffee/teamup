import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/game_control.dart';
import 'firebase_service.dart';

class InstructionService {
  final FirebaseService _firebaseService = FirebaseService();
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://team-up-game-a6449-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();

  final Random _random = Random();

  /// Generates a new random instruction for a specific player based on all controls in the room.
  Future<void> generateInstructionForPlayer(
    String sessionId, 
    String playerId, 
    List<GameControl> allControls, 
    Map<dynamic, dynamic> playersData,
  ) async {
    if (allControls.isEmpty) return;

    // Fetch the current round's duration to ensure internal logic matches the UI
    final snapshot = await _dbRef.child('sessions/$sessionId/instruction_duration').get();
    int duration = (snapshot.value as num? ?? 15).toInt();

    // Select a random control from the global pool
    final targetControl = allControls[_random.nextInt(allControls.length)];
    
    String instructionText = "";
    double targetValue = 0.0;

    // --- COMPLEX INSTRUCTION BUILDER ---
    switch (targetControl.type) {
      case ControlType.toggle:
        targetValue = _random.nextBool() ? 1.0 : 0.0;
        String action = targetValue == 1.0 ? targetControl.onAction : targetControl.offAction;
        instructionText = "TOGGLE ${targetControl.label} TO $action";
        break;

      case ControlType.slider:
        if (targetControl.options != null && targetControl.options!.isNotEmpty) {
          int optIndex = _random.nextInt(targetControl.options!.length);
          targetValue = optIndex.toDouble();
          instructionText = "SLIDE ${targetControl.label} TO ${targetControl.options![optIndex]}";
        } else {
          int steps = ((targetControl.max - targetControl.min) / targetControl.step).round();
          int randomStep = _random.nextInt(steps + 1);
          targetValue = targetControl.min + (randomStep * targetControl.step);
          String displayVal = _formatValue(targetValue);
          instructionText = "ADJUST ${targetControl.label} TO $displayVal${targetControl.unit}";
        }
        break;

      case ControlType.dial:
        if (targetControl.options != null && targetControl.options!.isNotEmpty) {
          int optIndex = _random.nextInt(targetControl.options!.length);
          targetValue = optIndex.toDouble();
          instructionText = "ROTATE ${targetControl.label} TO ${targetControl.options![optIndex]}";
        } else {
          int steps = ((targetControl.max - targetControl.min) / targetControl.step).round();
          int randomStep = _random.nextInt(steps + 1);
          targetValue = targetControl.min + (randomStep * targetControl.step);
          String displayVal = _formatValue(targetValue);
          instructionText = "SET ${targetControl.label} TO $displayVal${targetControl.unit}";
        }
        break;

      case ControlType.button:
        targetValue = 1.0;
        instructionText = "${targetControl.onAction} ${targetControl.label}";
        break;
    }

    await _firebaseService.setPlayerInstruction(
      sessionId, 
      playerId, 
      instructionText.toUpperCase(), 
      targetControl.id, 
      targetValue
    );
  }

  /// Helper to format numbers cleanly for instructions
  String _formatValue(double val) {
    return val == val.truncateToDouble() ? val.toInt().toString() : val.toStringAsFixed(1);
  }

  /// Checks if a physical interaction by any player satisfies any active instruction in the room.
  Future<void> verifyInteraction({
    required String sessionId,
    required GameControl control,
    required double newValue,
    required Map<dynamic, dynamic> playersData,
    required List<GameControl> allRoomControls,
  }) async {
    // We iterate through all players because instructions are collaborative
    for (var entry in playersData.entries) {
      final String targetPlayerId = entry.key.toString();
      final Map data = entry.value as Map;

      // Does this control match the target_id of this player's instruction?
      if (data['target_id'] == control.id) {
        double targetVal = (data['target_value'] as num).toDouble();
        
        // --- PROXIMITY & FUZZY MATCHING ---
        // Sliders and Dials have a small margin of error (epsilon) to account for touch sensitivity
        double epsilon = (control.type == ControlType.slider || control.type == ControlType.dial) 
            ? 0.05 
            : 0.1;

        if ((newValue - targetVal).abs() <= epsilon) {
          // Interaction successful! Generate a new instruction for that specific player
          await generateInstructionForPlayer(
            sessionId, 
            targetPlayerId, 
            allRoomControls, 
            playersData
          );
        }
      }
    }
  }

  /// Handles the penalty logic when a player's instruction timer runs out.
  Future<void> handleInstructionTimeout(
    String sessionId, 
    String playerId, 
    List<GameControl> allControls, 
    Map<dynamic, dynamic> playersData,
  ) async {
    // 1. Log the failure globally for the team
    await _firebaseService.incrementMissedCount(sessionId);

    // 2. Clear the failed instruction and give them a new task
    await generateInstructionForPlayer(
      sessionId, 
      playerId, 
      allControls, 
      playersData
    );
  }
}