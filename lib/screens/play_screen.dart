import 'package:flutter/material.dart';
import '../models/game_control.dart';
import '../widgets/control_factory.dart';
import '../services/firebase_service.dart';
import '../services/instruction_service.dart';
import '../widgets/animated_banner.dart';
import 'lobby_screen.dart'; 

class PlayScreen extends StatefulWidget {
  final String sessionId;
  final String localPlayerId;
  final String localPlayerName;
  final bool isHost;

  const PlayScreen({
    super.key, 
    required this.sessionId,
    required this.localPlayerId, 
    required this.localPlayerName,
    required this.isHost,
  });

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final InstructionService _instructionService = InstructionService();

  Future<void> _handleExit() async {
    if (widget.isHost) {
      await _firebaseService.deleteRoom(widget.sessionId);
    } else {
      await _firebaseService.leaveRoom(widget.sessionId, widget.localPlayerId);
    }
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LobbyScreen()),
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
        appBar: AppBar(
          title: Text('Scientist: ${widget.localPlayerName}'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _handleExit,
            tooltip: 'Leave Room',
          ),
        ),
        body: StreamBuilder(
          stream: _firebaseService.getGameStream(widget.sessionId),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            
            // If data becomes null, it means the room was deleted (likely by the host)
            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LobbyScreen()),
                  );
                }
              });
              return const Center(child: Text('Connection Lost...'));
            }

            final rawValue = snapshot.data!.snapshot.value;
            if (rawValue is! Map) return const Center(child: Text('Invalid data format.'));

            final sessionData = Map<dynamic, dynamic>.from(rawValue);
            final int missedCount = (sessionData['missed_count'] as num?)?.toInt() ?? 0;

            final dynamic playersRaw = sessionData['players'];
            Map<dynamic, dynamic> playersData = playersRaw is Map ? playersRaw : {};
            
            final dynamic localPlayerDataRaw = playersData[widget.localPlayerId];
            final Map<dynamic, dynamic> localPlayerData = localPlayerDataRaw is Map ? localPlayerDataRaw : {};
            
            final String localInstruction = localPlayerData['current_instruction']?.toString() ?? 'Stand by...';

            final dynamic controlsRaw = sessionData['controls'];
            List<GameControl> activeControls = [];
            List<GameControl> allRoomControls = [];

            if (controlsRaw is Map) {
              controlsRaw.forEach((key, data) {
                if (data is Map) {
                  String ownerId = data['ownerId']?.toString() ?? '';

                  List<String>? parsedOptions;
                  if (data['options'] != null && data['options'] is List) {
                    parsedOptions = List<String>.from(data['options']);
                  }

                  GameControl parsedControl = GameControl(
                    id: key.toString(),
                    label: data['label'] ?? 'Unknown',
                    type: ControlType.values.byName(data['type'] ?? 'button'),
                    value: (data['value'] as num? ?? 0).toDouble(),
                    onAction: data['onAction'] ?? 'Turn On',
                    offAction: data['offAction'] ?? 'Turn Off',
                    min: (data['min'] as num? ?? 0).toDouble(),
                    max: (data['max'] as num? ?? 1.0).toDouble(),
                    step: (data['step'] as num? ?? 0.1).toDouble(),
                    unit: data['unit'] ?? '',
                    ownerId: ownerId,
                    options: parsedOptions,
                  );

                  allRoomControls.add(parsedControl);

                  if (ownerId == widget.localPlayerId) {
                    activeControls.add(parsedControl);
                  }
                }
              });
            }

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8.0),
                  color: Colors.red.shade900,
                  child: Text(
                    'TEAM ERRORS: $missedCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                AnimatedInstructionBanner(
                  instruction: localInstruction,
                  durationInSeconds: 15,
                  onTimeExpired: () {
                    if (localInstruction.contains('PREPARING') || 
                        localInstruction.contains('GET READY') || 
                        localInstruction.contains('Stand by') || 
                        localInstruction.contains('ONLINE')) {
                      return;
                    }
                    _instructionService.handleInstructionTimeout(
                      widget.sessionId, 
                      widget.localPlayerId, 
                      allRoomControls, 
                      playersData
                    );
                  },
                ),
                const Divider(height: 1),
                
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double maxWrapWidth = constraints.maxWidth;

                      return Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWrapWidth),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 16.0,
                                runSpacing: 16.0,
                                children: activeControls.map((control) {
                                  
                                  double idealWidth;
                                  switch (control.type) {
                                    case ControlType.dial:
                                      idealWidth = 260.0;
                                      break;
                                    case ControlType.slider:
                                      idealWidth = 320.0;
                                      break;
                                    default:
                                      idealWidth = 200.0;
                                  }

                                  double safeWidth = idealWidth;
                                  if (safeWidth > maxWrapWidth - 32) {
                                    safeWidth = maxWrapWidth - 32;
                                  }

                                  return SizedBox(
                                    width: safeWidth,
                                    child: Card(
                                      elevation: 4,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: SizedBox(
                                            width: idealWidth, 
                                            child: controlFactory(
                                              control, 
                                              (newValue) {
                                                _firebaseService.updateControl(widget.sessionId, control.id, newValue);
                                              },
                                              (finalValue) {
                                                _instructionService.verifyInteraction(
                                                  sessionId: widget.sessionId,
                                                  control: control,
                                                  newValue: finalValue,
                                                  playersData: playersData, 
                                                  allRoomControls: allRoomControls,
                                                );
                                              }
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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