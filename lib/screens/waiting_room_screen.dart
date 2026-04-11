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
          title: Text('Room: ${widget.sessionId}'),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _handleExit),
        ),
        body: StreamBuilder(
          stream: _firebaseService.getGameStream(widget.sessionId),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('Connection Error'));
            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              // If the room data is completely null, the host destroyed the room. Kick to lobby.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LobbyScreen()));
              });
              return const Center(child: Text('Room closed.'));
            }

            final sessionData = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
            
            // --- THE TRANSITION TRIGGER ---
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
              return const Center(child: CircularProgressIndicator()); // Show loading while transitioning
            }
            // ------------------------------

            // Parse Players
            final dynamic playersRaw = sessionData['players'];
            Map<dynamic, dynamic> playersData = playersRaw is Map ? playersRaw : {};
            
            // Check if WE were booted
            if (!widget.isHost && !playersData.containsKey(widget.localPlayerId)) {
               WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LobbyScreen()));
              });
              return const Center(child: Text('You were removed from the room.'));
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
                  leading: Icon(ready ? Icons.check_circle : Icons.hourglass_empty, color: ready ? Colors.green : Colors.grey),
                  title: Text(pData['name'] ?? 'Unknown'),
                  trailing: (widget.isHost && pId != widget.localPlayerId) 
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _firebaseService.bootPlayer(widget.sessionId, pId),
                      ) 
                    : null,
                )
              );
            });

            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Waiting for Scientists...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView(children: playerTiles),
                ),
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: widget.isHost 
                    ? ElevatedButton(
                        onPressed: () => _roomService.startNewGame(widget.sessionId), // Only the host can call this now!
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                          backgroundColor: allReady ? Colors.blue : Colors.orange, // Orange hints at "Force Start"
                        ),
                        child: Text(allReady ? 'START GAME' : 'FORCE START', style: const TextStyle(fontSize: 20, color: Colors.white)),
                      )
                    : ElevatedButton(
                        onPressed: () => _firebaseService.toggleReadyStatus(widget.sessionId, widget.localPlayerId, !amIReady),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                          backgroundColor: amIReady ? Colors.grey : Colors.green,
                        ),
                        child: Text(amIReady ? 'UNREADY' : 'READY', style: const TextStyle(fontSize: 20, color: Colors.white)),
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