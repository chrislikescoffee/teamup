import 'dart:math';
import '../models/game_control.dart';
import '../data/control_library.dart';
import 'firebase_service.dart';
import 'instruction_service.dart';

class RoomService {
  final FirebaseService _firebaseService = FirebaseService();
  final InstructionService _instructionService = InstructionService();

  Future<void> startNewGame(String sessionId) async {
    // 1. Fetch connected players from the lobby
    final playersData = await _firebaseService.getPlayers(sessionId);
    if (playersData == null || playersData.isEmpty) return;

    List<String> playerIds = playersData.keys.cast<String>().toList();

    // 2. Prepare the control pool
    List<GameControl> pool = List.from(ControlLibrary.laboratoryPool);
    pool.shuffle();

    // 3. Determine control distribution
    // We aim for roughly 4 controls per player, limited by the pool size.
    int controlsPerPlayer = (pool.length / playerIds.length).floor();
    if (controlsPerPlayer > 4) controlsPerPlayer = 4; 
    if (controlsPerPlayer < 1) controlsPerPlayer = 1; 

    Map<String, dynamic> controlsMap = {};
    int poolIndex = 0;

    // 4. Distribute unique controls to each player
    for (String playerId in playerIds) {
      for (int i = 0; i < controlsPerPlayer; i++) {
        if (poolIndex >= pool.length) break; 
        
        final item = pool[poolIndex];
        controlsMap[item.id] = {
          'label': item.label,
          'type': item.type.name,
          'value': 0.0,
          'onAction': item.onAction,
          'offAction': item.offAction,
          'min': item.min,
          'max': item.max,
          'step': item.step,
          'unit': item.unit,
          'ownerId': playerId, // Each control is assigned to a specific player
          'options': item.options, // Include non-numerical labels if present
        };
        poolIndex++;
      }
    }

    // 5. Update player states for game start
    // We preserve the player IDs and names but set the initial game instructions.
    Map<dynamic, dynamic> updatedPlayers = Map.from(playersData);
    updatedPlayers.forEach((key, value) {
      if (value is Map) {
        value['current_instruction'] = 'PREPARING LABORATORY...';
        value['target_id'] = '';
        value['target_value'] = -1.0;
      }
    });

    // 6. Initialize the room database
    // Setting status to 'playing' triggers the UI transition on all client devices.
    await _firebaseService.initializeRoom(sessionId, {
      'status': 'playing',
      'controls': controlsMap,
      'missed_count': 0,
      'players': updatedPlayers, 
    });

    // Create a local list of all assigned controls for the instruction generator
    List<GameControl> allAssignedControls = [];
    controlsMap.forEach((key, data) {
      allAssignedControls.add(GameControl(
        id: key,
        type: ControlType.values.byName(data['type']),
        label: data['label'],
        ownerId: data['ownerId'],
        options: data['options'] != null ? List<String>.from(data['options']) : null,
      ));
    });

    // Short pause for screen transition to settle
    await Future.delayed(const Duration(seconds: 2));

    // --- SYNCHRONIZED START SEQUENCE ---
    // Push 'GET READY' to every player's banner
    for (String pId in playerIds) {
      await _firebaseService.setPlayerInstruction(
        sessionId, 
        pId, 
        'GET READY', 
        '', 
        -1.0
      );
    }
    
    // Wait for the duration of a standard instruction (15 seconds)
    await Future.delayed(const Duration(seconds: 15));
    // ------------------------------------

    // 7. Launch initial independent instructions for every player
    for (String pId in playerIds) {
      await _instructionService.generateInstructionForPlayer(
        sessionId, 
        pId, 
        allAssignedControls,
        updatedPlayers,
      );
    }
  }
}