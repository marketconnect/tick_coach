import 'dart:async';
import 'package:flutter/material.dart' hide Interval;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tick_coach/domain/models/training_session.dart';
import 'package:tick_coach/domain/repositories/workout_repository.dart';
import 'edit_workout_screen.dart';
import 'create_rounds_screen.dart';
import 'workout_timer_screen.dart';
import 'workout_notes_screen.dart';
import 'workout_preview_screen.dart';
import 'agent_entry.dart';
import 'dart:math';

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
  List<TrainingSession> _sessions = [];
  bool _isSelectionMode = false;
  final List<TrainingSession> _selectedSessions = [];

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
      final repo = Provider.of<WorkoutRepository>(context, listen: false);
      final sessionsData = await repo.getAllTrainingSessions();
      final List<TrainingSession> loadedSessions = [];
      for (final sessionMap in sessionsData) {
        final session = await repo.getTrainingSession(
          sessionMap['id'] as String,
        );
        if (session != null) {
          loadedSessions.add(session);
        }
      }
      if (!mounted) return;
      setState(() {
        _sessions = loadedSessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить тренировки: $e';
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
                    final newSessionId =
                        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
                    final newSession = TrainingSession(
                      id: newSessionId,
                      name: 'Новая тренировка',
                    );
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            EditWorkoutScreen(trainingSession: newSession),
                      ),
                    );
                    _fetchWorkouts();
                  },
                  child: const Text('Тренировка'),
                ),
                MenuItemButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CreateRoundsScreen(),
                      ),
                    );
                    _fetchWorkouts();
                  },
                  child: const Text('Раунды'),
                ),
                MenuItemButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isSelectionMode = true;
                      _selectedSessions.clear();
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
            onPressed: _selectedSessions.isNotEmpty ? _createSequence : null,
            child: const Text('Далее'),
          ),
        ],
      );
    }

    return AppBar(
      title: Text(isWorkoutsTab ? 'Тренировки: ${_sessions.length}' : 'AI'),
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
      _selectedSessions.clear();
    });
  }

  Future<void> _createSequence() async {
    if (_selectedSessions.isEmpty) return;

    final repo = Provider.of<WorkoutRepository>(context, listen: false);
    final List<Block> sequenceBlocks = [];

    String generateId() =>
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    for (final session in _selectedSessions) {
      // Rounds workouts are not suitable for sequences in this way.
      if (session.workoutType == 'rounds') {
        continue;
      }
      final fullSession = await repo.getTrainingSession(session.id);
      if (fullSession != null) {
        // Deep copy blocks and their children with new IDs to avoid DB conflicts.
        final copiedBlocks = fullSession.blocks.map((block) {
          return block.copyWith(
            id: generateId(),
            sets: block.sets.map((set) {
              return set.copyWith(
                id: generateId(),
                items: set.items.map((item) {
                  return item.copyWith(id: generateId());
                }).toList(),
              );
            }).toList(),
          );
        }).toList();
        sequenceBlocks.addAll(copiedBlocks);
      }
    }
    if (sequenceBlocks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Выберите хотя бы одну обычную тренировку (не раунды).',
            ),
          ),
        );
      }
      _cancelSelection();
      return;
    }
    final newSession = TrainingSession(
      id: generateId(),
      name: 'Новая последовательность',
      blocks: sequenceBlocks,
    );

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditWorkoutScreen(trainingSession: newSession),
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
    if (_sessions.isEmpty) {
      return const Center(child: Text('Пока нет тренировок'));
    }
    final displaySessions = _isSelectionMode
        ? _sessions.where((s) => s.workoutType != 'rounds').toList()
        : _sessions;
    if (displaySessions.isEmpty) {
      return Center(
        child: Text(
          _isSelectionMode
              ? 'Нет тренировок для добавления в последовательность'
              : 'Пока нет тренировок',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchWorkouts,
      child: ListView.separated(
        padding: const EdgeInsets.all(8.0),
        itemCount: displaySessions.length,
        itemBuilder: (context, index) {
          final session = displaySessions[index];
          return TrainingSessionCard(
            key: ValueKey(session.id),
            session: session,
            onFormatDuration: _formatDuration,
            onWorkoutUpdated: _fetchWorkouts,
            isSelectionMode: _isSelectionMode,
            isSelected: _selectedSessions.contains(session),
            onSelected: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (_selectedSessions.contains(session)) {
                  _selectedSessions.remove(session);
                } else {
                  _selectedSessions.add(session);
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
class TrainingSessionCard extends StatelessWidget {
  final TrainingSession session;
  final String Function(Duration) onFormatDuration;
  final VoidCallback onWorkoutUpdated;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onSelected;

  const TrainingSessionCard({
    required super.key,
    required this.session,
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
                    child: Row(
                      children: [
                        if (session.workoutType == 'rounds') ...[
                          const Icon(Icons.sports_mma, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            session.name,
                            style: theme.textTheme.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
                                        WorkoutTimerScreen(session: session),
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
                                if (session.workoutType == 'rounds') {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CreateRoundsScreen(session: session),
                                    ),
                                  );
                                } else {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => EditWorkoutScreen(
                                        trainingSession: session,
                                      ),
                                    ),
                                  );
                                }
                                onWorkoutUpdated();
                                break;
                              case 'notes':
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        WorkoutNotesScreen(session: session),
                                  ),
                                );
                                onWorkoutUpdated();
                                break;
                              case 'preview':
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        WorkoutPreviewScreen(session: session),
                                  ),
                                );
                                break;
                              case 'duplicate':
                                final repo = Provider.of<WorkoutRepository>(
                                  context,
                                  listen: false,
                                );
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  final originalSession = await repo
                                      .getTrainingSession(session.id);
                                  if (originalSession == null) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Не удалось найти тренировку для копирования',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  String generateId() =>
                                      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
                                  final newSession = originalSession.copyWith(
                                    id: generateId(),
                                    name: '${originalSession.name} (1)',
                                    blocks: originalSession.blocks.map((block) {
                                      return block.copyWith(
                                        id: generateId(),
                                        sets: block.sets.map((set) {
                                          return set.copyWith(
                                            id: generateId(),
                                            items: set.items.map((item) {
                                              return item.copyWith(
                                                id: generateId(),
                                              );
                                            }).toList(),
                                          );
                                        }).toList(),
                                      );
                                    }).toList(),
                                  );
                                  await repo.saveTrainingSession(newSession);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Тренировка "${session.name}" скопирована',
                                      ),
                                    ),
                                  );
                                  onWorkoutUpdated();
                                } catch (e) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Ошибка при копировании тренировки',
                                      ),
                                    ),
                                  );
                                }
                                break;
                              case 'delete':
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Удалить тренировку?'),
                                    content: Text(
                                      'Тренировка "${session.name}" будет удалена навсегда.',
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
                                  final repo = Provider.of<WorkoutRepository>(
                                    context,
                                    listen: false,
                                  );
                                  await repo.deleteTrainingSession(session.id);
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
              // ...workout.previewLines.map(
              //   (line) => Text(line, style: theme.textTheme.bodyMedium),
              // ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // if (workout.hasSettings)
                  //   const Chip(
                  //     avatar: Icon(Icons.tune, size: 16),
                  //     label: Text('Есть настройки'),
                  //   ),
                  if (session.notes != null && session.notes!.isNotEmpty)
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
