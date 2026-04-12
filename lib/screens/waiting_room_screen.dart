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
  late final FirebaseService _firebaseService;
  late final RoomService _roomService;

  @override
  void initState() {
    super.initState();
    debugPrint('DEBUG: [WaitingRoom] initState triggered');
    _firebaseService = FirebaseService();
    _roomService = RoomService();
  }

  Future<void> _handleExit() async {
    debugPrint('DEBUG: [WaitingRoom] _handleExit triggered');
    try {
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
    } catch (e) {
      debugPrint('DEBUG: [WaitingRoom] Exit Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('DEBUG: [WaitingRoom] build() method executing');

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        debugPrint('DEBUG: [WaitingRoom] PopScope internal exit');
        await _handleExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Waiting Room'),
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: _handleExit)
          ],
        ),
        body: StreamBuilder(
          stream: _firebaseService.getGameStream(widget.sessionId),
          builder: (context, snapshot) {
            // TRACKING THE STREAM STATE
            debugPrint('DEBUG: [Stream] State: ${snapshot.connectionState}, HasData: ${snapshot.hasData}');

            if (snapshot.hasError) {
              debugPrint('DEBUG: [Stream] ERROR: ${snapshot.error}');
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            // If we are still waiting for the very first connection, don't do anything yet
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // CRITICAL SECTION: The data check
            final dataValue = snapshot.data?.snapshot.value;
            debugPrint('DEBUG: [Stream] Snapshot Value is Null? ${dataValue == null}');

            if (dataValue == null) {
              // Only redirect if the stream is active and genuinely returned nothing
              if (snapshot.connectionState == ConnectionState.active) {
                debugPrint('DEBUG: [WaitingRoom] DATA IS NULL - REDIRECTING TO LOBBY');
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    Navigator.pushReplacement(
                      context, 
                      MaterialPageRoute(builder: (context) => const LobbyScreen())
                    );
                  }
                });
              }
              return const Center(child: Text('Connecting to Lab...'));
            }

            // If we made it here, we have data!
            final sessionData = Map<dynamic, dynamic>.from(dataValue as Map);
            final String status = sessionData['status'] ?? 'waiting';
            debugPrint('DEBUG: [WaitingRoom] Session status found: $status');

            if (status == 'playing') {
              debugPrint('DEBUG: [WaitingRoom] Transitioning to PlayScreen');
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
              return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
            }

            final dynamic playersRaw = sessionData['players'];
            Map playersData = playersRaw is Map ? playersRaw : {};
            debugPrint('DEBUG: [WaitingRoom] Player count: ${playersData.length}');

            // Safety check for players
            if (status == 'waiting' && !widget.isHost && !playersData.containsKey(widget.localPlayerId)) {
              debugPrint('DEBUG: [WaitingRoom] Local player not in list - exiting');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LobbyScreen()));
              });
              return const Center(child: Text('Removing from session...'));
            }

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
                  title: Text(pData['name'] ?? 'Scientist'),
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
                Expanded(child: ListView(children: playerTiles)),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          icon: Icon(amIReady ? Icons.check : Icons.priority_high),
                          label: Text(amIReady ? 'I AM READY' : 'SET READY STATUS'),
                          onPressed: () => _firebaseService.toggleReadyStatus(
                            widget.sessionId, widget.localPlayerId, !amIReady
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.isHost)
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: allReady ? Colors.green : Colors.orange),
                            onPressed: () {
                               debugPrint('DEBUG: [WaitingRoom] Host pressed Start Mission');
                               _roomService.startNewGame(widget.sessionId);
                            },
                            child: const Text('START MISSION', style: TextStyle(color: Colors.white)),
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