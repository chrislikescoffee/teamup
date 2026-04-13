import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import '../models/game_control.dart';
import '../data/control_library.dart';
import 'firebase_service.dart';
import 'instruction_service.dart';
import '../config/game_config.dart';

class RoomService {
  final FirebaseService _firebaseService = FirebaseService();
  final InstructionService _instructionService = InstructionService();

  Future<void> startNewGame(String sessionId) async {
    final sessionSnapshot = await _firebaseService.getGameStream(sessionId).first;
    final sessionData = sessionSnapshot.snapshot.value as Map?;
    if (sessionData == null) return;

    int currentRound = (sessionData['round_number'] as num? ?? 0).toInt();
    int nextRound = currentRound == 0 ? 1 : currentRound + 1;

    // --- DIFFICULTY SCALING VIA GAMECONFIG ---
    int controlsPerPlayer = (3 + (nextRound / 2).floor()).clamp(3, 8);
    
    int instructionSeconds = GameConfig.initialInstructionSeconds - 
        (nextRound ~/ GameConfig.instructionDecrementInterval);
    instructionSeconds = instructionSeconds.clamp(
      GameConfig.minInstructionSeconds, 
      GameConfig.initialInstructionSeconds
    );

    int roundDurationMs = GameConfig.initialRoundDurationMs - 
        ((nextRound - 1) * GameConfig.roundDurationDecrementMs);
    roundDurationMs = roundDurationMs.clamp(
      GameConfig.minRoundDurationMs, 
      GameConfig.initialRoundDurationMs
    );
    // -----------------------------------------

    final dynamic playersRaw = sessionData['players'];
    if (playersRaw == null || playersRaw is! Map) return;
    Map<dynamic, dynamic> playersData = Map.from(playersRaw);
    List<String> playerIds = playersData.keys.cast<String>().toList();

    List<GameControl> pool = List.from(ControlLibrary.laboratoryPool);
    pool.shuffle();

    Map<String, dynamic> controlsMap = {};
    int poolIndex = 0;

    for (String playerId in playerIds) {
      for (int i = 0; i < controlsPerPlayer; i++) {
        if (poolIndex >= pool.length) break; 
        final item = pool[poolIndex];
        
        // Use the helper method defined below
        double initialValue = _getRandomStartingValue(item);

        controlsMap[item.id] = {
          'label': item.label,
          'type': item.type.name,
          'value': initialValue,
          'onAction': item.onAction,
          'offAction': item.offAction,
          'min': item.min,
          'max': item.max,
          'step': item.step,
          'unit': item.unit,
          'ownerId': playerId,
          'options': item.options,
        };
        poolIndex++;
      }
    }

    Map<dynamic, dynamic> updatedPlayers = Map.from(playersData);
    updatedPlayers.forEach((key, value) {
      if (value is Map) {
        value['current_instruction'] = 'CALIBRATING SYSTEM...';
        value['target_id'] = '';
        value['target_value'] = -1.0;
        value['isReady'] = false;
        value['round_number'] = nextRound; 
      }
    });

    await _firebaseService.initializeRoom(sessionId, {
      'status': 'playing',
      'controls': controlsMap,
      'missed_count': 0,
      'round_number': nextRound,
      'instruction_duration': instructionSeconds,
      'players': updatedPlayers, 
      'round_end_timestamp': 0,
      'round_duration_ms': roundDurationMs,
    });

List<GameControl> allAssignedControls = [];
    controlsMap.forEach((key, data) {
      allAssignedControls.add(GameControl(
        id: key,
        type: ControlType.values.byName(data['type']),
        label: data['label'],
        ownerId: data['ownerId'],
        value: (data['value'] as num).toDouble(), 
        options: data['options'] != null ? List<String>.from(data['options']) : null,
        onAction: data['onAction'] ?? 'ON',
        offAction: data['offAction'] ?? 'OFF',
      ));
    });

    await Future.delayed(const Duration(seconds: 2));

    for (String pId in playerIds) {
      await _firebaseService.setPlayerInstruction(sessionId, pId, 'GET READY', '', -1.0);
    }
    
    await Future.delayed(const Duration(seconds: 3));

    final int endTime = DateTime.now().millisecondsSinceEpoch + roundDurationMs;
    await _firebaseService.initializeRoom(sessionId, {
      'round_end_timestamp': endTime,
    });

    for (String pId in playerIds) {
      await _instructionService.generateInstructionForPlayer(
        sessionId, 
        pId, 
        allAssignedControls,
        updatedPlayers,
      );
    }
  }

  // --- HELPER METHOD (Moved outside of startNewGame) ---
  double _getRandomStartingValue(GameControl control) {
    final random = Random();
    
    switch (control.type) {
      case ControlType.toggle:
        return random.nextBool() ? 1.0 : 0.0;
        
      case ControlType.choice:
      case ControlType.dial:
        if (control.options != null && control.options!.isNotEmpty) {
          return random.nextInt(control.options!.length).toDouble();
        }
        return 0.0;
        
      case ControlType.slider:
        double range = control.max - control.min;
        int steps = (range / control.step).round();
        return control.min + (random.nextInt(steps + 1) * control.step);
        
      case ControlType.button:
      case ControlType.sequence:
      default:
        return 0.0;
    }
  }
}