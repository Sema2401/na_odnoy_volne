import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});
  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _trackCtrl = TextEditingController(text: 'Lo-Fi Study');
  final _artistCtrl = TextEditingController(text: 'Unknown');
  final _urlCtrl = TextEditingController(
    text: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
  );
  bool _isSharing = false;
  bool _loading = false;

  Future<void> _toggleShare() async {
    setState(() => _loading = true);
    try {
      if (!_isSharing) {
        final res = await http.post(
          Uri.parse('${AuthService.baseUrl}/wave/start'),
          headers: await AuthService.authHeaders(),
          body: jsonEncode({
            'track_title': _trackCtrl.text,
            'artist': _artistCtrl.text,
            'track_url': _urlCtrl.text,
            'position_sec': 0,
          }),
        );
        if (res.statusCode == 200) setState(() => _isSharing = true);
      } else {
        await http.post(
          Uri.parse('${AuthService.baseUrl}/wave/stop'),
          headers: await AuthService.authHeaders(),
        );
        setState(() => _isSharing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поделиться волной')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _trackCtrl,
              decoration: const InputDecoration(
                labelText: 'Название трека',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _artistCtrl,
              decoration: const InputDecoration(
                labelText: 'Исполнитель',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL mp3',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _toggleShare,
              icon: Icon(_isSharing ? Icons.stop : Icons.share),
              label: Text(_isSharing ? 'Остановить волну' : 'Начать волну'),
              style: FilledButton.styleFrom(
                backgroundColor: _isSharing ? Colors.red : Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            if (_isSharing) ...[
              const SizedBox(height: 16),
              const Text(
                'Ты в эфире — другие видят тебя в ленте.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
