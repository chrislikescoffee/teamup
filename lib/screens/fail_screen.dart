import 'package:flutter/material.dart';
import 'lobby_screen.dart';
import '../services/firebase_service.dart';

class FailScreen extends StatelessWidget {
  final String sessionId;
  final String localPlayerId;
  final String localPlayerName;
  final int roundNumber;
  final bool isHost;

  const FailScreen({
    super.key,
    required this.sessionId,
    required this.localPlayerId,
    required this.localPlayerName,
    required this.roundNumber,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.report_problem,
                color: Colors.redAccent,
                size: 100,
              ),
              const SizedBox(height: 24),
              const Text(
                'HULL BREACHED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'MISSION FAILED',
                style: TextStyle(
                  color: Colors.red.shade200,
                  fontSize: 18,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'DEBRIEF DATA',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const Divider(color: Colors.redAccent),
                    const SizedBox(height: 10),
                    Text(
                      'ROUNDS SURVIVED: $roundNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              if (isHost)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  onPressed: () async {
                    // Host resets the room status to 'lobby' to play again
                    await firebaseService.initializeRoom(sessionId, {
                      'status': 'lobby',
                      'missed_count': 0,
                      'round_number': 1,
                    });
                  },
                  child: const Text('RE-ESTABLISH UPLINK'),
                )
              else
                const Text(
                  'WAITING FOR HOST TO RECALIBRATE...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LobbyScreen()),
                  );
                },
                child: const Text(
                  'ABANDON SHIP',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}