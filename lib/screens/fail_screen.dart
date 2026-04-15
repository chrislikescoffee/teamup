import 'package:flutter/material.dart';
import 'lobby_screen.dart';
import '../services/firebase_service.dart';

class FailScreen extends StatelessWidget {
  final String sessionId;
  final String localPlayerId;
  final String localPlayerName;
  final int roundNumber;
  final int completedInstructions;
  final int missedInstructions;
  final int noiseChanges;
  final bool isHost;

  const FailScreen({
    super.key,
    required this.sessionId,
    required this.localPlayerId,
    required this.localPlayerName,
    required this.roundNumber,
    required this.completedInstructions,
    required this.missedInstructions,
    required this.noiseChanges,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Restored Large Warning Icon
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

              // Restored and Expanded Debrief Container
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
                      style: TextStyle(
                        color: Colors.white70, 
                        fontSize: 14, 
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    const Divider(color: Colors.redAccent, height: 25),
                    
                    _buildStatRow('ROUNDS SURVIVED', roundNumber.toString()),
                    _buildStatRow('TASKS COMPLETED', completedInstructions.toString()),
                    _buildStatRow('TASKS FAILED', missedInstructions.toString()),
                    _buildStatRow('UNAUTHORIZED INPUTS', noiseChanges.toString()),
                    
                    const Divider(color: Colors.white10, height: 25),
                    
                    _buildStatRow(
                      'STABILITY RATING', 
                      _calculateEfficiency(), 
                      isHighlight: true
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),

              // Restored Host Action Logic
              if (isHost)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    // Reset all counters when restarting
                    await firebaseService.initializeRoom(sessionId, {
                      'status': 'lobby',
                      'missed_count': 0,
                      'completed_count': 0,
                      'noise_count': 0,
                      'round_number': 1,
                    });
                  },
                  child: const Text(
                    'RE-ESTABLISH UPLINK',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                )
              else
                const Text(
                  'WAITING FOR HOST TO RECALIBRATE...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54, 
                    fontStyle: FontStyle.italic,
                    fontSize: 14
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Restored Exit Logic
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LobbyScreen()),
                  );
                },
                child: const Text(
                  'ABANDON SHIP',
                  style: TextStyle(color: Colors.white38, letterSpacing: 1.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Restored helper widget for consistent data rows
  Widget _buildStatRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isHighlight ? Colors.white : Colors.white70,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? Colors.greenAccent : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isHighlight ? 18 : 15,
            ),
          ),
        ],
      ),
    );
  }

  // Restored efficiency logic
  String _calculateEfficiency() {
    int total = completedInstructions + missedInstructions;
    if (total == 0) return "0.0%";
    double perc = (completedInstructions / total) * 100;
    return "${perc.toStringAsFixed(1)}%";
  }
}