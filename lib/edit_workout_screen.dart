import 'package:flutter/material.dart';
import 'workouts_screen.dart';
import 'dart:ui';

// Domain models from the spec
enum IntervalKind {
  prepare,
  work,
  rest,
  between_sets,
  calmdown,
  work_and_rest,
  custom,
}

class Interval {
  String id;
  IntervalKind kind;
  String? title;
  String? description;
  int durationSec;
  String? imageUri;

  Interval({
    required this.id,
    required this.kind,
    this.title,
    this.description,
    required this.durationSec,
    this.imageUri,
  });
}

class EditWorkoutScreen extends StatefulWidget {
  final Workout workout;

  const EditWorkoutScreen({super.key, required this.workout});

  @override
  State<EditWorkoutScreen> createState() => _EditWorkoutScreenState();
}

class _EditWorkoutScreenState extends State<EditWorkoutScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Interval> _intervals = [];
  int _nextId = 100;

  @override
  void initState() {
    super.initState();
    _fetchIntervals();
  }

  void _insertIntervals(int index, List<IntervalKind> kinds) {
    setState(() {
      final newIntervals = kinds.map((kind) {
        _nextId++;
        String title;
        int duration;
        switch (kind) {
          case IntervalKind.prepare:
            title = 'Подготовка';
            duration = 10;
            break;
          case IntervalKind.work:
            title = 'Работа';
            duration = 30;
            break;
          case IntervalKind.rest:
            title = 'Отдых';
            duration = 15;
            break;
          default:
            title = kind.name.capitalize();
            duration = 60;
        }
        return Interval(
          id: _nextId.toString(),
          kind: kind,
          durationSec: duration,
          title: title,
        );
      }).toList();
      _intervals.insertAll(index, newIntervals);
    });
  }

  Future<void> _fetchIntervals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate loading
    setState(() {
      _intervals = [
        Interval(
          id: '1',
          kind: IntervalKind.prepare,
          durationSec: 10,
          title: 'Подготовка',
        ),
        Interval(
          id: '2',
          kind: IntervalKind.work,
          durationSec: 20,
          title: 'Упражнение 1',
        ),
        Interval(
          id: '3',
          kind: IntervalKind.rest,
          durationSec: 10,
          title: 'Отдых',
        ),
        Interval(
          id: '4',
          kind: IntervalKind.work,
          durationSec: 20,
          title: 'Упражнение 2',
        ),
        Interval(
          id: '5',
          kind: IntervalKind.rest,
          durationSec: 10,
          title: 'Отдых',
        ),
        Interval(
          id: '6',
          kind: IntervalKind.calmdown,
          durationSec: 30,
          title: 'Заминка',
        ),
      ];
      _isLoading = false;
    });
  }

  void _changeDuration(String intervalId, int delta) {
    setState(() {
      final interval = _intervals.firstWhere((i) => i.id == intervalId);
      interval.durationSec = (interval.durationSec + delta).clamp(0, 86400);
    });
  }

  void _deleteInterval(String intervalId) {
    setState(() {
      _intervals.removeWhere((i) => i.id == intervalId);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _intervals.removeAt(oldIndex);
      _intervals.insert(newIndex, item);
    });
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Сохранить',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: MenuAnchor(
        builder: (context, controller, child) {
          return FloatingActionButton(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: const Icon(Icons.add),
          );
        },
        menuChildren: [
          MenuItemButton(
            onPressed: () =>
                _insertIntervals(_intervals.length, [IntervalKind.prepare]),
            child: const Text('Подготовка'),
          ),
          MenuItemButton(
            onPressed: () =>
                _insertIntervals(_intervals.length, [IntervalKind.work]),
            child: const Text('Работа'),
          ),
          MenuItemButton(
            onPressed: () =>
                _insertIntervals(_intervals.length, [IntervalKind.rest]),
            child: const Text('Отдых'),
          ),
          MenuItemButton(
            onPressed: () => _insertIntervals(_intervals.length, [
              IntervalKind.work,
              IntervalKind.rest,
            ]),
            child: const Text('Работа + Отдых'),
          ),
        ],
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
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88), // Space for FAB
      itemCount: _intervals.length,
      itemBuilder: (context, index) {
        final interval = _intervals[index];
        return IntervalCard(
          key: ValueKey(interval.id),
          interval: interval,
          index: index,
          formatDuration: _formatDuration,
          onDecrement: () => _changeDuration(interval.id, -5),
          onIncrement: () => _changeDuration(interval.id, 5),
          onDelete: () => _deleteInterval(interval.id),
          onInsert: _insertIntervals,
        );
      },
      onReorder: _onReorder,
    );
  }
}

class IntervalCard extends StatelessWidget {
  final Interval interval;
  final int index;
  final String Function(int) formatDuration;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDelete;
  final void Function(int index, List<IntervalKind> kinds) onInsert;

  const IntervalCard({
    super.key,
    required this.interval,
    required this.index,
    required this.formatDuration,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
    required this.onInsert,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: Icon(Icons.drag_handle),
            ),
          ),
          Expanded(
            child: Text(
              interval.title ?? interval.kind.name.capitalize(),
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: onDecrement,
            tooltip: 'Уменьшить',
          ),
          Text(
            formatDuration(interval.durationSec),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: onIncrement,
            tooltip: 'Увеличить',
          ),
          MenuAnchor(
            builder: (context, controller, child) {
              return IconButton(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Действия',
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
              );
            },
            menuChildren: [
              SubmenuButton(
                menuChildren: [
                  MenuItemButton(
                    onPressed: () => onInsert(index, [IntervalKind.prepare]),
                    child: const Text('Подготовка'),
                  ),
                  MenuItemButton(
                    onPressed: () => onInsert(index, [IntervalKind.work]),
                    child: const Text('Работа'),
                  ),
                  MenuItemButton(
                    onPressed: () => onInsert(index, [IntervalKind.rest]),
                    child: const Text('Отдых'),
                  ),
                  MenuItemButton(
                    onPressed: () =>
                        onInsert(index, [IntervalKind.work, IntervalKind.rest]),
                    child: const Text('Работа + Отдых'),
                  ),
                ],
                child: const Text('Вставить выше'),
              ),
              SubmenuButton(
                menuChildren: [
                  MenuItemButton(
                    onPressed: () =>
                        onInsert(index + 1, [IntervalKind.prepare]),
                    child: const Text('Подготовка'),
                  ),
                  MenuItemButton(
                    onPressed: () => onInsert(index + 1, [IntervalKind.work]),
                    child: const Text('Работа'),
                  ),
                  MenuItemButton(
                    onPressed: () => onInsert(index + 1, [IntervalKind.rest]),
                    child: const Text('Отдых'),
                  ),
                  MenuItemButton(
                    onPressed: () => onInsert(index + 1, [
                      IntervalKind.work,
                      IntervalKind.rest,
                    ]),
                    child: const Text('Работа + Отдых'),
                  ),
                ],
                child: const Text('Вставить ниже'),
              ),
              MenuItemButton(
                onPressed: () {
                  // TODO: Implement duplicate
                },
                child: const Text('Копировать'),
              ),
              MenuItemButton(
                onPressed: () {
                  // TODO: Implement attach image
                },
                child: const Text('Добавить фото'),
              ),
              const Divider(),
              MenuItemButton(
                onPressed: onDelete,
                child: Text(
                  'Удалить',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
