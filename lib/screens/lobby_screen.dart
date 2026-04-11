import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'waiting_room_screen.dart'; // We will build this next

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  
  bool _isLoading = false;
  bool _showJoinOptions = false;

  Future<void> _createGame() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) return _showError('Please enter your name');

    setState(() => _isLoading = true);

    try {
      final result = await _firebaseService.createRoom(name);
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingRoomScreen(
            sessionId: result['sessionId']!,
            localPlayerId: result['playerId']!,
            localPlayerName: name,
            isHost: true,
          ),
        ),
      );
    } catch (e) {
      _showError('Failed to create room.');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGame() async {
    final String name = _nameController.text.trim();
    final String code = _codeController.text.trim().toUpperCase();
    
    if (name.isEmpty) return _showError('Please enter your name');
    if (code.length != 4) return _showError('Room code must be 4 letters');

    setState(() => _isLoading = true);

    try {
      final playerId = await _firebaseService.joinRoom(code, name);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingRoomScreen(
            sessionId: code,
            localPlayerId: playerId,
            localPlayerName: name,
            isHost: false,
          ),
        ),
      );
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laboratory Access'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Identify Yourself, Scientist', style: TextStyle(fontSize: 24), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Enter your name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 32),
                
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (!_showJoinOptions) ...[
                  ElevatedButton(
                    onPressed: _createGame,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                    child: const Text('Host New Game', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => setState(() => _showJoinOptions = true),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                    child: const Text('Join Existing Game', style: TextStyle(fontSize: 18)),
                  ),
                ] else ...[
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 4,
                    decoration: const InputDecoration(labelText: '4-Letter Room Code', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _joinGame,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                    child: const Text('Connect', style: TextStyle(fontSize: 18)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _showJoinOptions = false),
                    child: const Text('Back'),
                  )
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}