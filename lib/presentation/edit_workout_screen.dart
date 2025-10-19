import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tick_coach/domain/models/training_session.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:tick_coach/application/edit_workout_notifier.dart';
import 'package:tick_coach/data/services/vosk_service.dart';
import 'package:tick_coach/domain/repositories/workout_repository.dart';

import 'dart:io';

import 'dart:math';

class EditWorkoutScreen extends StatelessWidget {
  final TrainingSession trainingSession;
  const EditWorkoutScreen({super.key, required this.trainingSession});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => EditWorkoutNotifier(
        context.read<WorkoutRepository>(),
        context.read<VoskService>(),
        trainingSession,
      ),
      child: const _EditWorkoutScreenView(),
    );
  }
}

class _EditWorkoutScreenView extends StatefulWidget {
  const _EditWorkoutScreenView();

  @override
  State<_EditWorkoutScreenView> createState() => _EditWorkoutScreenViewState();
}

class _EditWorkoutScreenViewState extends State<_EditWorkoutScreenView> {
  final _scrollController = ScrollController();
  StreamSubscription? _closeChatSubscription;

  @override
  void initState() {
    super.initState();
    // Defer access to context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = context.read<EditWorkoutNotifier>();
      _closeChatSubscription = notifier.closeVoiceChatStream.listen((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _closeChatSubscription?.cancel();
    super.dispose();
  }

  Future<void> _showEditTitleDialog(EditWorkoutNotifier notifier) async {
    final controller = TextEditingController(text: notifier.session.name);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Название тренировки'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Введите название',
            hintText: 'Например: Грудь и плечи',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      notifier.updateSessionName(result);
    }
  }

  Future<void> _showEditBlockLabelDialog(
    EditWorkoutNotifier notifier,
    Block block,
  ) async {
    final controller = TextEditingController(text: block.label ?? block.type);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Название блока'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Введите название',
            hintText: 'Например: Разминка',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      notifier.updateBlockLabel(block, result);
    }
  }

  Future<void> _showSetRepeatDialog(
    EditWorkoutNotifier notifier,
    Set set,
  ) async {
    final controller = TextEditingController(text: set.repeat.toString());
    final newCountStr = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Количество повторов сета'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Укажите количество'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (newCountStr != null) {
      final newCount = int.tryParse(newCountStr);
      if (newCount != null && newCount > 0) {
        notifier.updateSetRepeat(set, newCount);
      }
    }
  }

  Future<void> _showVoiceChatBottomSheet(BuildContext context) {
    final notifier = context.read<EditWorkoutNotifier>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider<EditWorkoutNotifier>.value(
        value: notifier,
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.4,
          maxChildSize: 1.0,
          builder: (BuildContext context, ScrollController scrollController) {
            return _VoiceChatView(
              notifier: notifier,
              scrollController: scrollController,
            );
          },
        ),
      ),
    );
  }

  void _handleVoiceFabTap(
    BuildContext context,
    EditWorkoutNotifier notifier,
    bool isListening,
  ) {
    if (isListening) {
      notifier.toggleListening();
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } else {
      notifier.clearConversationLog();
      notifier.toggleListening();
      _showVoiceChatBottomSheet(context).whenComplete(() {
        if (context.read<EditWorkoutNotifier>().voskState ==
            VoskState.listening) {
          context.read<EditWorkoutNotifier>().toggleListening();
        }
      });
    }
  }

  Future<void> _saveWorkout(EditWorkoutNotifier notifier) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Сохранение...')));

    final success = await notifier.saveWorkout();
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    if (success) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Тренировка сохранена!')),
      );
      Navigator.of(context).pop();
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Ошибка сохранения')),
      );
    }
  }

  Widget _buildBody(EditWorkoutNotifier notifier) {
    return ReorderableListView.builder(
      scrollController: _scrollController,
      buildDefaultDragHandles: false,
      proxyDecorator: (widget, index, animation) {
        return Material(
          elevation: 4.0,
          color: Colors.transparent,
          child: widget,
        );
      },
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88), // Space for FAB
      itemCount: notifier.session.blocks.length,
      itemBuilder: (context, index) {
        final block = notifier.session.blocks[index];
        return _BlockCard(
          key: ValueKey(block.id),
          index: index,
          isContext: notifier.context == block,
          block: block,
          onAddSet: () => notifier.addSet(block),
          onEditLabel: () => _showEditBlockLabelDialog(notifier, block),
          onDelete: () => notifier.deleteBlock(index),
          onDuplicate: () => notifier.duplicateBlock(index),
          onDuplicateSet: (block, set) => notifier.duplicateSet(block, set),
          onAddExercise: (set) => notifier.addExercise(set),
          onAddRest: (set) => notifier.addRest(set),
          onDeleteItem: (set, item) => notifier.deleteItem(set, item),
          onDeleteSet: (block, set) => notifier.deleteSet(block, set),
          isSetContext: (set) => notifier.context == set,
          onShowSetRepeatDialog: (set) => _showSetRepeatDialog(notifier, set),
          onReorderSet: (set, oldIndex, newIndex) =>
              notifier.reorderSetItem(set, oldIndex, newIndex),
          onReorderSetsInBlock: (block, oldIndex, newIndex) =>
              notifier.reorderSetsInBlock(block, oldIndex, newIndex),
          onDuplicateItem: (set, item) => notifier.duplicateItem(set, item),
          onInsertItem: (set, index, item) =>
              notifier.insertItem(set, index, item),
          onPickImage: (exercise) => notifier.pickImage(exercise),
          onRemoveImage: (exercise) => notifier.removeImage(exercise),
          generateId: () =>
              '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}',
        );
      },
      onReorder: (oldIndex, newIndex) =>
          notifier.reorderBlock(oldIndex, newIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<EditWorkoutNotifier>();
    final voskState = notifier.voskState;
    final isListening = voskState == VoskState.listening;
    return Scaffold(
      backgroundColor: isListening
          ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3)
          : null,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        title: Semantics(
          button: true,
          label: 'Название тренировки: ${notifier.session.name}',
          onTapHint: 'Редактировать название',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              HapticFeedback.selectionClick();
              _showEditTitleDialog(notifier);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 6.0,
                horizontal: 8.0,
              ),
              child: Text(notifier.session.name),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_sharp),
            tooltip: 'Сохранить',
            onPressed: () => _saveWorkout(notifier),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(notifier),
      floatingActionButton: Consumer<EditWorkoutNotifier>(
        builder: (context, notifier, child) {
          final voskState = notifier.voskState;
          final isListening = voskState == VoskState.listening;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: 'voiceInputFab',
                onPressed:
                    (voskState == VoskState.ready ||
                        voskState == VoskState.listening)
                    ? () => _handleVoiceFabTap(context, notifier, isListening)
                    : null,
                tooltip: 'Голосовой ввод',
                backgroundColor: isListening
                    ? Theme.of(context).colorScheme.tertiaryContainer
                    : null,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: isListening
                      ? const Icon(Icons.mic_off, key: ValueKey('listening'))
                      : const Icon(Icons.mic, key: ValueKey('ready')),
                ),
              ),
              const SizedBox(height: 16),
              child!,
            ],
          );
        },
        child: FloatingActionButton(
          heroTag: 'addBlockFab',
          onPressed: () => context.read<EditWorkoutNotifier>().addBlock(),
          tooltip: 'Добавить блок',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  final Block block;
  final bool isContext;
  final int index;
  final VoidCallback onAddSet;
  final VoidCallback onEditLabel;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final void Function(Set) onAddExercise;
  final void Function(Set) onAddRest;
  final void Function(Set, SetItem) onDeleteItem;
  final void Function(Block, Set) onDeleteSet;
  final bool Function(Set) isSetContext;
  final void Function(Set, int, int) onReorderSet;
  final void Function(Block, int, int) onReorderSetsInBlock;
  final void Function(Set) onShowSetRepeatDialog;
  final void Function(Set, SetItem) onDuplicateItem;
  final void Function(Set, int, SetItem) onInsertItem;
  final Future<void> Function(Exercise) onPickImage;
  final void Function(Exercise) onRemoveImage;
  final void Function(Block, Set) onDuplicateSet;
  final String Function() generateId;

  const _BlockCard({
    super.key,
    required this.block,
    required this.isContext,
    required this.index,
    required this.onAddSet,
    required this.onEditLabel,
    required this.onDelete,
    required this.onDuplicate,
    required this.onDuplicateSet,
    required this.onDeleteSet,
    required this.onAddExercise,
    required this.onAddRest,
    required this.onDeleteItem,
    required this.onReorderSet,
    required this.onReorderSetsInBlock,
    required this.onShowSetRepeatDialog,
    required this.onDuplicateItem,
    required this.onInsertItem,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.generateId,
    required this.isSetContext,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: isContext
          ? RoundedRectangleBorder(
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                block.label ?? block.type,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEditLabel();
                if (value == 'delete') onDelete();
                if (value == 'duplicate') onDuplicate();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Переименовать'),
                ),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Text('Копировать блок'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Удалить блок',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          ReorderableListView.builder(
            buildDefaultDragHandles: false,
            proxyDecorator: (widget, index, animation) {
              return Material(
                elevation: 4.0,
                color: Colors.transparent,
                child: widget,
              );
            },
            itemCount: block.sets.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final set = block.sets[index];
              return _SetCard(
                key: ValueKey(set.id),
                index: index,
                isContext: isSetContext(set),
                set: set,
                onAddExercise: () => onAddExercise(set),
                onAddRest: () => onAddRest(set),
                onDelete: () => onDeleteSet(block, set),
                onDuplicate: () => onDuplicateSet(block, set),
                onDeleteItem: (item) => onDeleteItem(set, item),
                onReorder: (oldIndex, newIndex) =>
                    onReorderSet(set, oldIndex, newIndex),
                onShowSetRepeatDialog: () => onShowSetRepeatDialog(set),
                onDuplicateItem: (item) => onDuplicateItem(set, item),
                onInsertItem: (idx, item) => onInsertItem(set, idx, item),
                onPickImage: onPickImage,
                onRemoveImage: onRemoveImage,
                generateId: generateId,
              );
            },
            onReorder: (old, newIdx) =>
                onReorderSetsInBlock(block, old, newIdx),
          ),
          const SizedBox(height: 8),
          Center(
            child: ElevatedButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add),
              label: const Text('Добавить сет'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SetCard extends StatelessWidget {
  final Set set;
  final bool isContext;
  final int index;
  final VoidCallback onAddExercise;
  final VoidCallback onAddRest;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final void Function(SetItem) onDeleteItem;
  final void Function(int, int) onReorder;
  final VoidCallback onShowSetRepeatDialog;
  final void Function(SetItem) onDuplicateItem;
  final void Function(int, SetItem) onInsertItem;
  final Future<void> Function(Exercise) onPickImage;
  final void Function(Exercise) onRemoveImage;
  final String Function() generateId;

  const _SetCard({
    super.key,
    required this.set,
    required this.isContext,
    required this.index,
    required this.onAddExercise,
    required this.onAddRest,
    required this.onDelete,
    required this.onDuplicate,
    required this.onDeleteItem,
    required this.onReorder,
    required this.onShowSetRepeatDialog,
    required this.onDuplicateItem,
    required this.onInsertItem,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.generateId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
        shape: isContext
            ? RoundedRectangleBorder(
                side: BorderSide(
                  color: Theme.of(context).colorScheme.secondary,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          title: Text(set.label ?? 'Сет'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: onShowSetRepeatDialog,
                child: Text('x ${set.repeat}'),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                  if (value == 'duplicate') onDuplicate();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Копировать сет'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Удалить сет',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                proxyDecorator: (widget, index, animation) {
                  return Material(
                    elevation: 4.0,
                    color: Colors.transparent,
                    child: widget,
                  );
                },
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: set.items.length,
                itemBuilder: (context, index) {
                  final item = set.items[index];
                  if (item is Exercise) {
                    return _ExerciseItemCard(
                      key: ValueKey(item.id),
                      exercise: item,
                      index: index,
                      onDelete: () => onDeleteItem(item),
                      onDuplicate: () => onDuplicateItem(item),
                      onInsert: (idx, item) => onInsertItem(idx, item),
                      onPickImage: () => onPickImage(item),
                      onRemoveImage: () => onRemoveImage(item),
                      generateId: generateId,
                    );
                  }
                  if (item is Rest) {
                    return _RestItemCard(
                      key: ValueKey(item.id),
                      rest: item,
                      index: index,
                      onDelete: () => onDeleteItem(item),
                      onDuplicate: () => onDuplicateItem(item),
                      onInsert: (idx, item) => onInsertItem(idx, item),
                      generateId: generateId,
                    );
                  }
                  return SizedBox.shrink(key: ValueKey(item.id));
                },
                onReorder: onReorder,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 8.0, bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onAddExercise,
                    icon: const Icon(Icons.fitness_center),
                    label: const Text('Упражнение'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onAddRest,
                    icon: const Icon(Icons.pause),
                    label: const Text('Отдых'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseItemCard extends StatefulWidget {
  final Exercise exercise;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final void Function(int, SetItem) onInsert;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final String Function() generateId;

  const _ExerciseItemCard({
    super.key,
    required this.exercise,
    required this.index,
    required this.onDelete,
    required this.onDuplicate,
    required this.onInsert,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.generateId,
  });

  @override
  State<_ExerciseItemCard> createState() => _ExerciseItemCardState();
}

class _ExerciseItemCardState extends State<_ExerciseItemCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _valueController;
  late final TextEditingController _loadController;
  late final TextEditingController _tempoController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.exercise.name);
    _valueController = TextEditingController(
      text: widget.exercise.isRepsBased
          ? widget.exercise.reps.toString()
          : widget.exercise.durationSec.toString(),
    );
    _loadController = TextEditingController(
      text: widget.exercise.loadKg?.toString() ?? '',
    );
    _tempoController = TextEditingController(text: widget.exercise.tempo ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _loadController.dispose();
    _tempoController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ExerciseItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.exercise.isRepsBased
        ? widget.exercise.reps.toString()
        : widget.exercise.durationSec.toString();
    if (_valueController.text != newText) {
      _valueController.text = newText;
    }
    if (widget.exercise.name != _nameController.text) {
      _nameController.text = widget.exercise.name;
    }
  }

  void _changeValue(int delta) {
    setState(() {
      if (widget.exercise.isRepsBased) {
        final newValue = (widget.exercise.reps + delta).clamp(0, 1000);
        widget.exercise.reps = newValue;
        _valueController.text = newValue.toString();
      } else {
        final newValue = (widget.exercise.durationSec + delta).clamp(0, 86400);
        widget.exercise.durationSec = newValue;
        _valueController.text = newValue.toString();
      }
    });
  }

  void _toggleMetric() {
    setState(() {
      widget.exercise.isRepsBased = !widget.exercise.isRepsBased;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitLabel = widget.exercise.isRepsBased ? 'повт.' : 'сек.';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReorderableDragStartListener(
                index: widget.index,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 12.0),
                  child: Icon(Icons.drag_handle),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Упражнение/описание',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (value) => widget.exercise.name = value,
                        textCapitalization: TextCapitalization.sentences,
                        style: theme.textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.remove),
                            onPressed: () => _changeValue(-1),
                          ),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 60),
                              child: TextField(
                                controller: _valueController,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  suffixText: unitLabel,
                                  suffixStyle: theme.textTheme.bodyLarge,
                                ),
                                style: theme.textTheme.bodyLarge,
                                onChanged: (txt) {
                                  final v = int.tryParse(txt) ?? 0;
                                  setState(() {
                                    if (widget.exercise.isRepsBased) {
                                      widget.exercise.reps = v.clamp(0, 1000);
                                    } else {
                                      widget.exercise.durationSec = v.clamp(
                                        0,
                                        86400,
                                      );
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.add),
                            onPressed: () => _changeValue(1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  widget.exercise.isRepsBased
                      ? Icons.repeat
                      : Icons.timer_outlined,
                ),
                onPressed: _toggleMetric,
                tooltip:
                    'Сменить на ${widget.exercise.isRepsBased ? "время" : "повторения"}',
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'delete':
                      widget.onDelete();
                      break;
                    case 'duplicate':
                      widget.onDuplicate();
                      break;
                    case 'insert_ex_above':
                      widget.onInsert(
                        widget.index,
                        Exercise(
                          id: widget.generateId(),
                          name: 'Новое упражнение',
                        ),
                      );
                      break;
                    case 'insert_rest_above':
                      widget.onInsert(
                        widget.index,
                        Rest(id: widget.generateId(), durationSec: 60),
                      );
                      break;
                    case 'insert_ex_below':
                      widget.onInsert(
                        widget.index + 1,
                        Exercise(
                          id: widget.generateId(),
                          name: 'Новое упражнение',
                        ),
                      );
                      break;
                    case 'insert_rest_below':
                      widget.onInsert(
                        widget.index + 1,
                        Rest(id: widget.generateId(), durationSec: 60),
                      );
                      break;
                    case 'add_photo':
                      widget.onPickImage();
                      break;
                    case 'remove_photo':
                      widget.onRemoveImage();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Копировать'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'insert_ex_above',
                    child: Text('Вставить упражнение выше'),
                  ),
                  const PopupMenuItem(
                    value: 'insert_rest_above',
                    child: Text('Вставить отдых выше'),
                  ),
                  const PopupMenuItem(
                    value: 'insert_ex_below',
                    child: Text('Вставить упражнение ниже'),
                  ),
                  const PopupMenuItem(
                    value: 'insert_rest_below',
                    child: Text('Вставить отдых ниже'),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'add_photo',
                    child: Text(
                      widget.exercise.imageUri == null
                          ? 'Добавить фото'
                          : 'Изменить фото',
                    ),
                  ),
                  if (widget.exercise.imageUri != null)
                    const PopupMenuItem(
                      value: 'remove_photo',
                      child: Text('Удалить фото'),
                    ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Удалить',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _loadController,
                    decoration: const InputDecoration(
                      labelText: 'Вес, кг',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) =>
                        widget.exercise.loadKg = double.tryParse(value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _tempoController,
                    decoration: const InputDecoration(
                      labelText: 'Темп',
                      hintText: '3-1-1',
                      isDense: true,
                    ),
                    onChanged: (value) => widget.exercise.tempo = value,
                  ),
                ),
              ],
            ),
          ),
          if (widget.exercise.imageUri != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.file(
                  File(widget.exercise.imageUri!),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RestItemCard extends StatefulWidget {
  final Rest rest;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final void Function(int, SetItem) onInsert;
  final String Function() generateId;

  const _RestItemCard({
    super.key,
    required this.rest,
    required this.index,
    required this.onDelete,
    required this.onDuplicate,
    required this.onInsert,
    required this.generateId,
  });

  @override
  State<_RestItemCard> createState() => _RestItemCardState();
}

class _RestItemCardState extends State<_RestItemCard> {
  late final TextEditingController _durationController;
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(
      text: widget.rest.durationSec.toString(),
    );
    _reasonController = TextEditingController(text: widget.rest.reason);
  }

  @override
  void dispose() {
    _durationController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _RestItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rest.durationSec.toString() != _durationController.text) {
      _durationController.text = widget.rest.durationSec.toString();
    }
  }

  void _changeDuration(int delta) {
    setState(() {
      final newDuration = (widget.rest.durationSec + delta).clamp(0, 86400);
      widget.rest.durationSec = newDuration;
      _durationController.text = newDuration.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: theme.colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: widget.index,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 16.0),
              child: Icon(Icons.drag_handle),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 8),
                  child: TextField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Тип отдыха',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (value) => widget.rest.reason = value,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove),
                      onPressed: () => _changeDuration(-5),
                    ),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 60),
                        child: TextField(
                          controller: _durationController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            suffixText: ' сек',
                          ),
                          onChanged: (value) {
                            final newDuration = int.tryParse(value) ?? 0;
                            setState(() {
                              widget.rest.durationSec = newDuration;
                            });
                          },
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add),
                      onPressed: () => _changeDuration(5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'delete':
                  widget.onDelete();
                  break;
                case 'duplicate':
                  widget.onDuplicate();
                  break;
                case 'insert_ex_above':
                  widget.onInsert(
                    widget.index,
                    Exercise(id: widget.generateId(), name: 'Новое упражнение'),
                  );
                  break;
                case 'insert_rest_above':
                  widget.onInsert(
                    widget.index,
                    Rest(id: widget.generateId(), durationSec: 60),
                  );
                  break;
                case 'insert_ex_below':
                  widget.onInsert(
                    widget.index + 1,
                    Exercise(id: widget.generateId(), name: 'Новое упражнение'),
                  );
                  break;
                case 'insert_rest_below':
                  widget.onInsert(
                    widget.index + 1,
                    Rest(id: widget.generateId(), durationSec: 60),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'duplicate',
                child: Text('Копировать'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'insert_ex_above',
                child: Text('Вставить упражнение выше'),
              ),
              const PopupMenuItem(
                value: 'insert_rest_above',
                child: Text('Вставить отдых выше'),
              ),
              const PopupMenuItem(
                value: 'insert_ex_below',
                child: Text('Вставить упражнение ниже'),
              ),
              const PopupMenuItem(
                value: 'insert_rest_below',
                child: Text('Вставить отдых ниже'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Удалить',
                  style: TextStyle(color: theme.colorScheme.error),
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

class _VoiceChatView extends StatelessWidget {
  final EditWorkoutNotifier notifier;
  final ScrollController scrollController;

  const _VoiceChatView({
    required this.notifier,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48),
                Text('Голосовой помощник', style: theme.textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<EditWorkoutNotifier>(
              builder: (context, notifier, child) {
                final listScrollController = ScrollController();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (listScrollController.hasClients) {
                    listScrollController.animateTo(
                      listScrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                });
                return ListView.builder(
                  controller: listScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: notifier.conversationLog.length,
                  itemBuilder: (context, index) {
                    final message = notifier.conversationLog[index];
                    final isUserMessage = message.startsWith('You:');
                    final alignment = isUserMessage
                        ? Alignment.centerRight
                        : Alignment.centerLeft;
                    final color = isUserMessage
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest;
                    return Align(
                      alignment: alignment,
                      child: Card(
                        color: color,
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(message),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
