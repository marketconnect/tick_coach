import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tick_coach/domain/models/training_session.dart';
import 'package:tick_coach/domain/repositories/workout_repository.dart';

class WorkoutPreviewScreen extends StatefulWidget {
  final TrainingSession session;
  final String? highlightedItemId;

  const WorkoutPreviewScreen({
    super.key,
    required this.session,
    this.highlightedItemId,
  });

  @override
  State<WorkoutPreviewScreen> createState() => _WorkoutPreviewScreenState();
}

class _WorkoutPreviewScreenState extends State<WorkoutPreviewScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  TrainingSession? _fullSession;
  final Map<String, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    _fetchWorkoutDetails();
  }

  void _scrollToHighlightedItem() {
    if (widget.highlightedItemId == null) return;

    final key = _itemKeys[widget.highlightedItemId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
  }

  Future<void> _fetchWorkoutDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final repo = Provider.of<WorkoutRepository>(context, listen: false);
      final session = await repo.getTrainingSession(widget.session.id);
      if (!mounted) return;
      setState(() {
        _fullSession = session;
        _isLoading = false;

        if (_fullSession != null) {
          for (var block in _fullSession!.blocks) {
            for (var set in block.sets) {
              for (var item in set.items) {
                _itemKeys[item.id] = GlobalKey();
              }
            }
          }
        }
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToHighlightedItem(),
      );
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (set.label != null)
                              Expanded(
                                child: Text(
                                  set.label!,
                                  style: textTheme.titleMedium,
                                ),
                              ),
                            Text('x ${set.repeat}'),
                          ],
                        ),
                        const Divider(),
                        ...set.items.map((item) {
                          final isHighlighted =
                              item is Exercise &&
                              item.id == widget.highlightedItemId;

                          Widget child;
                          if (item is Exercise) {
                            child = ListTile(
                              title: Text(item.name),
                              leading: const Icon(Icons.fitness_center),
                              subtitle: Text(
                                '${item.isRepsBased ? '${item.reps} повт.' : '${item.durationSec} сек'}${item.loadKg != null ? ' @ ${item.loadKg} кг' : ''}',
                              ),
                            );
                          } else if (item is Rest) {
                            child = ListTile(
                              title: Text(item.reason ?? 'Отдых'),
                              leading: const Icon(Icons.pause),
                              subtitle: Text('${item.durationSec} сек'),
                            );
                          } else {
                            return const SizedBox.shrink();
                          }

                          return Container(
                            key: _itemKeys[item.id],
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: isHighlighted
                                ? BoxDecoration(
                                    color: colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: colorScheme.secondary,
                                      width: 2,
                                    ),
                                  )
                                : null,
                            child: child,
                          );
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
