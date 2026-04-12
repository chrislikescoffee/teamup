import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/room_service.dart';
import 'lobby_screen.dart';
import 'play_screen.dart';

class SuccessScreen extends StatefulWidget {
  final String sessionId;
  final String localPlayerId;     // Added
  final String localPlayerName;   // Added
  final int missedCount;
  final bool isHost;

  const SuccessScreen({
    super.key,
    required this.sessionId,
    required this.localPlayerId,
    required this.localPlayerName,
    required this.missedCount,
    required this.isHost,
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final RoomService _roomService = RoomService();

  Future<void> _handleExit() async {
    if (widget.isHost) {
      await _firebaseService.deleteRoom(widget.sessionId);
    } else {
      await _firebaseService.leaveRoom(widget.sessionId, widget.localPlayerId);
    }
    if (mounted) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const LobbyScreen())
      );
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
        backgroundColor: Colors.black,
        body: StreamBuilder(
          stream: _firebaseService.getGameStream(widget.sessionId),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return const Center(child: Text('Room Closed', style: TextStyle(color: Colors.white)));
            }

            final sessionData = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
            
            // AUTO-TRANSITION: If the host starts a new round, we go back to the PlayScreen
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
              return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
            }

            final players = Map<dynamic, dynamic>.from(sessionData['players']);
            bool allReady = true;
            bool amIReady = players[widget.localPlayerId]?['isReady'] ?? false;

            List<Widget> playerStatusWidgets = [];
            players.forEach((id, data) {
              bool ready = data['isReady'] ?? false;
              if (!ready) allReady = false;
              playerStatusWidgets.add(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    '${data['name']}: ${ready ? "READY" : "WAITING"}',
                    style: TextStyle(
                      color: ready ? Colors.greenAccent : Colors.white30,
                      fontSize: 18,
                    ),
                  ),
                ),
              );
            });

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified, size: 100, color: Colors.greenAccent),
                  const SizedBox(height: 24),
                  const Text(
                    'SUCCESS!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TEAM ERRORS: ${widget.missedCount}',
                    style: TextStyle(color: Colors.red.shade400, fontSize: 20),
                  ),
                  const SizedBox(height: 48),
                  ...playerStatusWidgets,
                  const SizedBox(height: 48),
                  
                  // Toggle Ready Button
                  SizedBox(
                    width: 250,
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: amIReady ? Colors.greenAccent : Colors.white,
                        side: BorderSide(color: amIReady ? Colors.greenAccent : Colors.white24),
                      ),
                      onPressed: () => _firebaseService.toggleReadyStatus(
                        widget.sessionId, widget.localPlayerId, !amIReady
                      ),
                      child: Text(amIReady ? 'I AM READY' : 'SET READY'),
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Host-only Start Button
                  if (widget.isHost)
                    SizedBox(
                      width: 250,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: allReady ? Colors.green : Colors.orange,
                        ),
                        onPressed: () => _roomService.startNewGame(widget.sessionId),
                        child: Text(
                          allReady ? 'START NEXT ROUND' : 'FORCE START',
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}