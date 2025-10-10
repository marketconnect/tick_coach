import 'dart:async';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide Interval;
import 'package:flutter/services.dart';
import 'package:tick_coach/domain/models/workout.dart';
import 'edit_workout_screen.dart';
import 'workout_timer_screen.dart';
import 'workout_notes_screen.dart';
import 'workout_preview_screen.dart';
import 'agent_entry.dart';
import '../utils/database_helper.dart';
import 'package:tick_coach/domain/models/interval.dart'
    show Interval, IntervalKind;

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
  bool _isSelectionMode = false;
  final List<Workout> _selectedWorkouts = [];

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
      appBar: _buildAppBar(cs, isWorkoutsTab),
      body: switch (_index) {
        0 => _buildWorkoutsBody(),
        1 => const AgentEntry(),
        _ => const SizedBox.shrink(),
      },
      floatingActionButton: isWorkoutsTab
          ? MenuAnchor(
              builder:
                  (
                    BuildContext context,
                    MenuController controller,
                    Widget? child,
                  ) {
                    return FloatingActionButton.extended(
                      onPressed: () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          HapticFeedback.selectionClick();
                          controller.open();
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить'),
                    );
                  },
              menuChildren: [
                MenuItemButton(
                  onPressed: () async {
                    final newWorkoutId =
                        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
                    final newWorkout = Workout(
                      id: newWorkoutId,
                      title: 'Новая тренировка',
                      previewLines: [],
                      totalTime: Duration.zero,
                      intervalsCount: 0,
                    );
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            EditWorkoutScreen(workout: newWorkout),
                      ),
                    );
                    _fetchWorkouts();
                  },
                  child: const Text('Тренировка'),
                ),
                MenuItemButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isSelectionMode = true;
                      _selectedWorkouts.clear();
                    });
                  },
                  child: const Text('Последовательность'),
                ),
              ],
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: cs.surfaceContainer,
        shadowColor: Colors.black,

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

  AppBar _buildAppBar(ColorScheme cs, bool isWorkoutsTab) {
    if (_isSelectionMode) {
      return AppBar(
        title: const Text('Выберите тренировки'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancelSelection,
        ),
        actions: [
          TextButton(
            onPressed: _selectedWorkouts.isNotEmpty ? _createSequence : null,
            child: const Text('Далее'),
          ),
        ],
      );
    }

    return AppBar(
      title: Text(isWorkoutsTab ? 'Тренировки: ${_workouts.length}' : 'AI'),
      centerTitle: false,
      backgroundColor: cs.surfaceContainer,
      scrolledUnderElevation: 2.0,
      shadowColor: Colors.black,
      surfaceTintColor: Colors.transparent,
    );
  }

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedWorkouts.clear();
    });
  }

  Future<void> _createSequence() async {
    if (_selectedWorkouts.isEmpty) return;

    final dbHelper = DatabaseHelper.instance;
    final List<Interval> sequenceIntervals = [];
    String newId() =>
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}_${sequenceIntervals.length}';

    for (final workout in _selectedWorkouts) {
      final intervals = await dbHelper.getIntervalsForWorkout(workout.id);
      final setCount = await dbHelper.getSetCountForWorkout(workout.id);

      if (intervals.isEmpty) continue;

      final restBetweenSets = intervals.firstWhereOrNull(
        (i) => i.kind == IntervalKind.between_sets,
      );

      final workIntervals = intervals
          .where((i) => i.kind != IntervalKind.between_sets)
          .toList();

      for (int i = 0; i < setCount; i++) {
        sequenceIntervals.addAll(
          workIntervals.map((interval) => interval.copyWith(id: newId())),
        );
        if (restBetweenSets != null && i < setCount - 1) {
          sequenceIntervals.add(restBetweenSets.copyWith(id: newId()));
        }
      }
    }

    final newWorkoutId =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    final newWorkout = Workout(
      id: newWorkoutId,
      title: 'Новая последовательность',
      previewLines: [],
      totalTime: Duration.zero, // Will be recalculated on save
      intervalsCount: sequenceIntervals.length,
    );

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditWorkoutScreen(
          workout: newWorkout,
          initialIntervals: sequenceIntervals,
        ),
      ),
    );

    // Reset state and refresh list after returning
    _cancelSelection();
    _fetchWorkouts();
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
            key: ValueKey(workout.id),
            workout: workout,
            onFormatDuration: _formatDuration,
            onWorkoutUpdated: _fetchWorkouts,
            isSelectionMode: _isSelectionMode,
            isSelected: _selectedWorkouts.contains(workout),
            onSelected: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (_selectedWorkouts.contains(workout)) {
                  _selectedWorkouts.remove(workout);
                } else {
                  _selectedWorkouts.add(workout);
                }
              });
            },
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
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onSelected;

  const WorkoutCard({
    required super.key,
    required this.workout,
    required this.onFormatDuration,
    required this.onWorkoutUpdated,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      color: isSelected ? colorScheme.secondaryContainer : null,
      child: InkWell(
        onTap: isSelectionMode ? onSelected : null,
        onLongPress: () {
          HapticFeedback.selectionClick();
          // Potentially show context menu
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
                      style: theme.textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        tooltip: 'Запустить тренировку',
                        onPressed: isSelectionMode
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        WorkoutTimerScreen(workout: workout),
                                  ),
                                );
                              },
                      ),
                      if (isSelectionMode)
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => onSelected(),
                        )
                      else
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
                              case 'preview':
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        WorkoutPreviewScreen(workout: workout),
                                  ),
                                );
                                break;
                              case 'duplicate':
                                await DatabaseHelper.instance.duplicateWorkout(
                                  workout.id,
                                );
                                onWorkoutUpdated();
                                break;
                              case 'delete':
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Удалить тренировку?'),
                                    content: Text(
                                      'Тренировка "${workout.title}" будет удалена навсегда.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Отмена'),
                                      ),
                                      FilledButton(
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          Navigator.of(context).pop(true);
                                        },
                                        child: const Text('Удалить'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await DatabaseHelper.instance.deleteWorkout(
                                    workout.id,
                                  );
                                  onWorkoutUpdated();
                                }
                                break;
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
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
                (line) => Text(line, style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Всего: ${onFormatDuration(workout.totalTime)}',
                    style: theme.textTheme.titleSmall,
                  ),
                  const _DotSeparator(),
                  Text(
                    '${workout.intervalsCount} интервалов',
                    style: theme.textTheme.titleSmall,
                  ),
                  if (workout.repeats != null) ...[
                    const _DotSeparator(),
                    Text(
                      '${workout.repeats} повт.',
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                  // if (workout.hasSettings)
                  //   const Chip(
                  //     avatar: Icon(Icons.tune, size: 16),
                  //     label: Text('Есть настройки'),
                  //   ),
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
