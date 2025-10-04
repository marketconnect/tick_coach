import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AgentEntry extends StatefulWidget {
  const AgentEntry({super.key});
  @override
  State<AgentEntry> createState() => _AgentEntryState();
}

class _AgentEntryState extends State<AgentEntry> {
  final _c = TextEditingController();
  String _result = '';
  static const _ai = MethodChannel(
    'ai/edge',
  ); // native side required on Android

  Future<void> _run() async {
    if (_c.text.trim().isEmpty) return;
    HapticFeedback.selectionClick();
    String text = '';
    try {
      text =
          await _ai.invokeMethod<String>('complete', {'prompt': _c.text}) ?? '';
    } catch (_) {
      text = 'On‑device AI is unavailable. Configure AICore or enable cloud.';
    }
    setState(() => _result = text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _c,
            decoration: const InputDecoration(
              labelText: 'I want…',
              prefixIcon: Icon(Icons.auto_awesome),
            ),
            onSubmitted: (_) => _run(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _run,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Generate'),
          ),
          const SizedBox(height: 16),
          if (_result.isNotEmpty)
            Card(
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(_result),
              ),
            ),
        ],
      ),
    );
  }
}
