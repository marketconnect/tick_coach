import 'dart:async';

import 'package:flutter/material.dart';

// Data model based on <entity id="Workout">
class Workout {
  final String id;
  final String title;
  final List<String> previewLines;
  final Duration totalTime;
  final int intervalsCount;
  final bool hasSettings;
  final bool hasNotes;
  final int? repeats;

  const Workout({
    required this.id,
    required this.title,
    required this.previewLines,
    required this.totalTime,
    required this.intervalsCount,
    this.hasSettings = false,
    this.hasNotes = false,
    this.repeats,
  });
}

// The main screen widget
class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  // State management based on <screen id="workouts_screen"> states
  bool _isLoading = true;
  String? _errorMessage;
  List<Workout> _workouts = [];

  @override
  void initState() {
    super.initState();
    _fetchWorkouts();
  }

  // Mock implementation of <effect id="load_workouts">
  Future<void> _fetchWorkouts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));
      // Mock data
      setState(() {
        _workouts = [
          const Workout(
            id: '1',
            title: 'Табата 4 мин',
            previewLines: ['20с работа', '10с отдых', '8 раундов'],
            totalTime: Duration(minutes: 4),
            intervalsCount: 16,
            repeats: 1,
            hasSettings: true,
          ),
          const Workout(
            id: '2',
            title: 'Дыхание 4-7-8',
            previewLines: ['Вдох: 4с', 'Задержка: 7с', 'Выдох: 8с'],
            totalTime: Duration(minutes: 5, seconds: 45),
            intervalsCount: 20,
            hasNotes: true,
          ),
          const Workout(
            id: '3',
            title: 'Интервальный бег',
            previewLines: [
              '5 мин разминка',
              '3 мин быстрый бег',
              '2 мин ходьба',
              '...',
            ],
            totalTime: Duration(minutes: 30),
            intervalsCount: 8,
          ),
        ];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить тренировки';
        _isLoading = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    }
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Тренировки: ${_workouts.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.payments),
            tooltip: 'Поддержать проект',
            onPressed: () {
              /* OpenDonations */
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Настройки приложения',
            onPressed: () {
              /* OpenAppSettings */
            },
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          /* CreateWorkout */
        },
        icon: const Icon(Icons.add),
        label: const Text('Добавить тренировку'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    if (_workouts.isEmpty) {
      return const Center(child: Text('Пока нет тренировок'));
    }
    return RefreshIndicator(
      onRefresh: _fetchWorkouts,
      child: ListView.separated(
        padding: const EdgeInsets.all(8.0),
        itemCount: _workouts.length,
        itemBuilder: (context, index) {
          final workout = _workouts[index];
          return WorkoutCard(
            workout: workout,
            onFormatDuration: _formatDuration,
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 8),
      ),
    );
  }
}

// UI component based on <template id="WorkoutCard">
class WorkoutCard extends StatelessWidget {
  final Workout workout;
  final String Function(Duration) onFormatDuration;

  const WorkoutCard({
    super.key,
    required this.workout,
    required this.onFormatDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          /* OpenWorkout(workout.id) */
        },
        onLongPress: () {
          /* ShowWorkoutMenu(workout.id) */
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      workout.title,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.play_arrow),
                        tooltip: 'Запустить тренировку',
                        onPressed: () {
                          /* StartWorkout(workout.id) */
                        },
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Дополнительные действия',
                        onSelected: (value) {
                          /* Handle menu selection */
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit),
                                  title: Text('Изменить'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'preview',
                                child: ListTile(
                                  leading: Icon(Icons.visibility),
                                  title: Text('Просмотр'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'settings',
                                child: ListTile(
                                  leading: Icon(Icons.tune),
                                  title: Text('Настройки'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'notes',
                                child: ListTile(
                                  leading: Icon(Icons.notes),
                                  title: Text('Заметки'),
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'duplicate',
                                child: ListTile(
                                  leading: Icon(Icons.content_copy),
                                  title: Text('Копировать'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'shuffle',
                                child: ListTile(
                                  leading: Icon(Icons.shuffle),
                                  title: Text('Перемешать'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'share',
                                child: ListTile(
                                  leading: Icon(Icons.share),
                                  title: Text('Поделиться'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'shortcut',
                                child: ListTile(
                                  leading: Icon(Icons.link),
                                  title: Text('Создать ярлык'),
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.delete,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  title: Text(
                                    'Удалить',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...workout.previewLines.map(
                (line) =>
                    Text(line, style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Всего: ${onFormatDuration(workout.totalTime)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const _DotSeparator(),
                  Text(
                    '${workout.intervalsCount} интервалов',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (workout.repeats != null) ...[
                    const _DotSeparator(),
                    Text(
                      '${workout.repeats} повт.',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                  if (workout.hasSettings)
                    const Chip(
                      avatar: Icon(Icons.tune, size: 16),
                      label: Text('Есть настройки'),
                    ),
                  if (workout.hasNotes)
                    const Chip(
                      avatar: Icon(Icons.notes, size: 16),
                      label: Text('Есть заметки'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotSeparator extends StatelessWidget {
  const _DotSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        '•',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}
