import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://team-up-game-a6449-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();

  // --- ROOM MANAGEMENT ---

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // Returns a map containing the new sessionId and the host's playerId
  Future<Map<String, String>> createRoom(String playerName) async {
    String code = _generateRoomCode();
    final roomRef = _dbRef.child('sessions/$code');
    final playerRef = roomRef.child('players').push();
    final playerId = playerRef.key!;

    // SAFETY NET: If the host loses connection or crashes, wipe the entire room
    await roomRef.onDisconnect().remove();

    await roomRef.set({
      'status': 'waiting',
      'hostId': playerId,
      'missed_count': 0,
    });

    await playerRef.set({
      'name': playerName,
      'isReady': true, // Host is ready by default
    });

    return {'sessionId': code, 'playerId': playerId};
  }

  // Returns the assigned playerId, or throws an error if the room is invalid
  Future<String> joinRoom(String code, String playerName) async {
    code = code.toUpperCase();
    final roomRef = _dbRef.child('sessions/$code');
    final snapshot = await roomRef.child('status').get();

    if (!snapshot.exists || snapshot.value != 'waiting') {
      throw Exception("Room not found or game has already started.");
    }

    final playerRef = roomRef.child('players').push();
    
    // SAFETY NET: If a client drops, remove just them from the players list
    await playerRef.onDisconnect().remove();

    await playerRef.set({
      'name': playerName,
      'isReady': false,
    });

    return playerRef.key!;
  }

  Future<void> toggleReadyStatus(String sessionId, String playerId, bool isReady) async {
    await _dbRef.child('sessions/$sessionId/players/$playerId').update({'isReady': isReady});
  }

  Future<void> bootPlayer(String sessionId, String playerId) async {
    await _dbRef.child('sessions/$sessionId/players/$playerId').remove();
  }

  // Used when the host intentionally clicks "Leave Room"
  Future<void> deleteRoom(String sessionId) async {
    await _dbRef.child('sessions/$sessionId').remove();
  }

  // Used when a client intentionally clicks "Leave Room"
  Future<void> leaveRoom(String sessionId, String playerId) async {
    await _dbRef.child('sessions/$sessionId/players/$playerId').remove();
    // Scrub their controls
    final controlsSnapshot = await _dbRef.child('sessions/$sessionId/controls').get();
    if (controlsSnapshot.exists) {
      Map<dynamic, dynamic> controls = controlsSnapshot.value as Map<dynamic, dynamic>;
      Map<String, Object?> updates = {};
      controls.forEach((key, value) {
        if (value is Map && value['ownerId'] == playerId) {
          updates['sessions/$sessionId/controls/$key'] = null;
        }
      });
      if (updates.isNotEmpty) await _dbRef.update(updates);
    }
  }

  // --- GAME LOGIC ---

  Stream<DatabaseEvent> getGameStream(String sessionId) {
    return _dbRef.child('sessions/$sessionId').onValue;
  }

  Future<void> updateControl(String sessionId, String controlId, double value) async {
    await _dbRef.child('sessions/$sessionId/controls/$controlId').update({'value': value});
  }

  Future<void> setPlayerInstruction(String sessionId, String playerId, String text, String targetId, double targetValue) async {
    await _dbRef.child('sessions/$sessionId/players/$playerId').update({
      'current_instruction': text,
      'target_id': targetId,
      'target_value': targetValue,
    });
  }

  // CRITICAL FIX: Changed from .set() to .update() so we don't overwrite the hostId or status
  Future<void> initializeRoom(String sessionId, Map<String, dynamic> data) async {
    await _dbRef.child('sessions/$sessionId').update(data);
  }

  Future<void> incrementMissedCount(String sessionId) async {
    final ref = _dbRef.child('sessions/$sessionId/missed_count');
    final snapshot = await ref.get();
    int currentCount = (snapshot.value as num?)?.toInt() ?? 0;
    await ref.set(currentCount + 1);
  }

  Future<Map<dynamic, dynamic>?> getPlayers(String sessionId) async {
    final snapshot = await _dbRef.child('sessions/$sessionId/players').get();
    if (snapshot.exists) return snapshot.value as Map<dynamic, dynamic>;
    return null;
  }

  Future<Map<dynamic, dynamic>?> getRoomControls(String sessionId) async {
    final snapshot = await _dbRef.child('sessions/$sessionId/controls').get();
    if (snapshot.exists) return snapshot.value as Map<dynamic, dynamic>;
    return null;
  }
}