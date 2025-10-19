import 'dart:async';

import 'dart:math';
import 'package:flutter/foundation.dart';

import 'package:image_picker/image_picker.dart';
import 'package:tick_coach/data/services/vosk_service.dart';
import 'package:tick_coach/domain/models/training_session.dart';
import 'package:tick_coach/domain/repositories/workout_repository.dart';

class EditWorkoutNotifier extends ChangeNotifier {
  final WorkoutRepository _workoutRepository;
  final VoskService _voskService;
  late TrainingSession _session;

  EditWorkoutNotifier(
    this._workoutRepository,
    this._voskService,
    TrainingSession initialSession,
  ) {
    _session = initialSession;
    _initializeVoskService();
  }

  TrainingSession get session => _session;
  VoskState get voskState => _voskService.state.value;

  StreamSubscription<String>? _resultSubscription;

  Future<void> _initializeVoskService() async {
    try {
      _voskService.state.addListener(_onVoskStateChanged);
      await _voskService.initialize(
        'assets/models/vosk-model-small-ru-0.22.zip',
      );
      _resultSubscription = _voskService.recognitionResultStream.listen(
        _handleVoiceCommand,
      );
    } catch (e) {
      debugPrint('Ошибка инициализации голосового ввода: ${e.toString()}');
    }
  }

  void _onVoskStateChanged() {
    notifyListeners();
  }

  String _generateId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';

  @override
  void dispose() {
    _resultSubscription?.cancel();
    _voskService.state.removeListener(_onVoskStateChanged);
    super.dispose();
  }

  void updateSessionName(String name) {
    if (name.isNotEmpty) {
      _session.name = name;
      notifyListeners();
    }
  }

  Future<void> toggleListening() async {
    final currentState = _voskService.state.value;
    if (currentState == VoskState.listening) {
      await _voskService.stopListening();
    } else if (currentState == VoskState.ready) {
      await _voskService.startListening();
    }
  }

  void _handleVoiceCommand(String command) {
    if (command.isEmpty) return;
    command = command.toLowerCase();
    command = command
        .replaceAll('повторений', 'раз')
        .replaceAll('повторов', 'раз')
        .replaceAll('килограмм', 'кг');

    if (command.contains('блок')) {
      String type = 'Основная часть';
      if (command.contains('разминка')) type = 'Разминка';
      if (command.contains('заминка')) type = 'Заминка';
      _session.blocks.add(Block(id: _generateId(), type: type, sets: []));
      notifyListeners();
      return;
    }

    if (command.contains('сет')) {
      var lastBlock = _session.blocks.lastOrNull;
      if (lastBlock == null) {
        lastBlock = Block(id: _generateId(), type: 'Основная часть', sets: []);
        _session.blocks.add(lastBlock);
      }
      int repeat = 1;
      final repeatMatch = RegExp(
        r'(\d+)\s+(?:раз|круга|круг)',
      ).firstMatch(command);
      if (repeatMatch != null) {
        repeat = int.tryParse(repeatMatch.group(1)!) ?? 1;
      }
      String? label;
      if (command.contains('суперсет')) label = 'Суперсет';
      if (command.contains('трисет')) label = 'Трисет';
      lastBlock.sets.add(
        Set(id: _generateId(), items: [], repeat: repeat, label: label),
      );
      notifyListeners();
      return;
    }

    if (command.startsWith('отдых')) {
      final durationMatch = RegExp(r'(\d+)\s+секунд').firstMatch(command);
      int duration = 60;
      if (durationMatch != null) {
        duration = int.tryParse(durationMatch.group(1)!) ?? 60;
      }
      _addItemToLastSet(Rest(id: _generateId(), durationSec: duration));
      return;
    }

    var processedCommand = command
        .replaceFirst('добавь', '')
        .replaceFirst('новое упражнение', '')
        .trim();
    if (processedCommand == 'упражнение') {
      _addItemToLastSet(Exercise(id: _generateId(), name: 'Новое упражнение'));
      return;
    }

    int? reps;
    final repsMatch = RegExp(r'(\d+)\s+раз').firstMatch(processedCommand);
    if (repsMatch != null) {
      reps = int.tryParse(repsMatch.group(1)!);
      processedCommand = processedCommand
          .replaceAll(repsMatch.group(0)!, '')
          .trim();
    }

    double? loadKg;
    final loadMatch = RegExp(
      r'(\d+(?:\.|\,)?\d*)\s+кг',
    ).firstMatch(processedCommand);
    if (loadMatch != null) {
      loadKg = double.tryParse(loadMatch.group(1)!.replaceAll(',', '.'));
      processedCommand = processedCommand
          .replaceAll(loadMatch.group(0)!, '')
          .trim();
    }

    final name = processedCommand.isNotEmpty
        ? processedCommand
        : 'Новое упражнение';
    _addItemToLastSet(
      Exercise(
        id: _generateId(),
        name: name.capitalize(),
        reps: reps ?? 10,
        loadKg: loadKg,
      ),
    );
  }

  void _addItemToLastSet(SetItem item) {
    var lastSet = _session.blocks.lastOrNull?.sets.lastOrNull;
    if (lastSet == null) {
      var lastBlock = _session.blocks.lastOrNull;
      if (lastBlock == null) {
        lastBlock = Block(id: _generateId(), type: 'Основная часть', sets: []);
        _session.blocks.add(lastBlock);
      }
      lastSet = Set(id: _generateId(), items: []);
      lastBlock.sets.add(lastSet);
    }
    lastSet.items.add(item);
    notifyListeners();
  }

  void updateBlockLabel(Block block, String label) {
    if (label.isNotEmpty) {
      block.label = label;
      notifyListeners();
    }
  }

  void addBlock() {
    _session.blocks.add(
      Block(id: _generateId(), type: 'Основная часть', sets: []),
    );
    notifyListeners();
  }

  void addSet(Block block) {
    block.sets.add(Set(id: _generateId(), items: []));
    notifyListeners();
  }

  void addExercise(Set set) {
    set.items.add(Exercise(id: _generateId(), name: 'Новое упражнение'));
    notifyListeners();
  }

  void addRest(Set set) {
    set.items.add(Rest(id: _generateId(), durationSec: 60));
    notifyListeners();
  }

  void insertItem(Set targetSet, int index, SetItem item) {
    targetSet.items.insert(index, item);
    notifyListeners();
  }

  void duplicateBlock(int blockIndex) {
    final originalBlock = _session.blocks[blockIndex];
    final newBlock = originalBlock.copyWith(
      id: _generateId(),
      sets: originalBlock.sets
          .map(
            (s) => s.copyWith(
              id: _generateId(),
              items: s.items.map((i) => i.copyWith(id: _generateId())).toList(),
            ),
          )
          .toList(),
    );
    _session.blocks.insert(blockIndex + 1, newBlock);
    notifyListeners();
  }

  void duplicateSet(Block block, Set originalSet) {
    final newSet = originalSet.copyWith(
      id: _generateId(),
      items: originalSet.items
          .map((i) => i.copyWith(id: _generateId()))
          .toList(),
    );
    final originalIndex = block.sets.indexOf(originalSet);
    block.sets.insert(originalIndex + 1, newSet);
    notifyListeners();
  }

  void duplicateItem(Set set, SetItem originalItem) {
    final newItem = originalItem.copyWith(id: _generateId());
    final originalIndex = set.items.indexOf(originalItem);
    set.items.insert(originalIndex + 1, newItem);
    notifyListeners();
  }

  Future<void> pickImage(Exercise exercise) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      exercise.imageUri = pickedFile.path;
      notifyListeners();
    }
  }

  void removeImage(Exercise exercise) {
    exercise.imageUri = null;
    notifyListeners();
  }

  void deleteBlock(int blockIndex) {
    _session.blocks.removeAt(blockIndex);
    notifyListeners();
  }

  void deleteSet(Block block, Set setToDelete) {
    block.sets.remove(setToDelete);
    notifyListeners();
  }

  void deleteItem(Set set, SetItem itemToDelete) {
    set.items.remove(itemToDelete);
    notifyListeners();
  }

  void updateSetRepeat(Set set, int newCount) {
    if (newCount > 0) {
      set.repeat = newCount;
      notifyListeners();
    }
  }

  void reorderBlock(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _session.blocks.removeAt(oldIndex);
    _session.blocks.insert(newIndex, item);
    notifyListeners();
  }

  void reorderSetItem(Set set, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = set.items.removeAt(oldIndex);
    set.items.insert(newIndex, item);
    notifyListeners();
  }

  Future<bool> saveWorkout() async {
    try {
      await _workoutRepository.saveTrainingSession(_session);
      return true;
    } catch (e) {
      return false;
    }
  }
}

extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
