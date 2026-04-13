import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_control.dart';
import 'firebase_service.dart';
import '../config/game_config.dart';

class InstructionService {
  final FirebaseService _firebaseService = FirebaseService();
  final Random _random = Random();

  Future<void> generateInstructionForPlayer(
    String sessionId,
    String playerId,
    List<GameControl> allRoomControls,
    Map<dynamic, dynamic> playersData,
  ) async {
    if (allRoomControls.isEmpty) {
      debugPrint('DEBUG STANDBY: allRoomControls is empty for $playerId');
      return;
    }

    // 1. Pick a control with a bias towards other players' controls
    GameControl targetControl;
    int pickAttempts = 0;
    
    do {
      targetControl = allRoomControls[_random.nextInt(allRoomControls.length)];
      pickAttempts++;
      
      bool isMine = targetControl.ownerId == playerId;
      bool rollForSelf = _random.nextDouble() < GameConfig.chanceOfSelfInstruction;
      
      if (!isMine || rollForSelf || pickAttempts > 15) {
        break; 
      }
    } while (true);

    double targetValue = 0.0;
    String instructionText = "STAND BY"; // Default value

    // Get current round for sequence scaling
    int currentRound = (playersData.values.first['round_number'] as num? ?? 1).toInt();
    if (currentRound == 0) currentRound = 1;

    debugPrint('DEBUG: Generating instruction for player $playerId');
    debugPrint('DEBUG: Target selected: ${targetControl.label} (${targetControl.type.name}) owned by ${targetControl.ownerId}');

    switch (targetControl.type) {
      case ControlType.toggle:
        // Use a 0.5 threshold to determine if it is currently ON or OFF.
        // This prevents floating point errors (e.g., 0.999 vs 1.0).
        bool currentlyOn = targetControl.value > 0.5;
        
        // Force the target to be the absolute opposite.
        targetValue = currentlyOn ? 0.0 : 1.0;
        
        // Assign the instruction text based on the NEW targetValue.
        instructionText = (targetValue > 0.5) 
            ? "${targetControl.onAction} ${targetControl.label}" 
            : "${targetControl.offAction} ${targetControl.label}";
            
        debugPrint('DEBUG TOGGLE: ${targetControl.label} is currently ${currentlyOn ? "ON" : "OFF"}. Setting Target to $targetValue');
        break;

      case ControlType.choice:
      case ControlType.dial:
        if (targetControl.options != null && targetControl.options!.isNotEmpty) {
          // --- CATEGORICAL DIAL (e.g., Navigation Heading) ---
          int currentIndex = targetControl.value.toInt();
          int newIndex;
          int attempts = 0;
          do {
            newIndex = _random.nextInt(targetControl.options!.length);
            attempts++;
          } while (newIndex == currentIndex && attempts < GameConfig.maxRedundancyAttempts);
          
          targetValue = newIndex.toDouble();
          String targetLabel = targetControl.options![newIndex];
          instructionText = "SET ${targetControl.label} TO $targetLabel";
          debugPrint('DEBUG: Categorical Dial/Choice logic applied for ${targetControl.label}');
        } else {
          // --- NUMERICAL DIAL (e.g., Signal Frequency, Grid Voltage) ---
          double currentValue = targetControl.value;
          double newValue;
          int attempts = 0;
          double range = targetControl.max - targetControl.min;
          
          // Use a smaller movement threshold for dials than sliders (15%)
          double minDistance = range * 0.15; 
          
          do {
            int steps = (range / targetControl.step).round();
            newValue = targetControl.min + (_random.nextInt(steps + 1) * targetControl.step);
            attempts++;
          } while ((newValue - currentValue).abs() < minDistance && attempts < 20);
          
          targetValue = newValue;
          String display = targetValue == targetValue.truncateToDouble() 
              ? targetValue.toInt().toString() 
              : targetValue.toStringAsFixed(1);
          
          instructionText = "ROTATE ${targetControl.label} TO $display${targetControl.unit}";
          debugPrint('DEBUG: Numerical Dial logic applied for ${targetControl.label}. Value: $targetValue');
        }
        break;

      case ControlType.slider:
        double currentValue = targetControl.value;
        double newValue;
        int attempts = 0;
        
        // 1. Calculate range and total steps based on the control's actual scale
        double range = targetControl.max - targetControl.min;
        int totalSteps = (range / targetControl.step).round();
        
        // 2. Minimum distance to ensure the player actually has to move it
        double minDistance = range * GameConfig.sliderMinMovementPercent;
        
        do {
          // 3. Pick a random step and map it back to the real scale (min to max)
          int randomStep = _random.nextInt(totalSteps + 1);
          newValue = targetControl.min + (randomStep * targetControl.step);
          attempts++;
          
          // Safety break to prevent infinite loops if the range is too small
          if (attempts > 30) break;
        } while ((newValue - currentValue).abs() < minDistance);
        
        targetValue = newValue;
        
        // 4. Formatting: Ensure we don't show "0.6000000000000001"
        // truncateToDouble check handles clean integers vs decimals
        String display = targetValue == targetValue.truncateToDouble() 
            ? targetValue.toInt().toString() 
            : targetValue.toStringAsFixed(1);
            
        instructionText = "ADJUST ${targetControl.label} TO $display${targetControl.unit}";
        
        debugPrint('DEBUG SLIDER: ${targetControl.label} | Range: ${targetControl.min}-${targetControl.max} | New Target: $targetValue');
        break;

      case ControlType.sequence:
        int sequenceLength = GameConfig.minSequenceLength + 
            (currentRound / GameConfig.roundsPerSequenceScaling).ceil();
        sequenceLength = sequenceLength.clamp(GameConfig.minSequenceLength, GameConfig.maxSequenceLength);

        String displayCode = "";
        String numericValue = "";
        List<String> chars = targetControl.options ?? ['1', '2', '3', '4'];
        
        for (int i = 0; i < sequenceLength; i++) {
          int idx = _random.nextInt(chars.length);
          displayCode += (displayCode.isEmpty ? "" : "-") + chars[idx];
          numericValue += (idx + 1).toString();
        }

        targetValue = double.parse(numericValue);
        instructionText = "ENTER CODE $displayCode ON ${targetControl.label}";
        debugPrint('DEBUG: Sequence logic applied. Length: $sequenceLength, Code: $displayCode');
        break;

      case ControlType.button:
        targetValue = 1.0;
        String action = (targetControl.onAction.isNotEmpty && targetControl.onAction != 'ON') 
            ? targetControl.onAction 
            : "PRESS";
        instructionText = "$action ${targetControl.label}";
        debugPrint('DEBUG: Button logic applied. Action: $action');
        break;
      
      default:
        debugPrint('DEBUG STANDBY: Reached default case in switch for type ${targetControl.type}');
        return;
    }

    // Final guard before update
    if (instructionText == "STAND BY") {
      debugPrint('DEBUG STANDBY: Logic failed to update instructionText for ${targetControl.label}');
    }

    // Determine duration
    int baseSeconds = (playersData.values.first['instruction_duration'] as num? ?? 15).toInt();
    int finalDuration = targetControl.type == ControlType.sequence 
        ? (baseSeconds * GameConfig.sequenceTimeMultiplier).round() 
        : baseSeconds;

    debugPrint('DEBUG: Final Instruction: "$instructionText" | Target Value: $targetValue | Duration: $finalDuration');

    // 2. Update Firebase
    await _firebaseService.setPlayerInstruction(
      sessionId, 
      playerId, 
      instructionText, 
      targetControl.id, 
      targetValue,
    );
    
    await _firebaseService.initializeRoom(sessionId, {
      'players/$playerId/instruction_duration': finalDuration,
      'players/$playerId/instruction_timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> verifyInteraction({
    required String sessionId,
    required GameControl control,
    required double newValue,
    required Map<dynamic, dynamic> playersData,
    required List<GameControl> allRoomControls,
  }) async {
    for (var entry in playersData.entries) {
      final String targetPlayerId = entry.key.toString();
      final dynamic dataRaw = entry.value;
      if (dataRaw is! Map) continue;
      
      final Map data = dataRaw;

      if (data['target_id'] == control.id) {
        double targetVal = (data['target_value'] as num? ?? 0).toDouble();
        
        bool isMatch = false;

        if (control.type == ControlType.sequence || 
            control.type == ControlType.button ||
            control.type == ControlType.toggle ||
            control.type == ControlType.choice) {
          
          isMatch = newValue.round() == targetVal.round();
          
          if (isMatch) {
            debugPrint('DEBUG: Strict match successful for $targetPlayerId on ${control.label}');
          }
        } else {
          double epsilon = GameConfig.analogEpsilon;
          isMatch = (newValue - targetVal).abs() <= epsilon;
          if (isMatch) {
            debugPrint('DEBUG: Fuzzy match successful for $targetPlayerId on ${control.label}');
          }
        }

        if (isMatch) {
          // WAIT FOR SUCCESS FLASH before generating new instruction
          await Future.delayed(const Duration(milliseconds: GameConfig.feedbackAnimationMs));

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

  Future<void> handleInstructionTimeout(
    String sessionId,
    String playerId,
    List<GameControl> allRoomControls,
    Map<dynamic, dynamic> playersData,
  ) async {
    debugPrint('DEBUG: Instruction Timeout for $playerId. Punishing team.');
    await _firebaseService.incrementMissedCount(sessionId);
    
    // WAIT FOR FAIL FLASH before generating new instruction
    await Future.delayed(const Duration(milliseconds: GameConfig.feedbackAnimationMs));

    await generateInstructionForPlayer(
      sessionId, 
      playerId, 
      allRoomControls, 
      playersData
    );
  }
}