import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import 'waiting_room_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

enum GameRole { host, join }

class _LobbyScreenState extends State<LobbyScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  
  GameRole _selectedRole = GameRole.host;
  bool _isLoading = false;
  bool _isValidCode = false;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_validateCode);
  }

  void _validateCode() {
    final input = _codeController.text.trim();
    setState(() => _isValidCode = input.length == 5);
  }

  Future<void> _resetDatabase() async {
    final String code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showError('Enter a room code to clear specific data.');
      return;
    }
    await _firebaseService.deleteRoom(code);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room data purged.'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _handleAction() async {
  final String name = _nameController.text.trim();
  if (name.isEmpty) return _showError('Identify yourself, Scientist.');

  debugPrint('DEBUG: Starting _handleAction for $name');
  final navigator = Navigator.of(context);
  FocusManager.instance.primaryFocus?.unfocus();
  
  setState(() => _isLoading = true);

  try {
    if (_selectedRole == GameRole.host) {
      debugPrint('DEBUG: Calling createRoom...');
      final result = await _firebaseService.createRoom(name);
      debugPrint('DEBUG: createRoom Success. Session: ${result['sessionId']} Player: ${result['playerId']}');
      
      if (mounted) {
        debugPrint('DEBUG: Attempting Navigator.pushReplacement to WaitingRoomScreen (Host)');
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => WaitingRoomScreen(
              sessionId: result['sessionId']!,
              localPlayerId: result['playerId']!,
              localPlayerName: name,
              isHost: true,
            ),
          ),
        );
      }
    } else {
      final String code = _codeController.text.trim().toUpperCase();
      debugPrint('DEBUG: Joining room $code');
      final playerId = await _firebaseService.joinRoom(code, name);
      debugPrint('DEBUG: joinRoom Success. PlayerID: $playerId');
      
      if (mounted) {
        debugPrint('DEBUG: Attempting Navigator.pushReplacement to WaitingRoomScreen (Guest)');
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => WaitingRoomScreen(
              sessionId: code,
              localPlayerId: playerId,
              localPlayerName: name,
              isHost: false,
            ),
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('DEBUG: FATAL ERROR in Lobby: $e');
    if (mounted) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }
}

  void _navigateToWaitingRoom(String sid, String pid, String name, bool host) {
    // PostFrameCallback ensures the UI is ready for navigation 
    // after the keyboard dismissal and state updates.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingRoomScreen(
            sessionId: sid,
            localPlayerId: pid,
            localPlayerName: name,
            isHost: host,
          ),
        ),
      );
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade800),
    );
  }

  @override
  void dispose() {
    _codeController.removeListener(_validateCode);
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laboratory Access'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: _resetDatabase,
            tooltip: 'Purge Room Data',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Player Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 24),
                SegmentedButton<GameRole>(
                  segments: const [
                    ButtonSegment(value: GameRole.host, label: Text('Host'), icon: Icon(Icons.grid_view)),
                    ButtonSegment(value: GameRole.join, label: Text('Join'), icon: Icon(Icons.group_add)),
                  ],
                  selected: {_selectedRole},
                  onSelectionChanged: (Set<GameRole> set) => setState(() => _selectedRole = set.first),
                ),
                const SizedBox(height: 32),
                if (_selectedRole == GameRole.join) ...[
                  TextField(
                    controller: _codeController,
                    maxLength: 5,
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
                    inputFormatters: [UpperCaseTextFormatter()],
                    decoration: const InputDecoration(
                      hintText: 'CODE',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: (_isLoading || (_selectedRole == GameRole.join && !_isValidCode)) ? null : _handleAction,
                    child: _isLoading 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                          ) 
                        : Text(_selectedRole == GameRole.host ? 'GENERATE SESSION' : 'JOIN LABORATORY'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}