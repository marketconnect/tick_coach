import 'package:flutter/material.dart';
import 'package:tick_coach/domain/models/training_session.dart';
import 'package:tick_coach/utils/database_helper.dart';

class WorkoutPreviewScreen extends StatefulWidget {
  final TrainingSession session;

  const WorkoutPreviewScreen({super.key, required this.session});

  @override
  State<WorkoutPreviewScreen> createState() => _WorkoutPreviewScreenState();
}

class _WorkoutPreviewScreenState extends State<WorkoutPreviewScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  TrainingSession? _fullSession;

  @override
  void initState() {
    super.initState();
    _fetchWorkoutDetails();
  }

  Future<void> _fetchWorkoutDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final session = await DatabaseHelper.instance.getTrainingSession(
        widget.session.id,
      );
      if (!mounted) return;
      setState(() {
        _fullSession = session;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка загрузки тренировки: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.session.name)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    if (_fullSession == null || _fullSession!.blocks.isEmpty) {
      return const Center(child: Text('В этой тренировке нет упражнений.'));
    }

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          color: colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Обзор тренировки', style: textTheme.titleLarge),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._fullSession!.blocks.map((block) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(block.label ?? block.type, style: textTheme.titleLarge),
              const SizedBox(height: 8),
              ...block.sets.map((set) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (set.label != null)
                          Text(set.label!, style: textTheme.titleMedium),
                        Text('Повторить: ${set.repeat} раз'),
                        const Divider(),
                        ...set.items.map((item) {
                          if (item is Exercise) {
                            return ListTile(
                              title: Text(item.name),
                              leading: const Icon(Icons.fitness_center),
                            );
                          }
                          if (item is Rest) {
                            return ListTile(
                              title: Text('Отдых: ${item.durationSec} сек'),
                              leading: const Icon(Icons.pause),
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }
}
