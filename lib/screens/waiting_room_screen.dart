import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/room_service.dart';
import 'play_screen.dart';
import 'lobby_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String sessionId;
  final String localPlayerId;
  final String localPlayerName;
  final bool isHost;

  const WaitingRoomScreen({
    super.key,
    required this.sessionId,
    required this.localPlayerId,
    required this.localPlayerName,
    required this.isHost,
  });

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final RoomService _roomService = RoomService();

  Future<void> _handleExit() async {
    if (widget.isHost) {
      await _firebaseService.deleteRoom(widget.sessionId);
    } else {
      await _firebaseService.leaveRoom(widget.sessionId, widget.localPlayerId);
    }
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LobbyScreen()));
    }
  }

  // NEW: Confirmation Dialog for the Host
  Future<void> _confirmStart(bool allReady) async {
    if (allReady) {
      _roomService.startNewGame(widget.sessionId);
      return;
    }

    final bool? shouldStart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scientists Not Ready'),
        content: const Text('Not all players are ready. Are you sure you want to start the mission?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('START ANYWAY', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (shouldStart == true) {
      _roomService.startNewGame(widget.sessionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Waiting Room'),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: _handleExit)
          ],
        ),
        body: StreamBuilder(
          stream: _firebaseService.getGameStream(widget.sessionId),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return const Center(child: Text('Session Ended.'));
            }

            final sessionData = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
            
            if (sessionData['status'] == 'playing') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlayScreen(
                        sessionId: widget.sessionId,
                        localPlayerId: widget.localPlayerId,
                        localPlayerName: widget.localPlayerName,
                        isHost: widget.isHost,
                      ),
                    ),
                  );
                }
              });
              return const Center(child: CircularProgressIndicator());
            }

            final dynamic playersRaw = sessionData['players'];
            Map<dynamic, dynamic> playersData = playersRaw is Map ? playersRaw : {};

            bool allReady = true;
            bool amIReady = false;
            List<Widget> playerTiles = [];

            playersData.forEach((key, value) {
              String pId = key.toString();
              Map pData = value as Map;
              bool ready = pData['isReady'] == true;
              if (!ready) allReady = false;
              if (pId == widget.localPlayerId) amIReady = ready;

              playerTiles.add(
                ListTile(
                  leading: Icon(ready ? Icons.check_circle : Icons.radio_button_unchecked, 
                             color: ready ? Colors.green : Colors.grey),
                  title: Text(pData['name'] ?? 'Unknown'),
                  trailing: (widget.isHost && pId != widget.localPlayerId) 
                    ? IconButton(icon: const Icon(Icons.person_remove, color: Colors.red),
                        onPressed: () => _firebaseService.bootPlayer(widget.sessionId, pId)) 
                    : null,
                )
              );
            });

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade900,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('ACCESS CODE', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(
                        widget.sessionId,
                        style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 12),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(child: ListView(children: playerTiles)),
                
                // UPDATED: Combined Host Control Area
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Both Host and Client now have the Ready Toggle
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          icon: Icon(amIReady ? Icons.check : Icons.priority_high),
                          label: Text(amIReady ? 'I AM READY' : 'SET READY STATUS'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: amIReady ? Colors.green : Colors.blue,
                            side: BorderSide(color: amIReady ? Colors.green : Colors.blue),
                          ),
                          onPressed: () => _firebaseService.toggleReadyStatus(
                            widget.sessionId, widget.localPlayerId, !amIReady
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Only Host sees the Start Mission button
                      if (widget.isHost)
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: allReady ? Colors.green : Colors.orange,
                            ),
                            onPressed: () => _confirmStart(allReady),
                            child: const Text('START MISSION', style: TextStyle(fontSize: 18, color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}