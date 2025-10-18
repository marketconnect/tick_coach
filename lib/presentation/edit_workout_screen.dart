import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tick_coach/domain/models/training_session.dart';

import '../utils/database_helper.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:math';

class EditWorkoutScreen extends StatefulWidget {
  final TrainingSession trainingSession;
  const EditWorkoutScreen({super.key, required this.trainingSession});

  @override
  State<EditWorkoutScreen> createState() => _EditWorkoutScreenState();
}

class _EditWorkoutScreenState extends State<EditWorkoutScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  late TrainingSession _session;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _session = widget.trainingSession;
    _isLoading = false; // Data is passed in directly
  }

  String _generateId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _showEditTitleDialog() async {
    final controller = TextEditingController(text: _session.name);
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
      setState(() => _session.name = result);
    }
  }

  void _addBlock() {
    setState(() {
      _session.blocks.add(
        Block(id: _generateId(), type: 'Основная часть', sets: []),
      );
    });
  }

  void _addSet(Block block) {
    setState(() {
      block.sets.add(Set(id: _generateId(), items: []));
    });
  }

  void _addExercise(Set set) {
    setState(() {
      set.items.add(Exercise(id: _generateId(), name: 'Новое упражнение'));
    });
  }

  void _insertItem(Set targetSet, int index, SetItem item) {
    setState(() {
      targetSet.items.insert(index, item);
    });
  }

  void _duplicateBlock(int blockIndex) {
    setState(() {
      final originalBlock = _session.blocks[blockIndex];
      final newBlock = Block(
        id: _generateId(),
        type: originalBlock.type,
        label: originalBlock.label,
        sets: originalBlock.sets.map((s) {
          return s.copyWith(
            id: _generateId(),
            items: s.items.map((i) => i.copyWith(id: _generateId())).toList(),
          );
        }).toList(),
      );
      _session.blocks.insert(blockIndex + 1, newBlock);
    });
  }

  void _duplicateSet(Block block, Set originalSet) {
    setState(() {
      final newSet = originalSet.copyWith(
        id: _generateId(),
        items: originalSet.items
            .map((i) => i.copyWith(id: _generateId()))
            .toList(),
      );
      final originalIndex = block.sets.indexOf(originalSet);
      block.sets.insert(originalIndex + 1, newSet);
    });
  }

  void _duplicateItem(Set set, SetItem originalItem) {
    setState(() {
      final newItem = originalItem.copyWith(id: _generateId());
      final originalIndex = set.items.indexOf(originalItem);
      set.items.insert(originalIndex + 1, newItem);
    });
  }

  Future<void> _pickImage(Exercise exercise) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        exercise.imageUri = pickedFile.path;
      });
    }
  }

  void _removeImage(Exercise exercise) {
    setState(() {
      exercise.imageUri = null;
    });
  }

  void _deleteBlock(int blockIndex) {
    setState(() {
      _session.blocks.removeAt(blockIndex);
    });
  }

  void _deleteSet(Block block, Set setToDelete) {
    setState(() {
      block.sets.remove(setToDelete);
    });
  }

  void _deleteItem(Set set, SetItem itemToDelete) {
    setState(() {
      set.items.remove(itemToDelete);
    });
  }

  Future<void> _showSetRepeatDialog(Set set) async {
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
        setState(() => set.repeat = newCount);
      }
    }
  }

  void _addRest(Set set) {
    setState(() {
      set.items.add(Rest(id: _generateId(), durationSec: 60));
    });
  }

  Future<void> _saveWorkout() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Сохранение...')));

    try {
      await DatabaseHelper.instance.saveTrainingSession(_session);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Тренировка сохранена!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88), // Space for FAB
      itemCount: _session.blocks.length,
      itemBuilder: (context, index) {
        final block = _session.blocks[index];
        return _BlockCard(
          key: ValueKey(block.id),
          block: block,
          onAddSet: () => _addSet(block),

          onDelete: () => _deleteBlock(index),
          onDuplicate: () => _duplicateBlock(index),
          onDuplicateSet: _duplicateSet,
          onAddExercise: _addExercise,
          onAddRest: _addRest,
          onDeleteItem: _deleteItem,
          onDeleteSet: _deleteSet,
          onShowSetRepeatDialog: _showSetRepeatDialog,
          onReorderSet: (set, oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = set.items.removeAt(oldIndex);
              set.items.insert(newIndex, item);
            });
          },
          onDuplicateItem: _duplicateItem,
          onInsertItem: _insertItem,
          onPickImage: _pickImage,
          onRemoveImage: _removeImage,
          generateId: _generateId,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        title: Semantics(
          button: true,
          label: 'Название тренировки: ${_session.name}',
          onTapHint: 'Редактировать название',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              HapticFeedback.selectionClick();
              _showEditTitleDialog();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 6.0,
                horizontal: 8.0,
              ),
              child: Text(_session.name),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_sharp),
            tooltip: 'Сохранить',
            onPressed: _saveWorkout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBlock,
        tooltip: 'Добавить блок',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  final Block block;
  final VoidCallback onAddSet;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final void Function(Set) onAddExercise;
  final void Function(Set) onAddRest;
  final void Function(Set, SetItem) onDeleteItem;
  final void Function(Block, Set) onDeleteSet;
  final void Function(Set, int, int) onReorderSet;
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
    required this.onAddSet,
    required this.onDelete,
    required this.onDuplicate,
    required this.onDuplicateSet,
    required this.onDeleteSet,
    required this.onAddExercise,
    required this.onAddRest,
    required this.onDeleteItem,
    required this.onReorderSet,
    required this.onShowSetRepeatDialog,
    required this.onDuplicateItem,
    required this.onInsertItem,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.generateId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        title: Text(
          block.label ?? block.type,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') onDelete();
                if (value == 'duplicate') onDuplicate();
              },
              itemBuilder: (context) => [
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
          for (final set in block.sets)
            _SetCard(
              key: ValueKey(set.id),
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
              onInsertItem: (index, item) => onInsertItem(set, index, item),
              onPickImage: onPickImage,
              onRemoveImage: onRemoveImage,
              generateId: generateId,
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
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          ListTile(
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
          ),
          ReorderableListView.builder(
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
        ],
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
        widget.exercise.reps = (widget.exercise.reps + delta).clamp(0, 1000);
      } else {
        widget.exercise.durationSec = (widget.exercise.durationSec + delta)
            .clamp(0, 86400);
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
                  padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
                  child: Icon(Icons.drag_handle),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () => _changeValue(-1),
                      ),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 72,
                            maxWidth: 140,
                          ),
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
                        icon: const Icon(Icons.add),
                        onPressed: () => _changeValue(1),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Упражнение/описание',
              ),
              onChanged: (value) => widget.exercise.name = value,
              textCapitalization: TextCapitalization.sentences,
            ),
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
      widget.rest.durationSec = (widget.rest.durationSec + delta).clamp(
        0,
        86400,
      );
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
              padding: EdgeInsets.all(16.0),
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
                      icon: const Icon(Icons.remove),
                      onPressed: () => _changeDuration(-5),
                    ),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
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
