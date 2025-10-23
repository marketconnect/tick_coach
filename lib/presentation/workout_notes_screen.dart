import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tick_coach/domain/models/training_session.dart';
import 'package:tick_coach/domain/repositories/workout_repository.dart';

class WorkoutNotesScreen extends StatefulWidget {
  final TrainingSession session;

  const WorkoutNotesScreen({super.key, required this.session});

  @override
  State<WorkoutNotesScreen> createState() => _WorkoutNotesScreenState();
}

class _WorkoutNotesScreenState extends State<WorkoutNotesScreen> {
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.session.notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    final notes = _notesController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = Provider.of<WorkoutRepository>(context, listen: false);
      await repo.updateTrainingSessionNotes(widget.session.id, notes);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Заметки сохранены')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Заметки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Сохранить',
            onPressed: () {
              HapticFeedback.selectionClick();
              _saveNotes();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: TextField(
          controller: _notesController,
          autofocus: true,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText:
                'Здесь можно хранить заметки о весах, повторениях, самочувствии и т.д.',
            border: InputBorder.none,
          ),
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
        ),
      ),
    );
  }
}
