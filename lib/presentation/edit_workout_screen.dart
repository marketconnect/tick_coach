import 'package:flutter/material.dart' hide Interval;
import 'package:tick_coach/domain/models/interval.dart' show IntervalKind;
import 'package:tick_coach/domain/models/interval.dart' show Interval;
import 'workouts_screen.dart';
import 'package:flutter/services.dart';
import '../utils/database_helper.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:math';
import 'package:flutter/gestures.dart';

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
  int _setCount = 1;
  final _scrollController = ScrollController();
  late String _title;
  @override
  void initState() {
    super.initState();
    _title = widget.workout.title;
    _fetchIntervals();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _showEditTitleDialog() async {
    final controller = TextEditingController(text: _title);
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
      setState(() => _title = result);
    }
  }

  void _insertIntervals(int index, List<IntervalKind> kinds) {
    final isAppending = index >= _intervals.length;
    setState(() {
      final newIntervals = kinds.map((kind) {
        final newId =
            '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
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
          case IntervalKind.between_sets:
            title = 'Отдых между сетами';
            duration = 60;
            break;
          default:
            title = kind.name.capitalize();
            duration = 60;
        }
        return Interval(
          id: newId,
          kind: kind,
          durationSec: duration,
          title: title,
        );
      }).toList();
      final List<Interval> updatedList = List.from(_intervals)
        ..insertAll(index, newIntervals);
      _intervals = updatedList;
    });
    if (isAppending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _fetchIntervals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dbHelper = DatabaseHelper.instance;
      final intervals = await dbHelper.getIntervalsForWorkout(
        widget.workout.id,
      );
      final setCount = await dbHelper.getSetCountForWorkout(widget.workout.id);
      if (!mounted) return;
      setState(() {
        _intervals = intervals;
        _setCount = setCount;
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

  Future<void> _saveWorkout() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Сохранение...')));
    // Create a new workout object with the potentially updated title,
    // while preserving all other properties from the original workout object.
    final workoutToSave = Workout(
      id: widget.workout.id,
      title: _title,
      previewLines: widget.workout.previewLines,
      totalTime: widget.workout.totalTime,
      intervalsCount: widget.workout.intervalsCount,
      hasSettings: widget.workout.hasSettings,
      hasNotes: widget.workout.hasNotes,
      notes: widget.workout.notes,
      repeats: widget.workout.repeats,
    );
    try {
      await DatabaseHelper.instance.saveWorkout(
        widget.workout,
        _intervals,
        _setCount,
      );
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

  void _changeDuration(String intervalId, int delta) {
    setState(() {
      final interval = _intervals.firstWhere((i) => i.id == intervalId);

      if (interval.isRepsBased) {
        final repsDelta = delta > 0 ? 1 : -1;
        interval.reps = (interval.reps + repsDelta).clamp(0, 1000);
      } else {
        interval.durationSec = (interval.durationSec + delta).clamp(0, 86400);
      }
    });
  }

  void _deleteInterval(String intervalId) {
    setState(() {
      _intervals.removeWhere((i) => i.id == intervalId);
    });
  }

  void _updateIntervalDescription(String id, String description) {
    final interval = _intervals.firstWhere((i) => i.id == id);
    interval.description = description;
  }

  void _toggleMetric(String intervalId) {
    setState(() {
      final interval = _intervals.firstWhere((i) => i.id == intervalId);
      interval.isRepsBased = !interval.isRepsBased;
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

  Future<void> _showSetCountDialog() async {
    final controller = TextEditingController(text: _setCount.toString());
    final newCountStr = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Количество сетов'),
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
        setState(() => _setCount = newCount);
      }
    }
  }

  void _duplicateInterval(int index) {
    setState(() {
      final originalInterval = _intervals[index];
      final newId =
          '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      final newInterval = Interval(
        id: newId,
        kind: originalInterval.kind,
        title: originalInterval.title,
        description: originalInterval.description,
        durationSec: originalInterval.durationSec,
        reps: originalInterval.reps,
        isRepsBased: originalInterval.isRepsBased,
        imageUri: originalInterval.imageUri,
      );
      _intervals.insert(index + 1, newInterval);
    });
  }

  Future<void> _pickImageForInterval(String intervalId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        final interval = _intervals.firstWhere((i) => i.id == intervalId);
        interval.imageUri = pickedFile.path;
      });
    }
  }

  void _removeImageFromInterval(String intervalId) {
    setState(() {
      final interval = _intervals.firstWhere((i) => i.id == intervalId);
      interval.imageUri = null;
    });
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
          label: 'Название тренировки: $_title',
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
              child: Text(_title),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _showSetCountDialog,
            child: Text('Сеты: $_setCount'),
          ),
          IconButton(
            icon: const Icon(Icons.check_sharp),
            tooltip: 'Сохранить',
            onPressed: _saveWorkout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: MenuAnchor(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          elevation: WidgetStateProperty.all(3.0),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          ),
        ),
        builder: (context, controller, child) {
          return FloatingActionButton(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                HapticFeedback.selectionClick();
                controller.open();
              }
            },
            child: const Icon(Icons.add),
          );
        },
        menuChildren: [
          MenuItemButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              _insertIntervals(_intervals.length, [IntervalKind.prepare]);
            },
            child: const Text('Подготовка'),
          ),
          MenuItemButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              _insertIntervals(_intervals.length, [IntervalKind.work]);
            },
            child: const Text('Работа'),
          ),
          MenuItemButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              _insertIntervals(_intervals.length, [IntervalKind.rest]);
            },
            child: const Text('Отдых'),
          ),
          MenuItemButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              _insertIntervals(_intervals.length, [
                IntervalKind.work,
                IntervalKind.rest,
              ]);
            },
            child: const Text('Работа + Отдых'),
          ),
          MenuItemButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              _insertIntervals(_intervals.length, [IntervalKind.between_sets]);
            },
            child: const Text('Отдых между сетами'),
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
      scrollController: _scrollController,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88), // Space for FAB
      buildDefaultDragHandles: false, // перетаскивание только за ручку
      dragStartBehavior: DragStartBehavior.down, // отзывчивее старт драга
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _intervals.length,
      itemBuilder: (context, index) {
        final interval = _intervals[index];
        return IntervalCard(
          key: ValueKey(interval.id),
          interval: interval,
          index: index,
          formatDuration: _formatDuration,
          onDecrement: () => _changeDuration(interval.id, -1),
          onIncrement: () => _changeDuration(interval.id, 1),
          onDelete: () => _deleteInterval(interval.id),
          onInsert: _insertIntervals,
          onDescriptionChanged: (newDescription) =>
              _updateIntervalDescription(interval.id, newDescription),
          onToggleMetric: () => _toggleMetric(interval.id),
          onEditValue: () {}, // диалог больше не нужен
          onDuplicate: () => _duplicateInterval(index),
          onAddPhoto: () => _pickImageForInterval(interval.id),
          onRemovePhoto: () => _removeImageFromInterval(interval.id),
        );
      },
      onReorder: _onReorder,
      proxyDecorator: (Widget child, int index, Animation<double> animation) {
        return Material(
          elevation: 4.0,
          color: Colors.transparent,
          child: child,
        );
      },
    );
  }
}

class IntervalCard extends StatefulWidget {
  final Interval interval;
  final int index;
  final String Function(int) formatDuration;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDelete;
  final void Function(int index, List<IntervalKind> kinds) onInsert;
  final void Function(String newDescription) onDescriptionChanged;
  final VoidCallback onToggleMetric;
  final VoidCallback onEditValue;
  final VoidCallback onDuplicate;
  final VoidCallback onAddPhoto;
  final VoidCallback onRemovePhoto;
  const IntervalCard({
    super.key,
    required this.interval,
    required this.index,
    required this.formatDuration,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
    required this.onInsert,
    required this.onDescriptionChanged,
    required this.onToggleMetric,
    required this.onEditValue,
    required this.onDuplicate,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  @override
  State<IntervalCard> createState() => _IntervalCardState();
}

class _IntervalCardState extends State<IntervalCard> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _valueController; // для секунд/повторений
  bool _dragPressed =
      false; // визуальная подсветка при нажатии на ручку перетаскивания

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.interval.description,
    );
    _valueController = TextEditingController(
      text:
          (widget.interval.kind == IntervalKind.work &&
              widget.interval.isRepsBased)
          ? widget.interval.reps.toString()
          : widget.interval.durationSec.toString(),
    );

    // _descriptionController.addListener(() {
    //   widget.onDescriptionChanged(_descriptionController.text);
    // });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant IntervalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Синхронизируем поле, если значение поменяли +/- или переключили метрику
    final isReps =
        widget.interval.kind == IntervalKind.work &&
        widget.interval.isRepsBased;
    final newText = isReps
        ? widget.interval.reps.toString()
        : widget.interval.durationSec.toString();
    if (_valueController.text != newText) {
      _valueController.text = newText;
    }
  }

  Future<void> _showDescriptionDialog() async {
    final controller = TextEditingController(text: _descriptionController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Описание интервала'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: null,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Добавить описание',
              hintText: 'Например: Отжимания 15 раз',
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
                Navigator.of(context).pop(controller.text);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      _descriptionController.text = result;
      widget.onDescriptionChanged(result);
      setState(() {}); // обновим превью текста на карточке
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWorkInterval = widget.interval.kind == IntervalKind.work;
    final isReps = isWorkInterval && widget.interval.isRepsBased;
    final unitLabel = isReps ? 'повт.' : 'сек.';
    final Color? _baseColor = isWorkInterval
        ? colorScheme.surfaceContainerLow
        : null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      // Подсветка карты во время нажатия на drag-handle
      color: _dragPressed ? colorScheme.secondaryContainer : _baseColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReorderableDragStartListener(
                index: widget.index,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0),
                  child: Listener(
                    onPointerDown: (_) {
                      setState(() => _dragPressed = true);
                      HapticFeedback.selectionClick();
                    },
                    onPointerCancel: (_) =>
                        setState(() => _dragPressed = false),
                    onPointerUp: (_) => setState(() => _dragPressed = false),
                    child: Icon(Icons.drag_handle, color: theme.disabledColor),
                  ),
                ),
              ),

              // _getIntervalIcon(widget.interval.kind, colorScheme),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                      child: Text(
                        widget.interval.title ??
                            widget.interval.kind.name.capitalize(),
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: widget.onDecrement,
                          tooltip: 'Уменьшить',
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
                                hintText: '0',
                                contentPadding: EdgeInsets.zero,
                                // единица измерения внутри поля
                                suffixText: unitLabel,
                                suffixStyle: theme.textTheme.bodyLarge,
                              ),
                              style: theme.textTheme.bodyLarge,
                              // Обновляем модель по вводу (секунды/повторения как число)
                              onChanged: (txt) {
                                final v = int.tryParse(txt) ?? 0;
                                if (isReps) {
                                  widget.interval.reps = v.clamp(0, 1000);
                                } else {
                                  widget.interval.durationSec = v.clamp(
                                    0,
                                    86400,
                                  );
                                }
                                setState(() {}); // мгновенная отрисовка
                              },
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: widget.onIncrement,
                          tooltip: 'Увеличить',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isWorkInterval)
                IconButton(
                  icon: Icon(
                    widget.interval.isRepsBased
                        ? Icons.repeat
                        : Icons.timer_outlined,
                  ),
                  onPressed: widget.onToggleMetric,
                  tooltip:
                      'Сменить на ${widget.interval.isRepsBased ? "время" : "повторения"}',
                )
              else
                const SizedBox(width: 48),

              MenuAnchor(
                builder: (context, controller, child) {
                  return IconButton(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Действия',
                    onPressed: () {
                      HapticFeedback.selectionClick();
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
                        onPressed: () => widget.onInsert(widget.index, [
                          IntervalKind.prepare,
                        ]),
                        child: const Text('Подготовка'),
                      ),
                      MenuItemButton(
                        onPressed: () =>
                            widget.onInsert(widget.index, [IntervalKind.work]),
                        child: const Text('Работа'),
                      ),
                      MenuItemButton(
                        onPressed: () =>
                            widget.onInsert(widget.index, [IntervalKind.rest]),
                        child: const Text('Отдых'),
                      ),
                      MenuItemButton(
                        onPressed: () => widget.onInsert(widget.index, [
                          IntervalKind.work,
                          IntervalKind.rest,
                        ]),
                        child: const Text('Работа + Отдых'),
                      ),
                    ],
                    child: const Text('Вставить выше'),
                  ),
                  SubmenuButton(
                    menuChildren: [
                      MenuItemButton(
                        onPressed: () => widget.onInsert(widget.index + 1, [
                          IntervalKind.prepare,
                        ]),
                        child: const Text('Подготовка'),
                      ),
                      MenuItemButton(
                        onPressed: () => widget.onInsert(widget.index + 1, [
                          IntervalKind.work,
                        ]),
                        child: const Text('Работа'),
                      ),
                      MenuItemButton(
                        onPressed: () => widget.onInsert(widget.index + 1, [
                          IntervalKind.rest,
                        ]),
                        child: const Text('Отдых'),
                      ),
                      MenuItemButton(
                        onPressed: () => widget.onInsert(widget.index + 1, [
                          IntervalKind.work,
                          IntervalKind.rest,
                        ]),
                        child: const Text('Работа + Отдых'),
                      ),
                    ],
                    child: const Text('Вставить ниже'),
                  ),
                  MenuItemButton(
                    onPressed: widget.onDuplicate,
                    child: const Text('Копировать'),
                  ),
                  MenuItemButton(
                    onPressed: widget.onAddPhoto,
                    child: Text(
                      widget.interval.imageUri == null
                          ? 'Добавить фото'
                          : 'Изменить фото',
                    ),
                  ),
                  if (widget.interval.imageUri != null)
                    MenuItemButton(
                      onPressed: widget.onRemovePhoto,
                      child: const Text('Удалить фото'),
                    ),
                  const Divider(),
                  MenuItemButton(
                    onPressed: widget.onDelete,
                    child: Text(
                      'Удалить',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(80.0, 0, 16.0, 12.0),
            child: Semantics(
              button: true,
              label: 'Добавить или изменить описание интервала',
              onTapHint: 'Открыть диалог редактирования',
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showDescriptionDialog();
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    (_descriptionController.text.isEmpty)
                        ? 'Добавить описание'
                        : _descriptionController.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: (_descriptionController.text.isEmpty)
                          ? theme.hintColor
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.interval.imageUri != null &&
              widget.interval.imageUri!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(80.0, 0, 16.0, 12.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.file(
                  File(widget.interval.imageUri!),
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

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
