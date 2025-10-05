import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'edit_workout_screen.dart';
import 'workout_timer_screen.dart';
import 'workout_notes_screen.dart';
import 'agent_entry.dart';
import '../utils/database_helper.dart';

// Data model based on <entity id="Workout">
class Workout {
  final String id;
  final String title;
  final List<String> previewLines;
  final Duration totalTime;
  final int intervalsCount;
  final bool hasSettings;
  final bool hasNotes;
  final String? notes;
  final int? repeats;

  const Workout({
    required this.id,
    required this.title,
    required this.previewLines,
    required this.totalTime,
    required this.intervalsCount,
    this.hasSettings = false,
    this.hasNotes = false,
    this.notes,
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
  int _index = 0;
  // State management based on <screen id="workouts_screen"> states
  bool _isLoading = true;
  String? _errorMessage;
  List<Workout> _workouts = [];

  @override
  void initState() {
    super.initState();
    _fetchWorkouts();
  }

  Future<void> _fetchWorkouts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dbHelper = DatabaseHelper.instance;
      final workoutsData = await dbHelper.getAllWorkouts();
      final List<Workout> loadedWorkouts = [];
      for (final workoutMap in workoutsData) {
        final workoutId = workoutMap['id'] as String;
        final notes = workoutMap['notes'] as String?;
        final intervals = await dbHelper.getIntervalsForWorkout(workoutId);
        final setCount = await dbHelper.getSetCountForWorkout(workoutId);
        if (intervals.isNotEmpty) {
          final totalDurationInSeconds =
              intervals.fold<int>(0, (sum, item) => sum + item.durationSec) *
              setCount;
          final distinctDescriptions = intervals
              .map((i) => i.description)
              .where((d) => d != null && d.isNotEmpty)
              .toSet()
              .toList();
          final previewLines = distinctDescriptions
              .take(3)
              .map((d) => d!)
              .toList();
          if (distinctDescriptions.length > 3) {
            previewLines.add('...');
          }
          loadedWorkouts.add(
            Workout(
              id: workoutId,
              title: workoutMap['title'] as String,
              previewLines: previewLines.isEmpty
                  ? ['Нет описания']
                  : previewLines,
              totalTime: Duration(seconds: totalDurationInSeconds),
              notes: notes,
              hasNotes: notes != null && notes.isNotEmpty,
              intervalsCount: intervals.length * setCount,
              repeats: setCount,
            ),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _workouts = loadedWorkouts;
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
    final cs = Theme.of(context).colorScheme;
    final isWorkoutsTab = _index == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isWorkoutsTab ? 'Тренировки: ${_workouts.length}' : 'AI'),
        actions: isWorkoutsTab
            ? [
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
              ]
            : null,
      ),
      body: switch (_index) {
        0 => _buildWorkoutsBody(),
        1 => const AgentEntry(),
        _ => const SizedBox.shrink(),
      },
      floatingActionButton: isWorkoutsTab
          ? FloatingActionButton.extended(
              onPressed: () {
                /* CreateWorkout */
              },
              icon: const Icon(Icons.add),
              label: const Text('Добавить тренировку'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Тренировки',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI',
          ),
        ],
        indicatorColor: cs.secondaryContainer,
      ),
    );
  }

  Widget _buildWorkoutsBody() {
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
            onWorkoutUpdated: _fetchWorkouts,
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
  final VoidCallback onWorkoutUpdated;

  const WorkoutCard({
    super.key,
    required this.workout,
    required this.onFormatDuration,
    required this.onWorkoutUpdated,
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
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  WorkoutTimerScreen(workout: workout),
                            ),
                          );
                        },
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Дополнительные действия',
                        onSelected: (value) async {
                          switch (value) {
                            case 'edit':
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EditWorkoutScreen(workout: workout),
                                ),
                              );
                              onWorkoutUpdated();
                              break;
                            case 'notes':
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      WorkoutNotesScreen(workout: workout),
                                ),
                              );
                              onWorkoutUpdated();
                              break;
                            // Handle other cases
                          }
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
