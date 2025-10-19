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
  TrainingSession? _previousSession;

  int _pendingBlocksCount = 0;
  final List<String> _collectedBlockNames = [];

  EditWorkoutNotifier(
    this._workoutRepository,
    this._voskService,
    TrainingSession initialSession,
  ) {
    _session = initialSession;
    _connectToVoskService();
    _context = _session;
  }

  TrainingSession get session => _session;
  VoskState get voskState => _voskService.state.value;

  // --- Chatbot State ---

  List<String> _conversationLog = [];
  List<String> get conversationLog => _conversationLog;

  Object? _context;
  Object? get context => _context;

  StreamSubscription<String>? _resultSubscription;

  final StreamController<void> _closeVoiceChatController =
      StreamController.broadcast();
  Stream<void> get closeVoiceChatStream => _closeVoiceChatController.stream;

  void _addBotMessage(String text) {
    _conversationLog.add("Bot: $text");
    notifyListeners();
  }

  void _connectToVoskService() {
    _voskService.state.addListener(_onVoskStateChanged);
    _resultSubscription = _voskService.recognitionResultStream.listen(
      _handleVoiceCommand,
    );
    // Сразу проверяем состояние, если сервис уже был инициализирован
    _onVoskStateChanged();
  }

  void _onVoskStateChanged() {
    notifyListeners();
  }

  String _generateId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';

  void _saveStateForUndo() {
    // Deep copy for undo
    _previousSession = _session.copyWith(
      blocks: _session.blocks
          .map(
            (block) => block.copyWith(
              sets: block.sets
                  .map(
                    (set) => set.copyWith(
                      items: set.items.map((item) => item.copyWith()).toList(),
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  void undo() {
    if (_previousSession != null) {
      _session = _previousSession!;
      _previousSession = null;
      // Reset context to the session level after undo
      _context = _session;
      _addBotMessage("Отменила последнее действие.");
      notifyListeners();
    } else {
      _addBotMessage("Нечего отменять.");
    }
  }

  @override
  void dispose() {
    _resultSubscription?.cancel();
    _closeVoiceChatController.close();
    _voskService.state.removeListener(_onVoskStateChanged);
    super.dispose();
  }

  void updateSessionName(String name) {
    if (name.isNotEmpty) {
      _saveStateForUndo();
      _session.name = name;
      notifyListeners();
    }
  }

  void clearConversationLog() {
    _conversationLog.clear();
    notifyListeners();
  }

  Future<void> toggleListening() async {
    final currentState = _voskService.state.value;
    if (currentState == VoskState.listening) {
      await _voskService.stopListening();
    } else if (currentState == VoskState.ready) {
      await _voskService.startListening();
      // New logic for contextual prompt
      if (_session.blocks.isEmpty || _context is TrainingSession) {
        _addBotMessage('Сколько блоков хотите добавить?');
      } else if (_context is Block) {
        _addBotMessage('Сколько сетов хотите добавить? Пример: "пять".');
      } else if (_context is Set) {
        _addBotMessage(
          'Назовите упражнение, которое хотите добавить? Пример: "отжимания 25 раз." или "бег на месте 30 секунд"',
        );
      }
    }
  }

  void _handleVoiceCommand(String command) async {
    debugPrint('VOICE COMMAND RECEIVED: "$command"');
    if (command.isEmpty) return;

    // Stop listening as soon as we receive a command to process it.
    await _voskService.stopListening();

    _conversationLog.add("You: $command");
    notifyListeners();

    final normalizedCommand = command.toLowerCase();

    if (normalizedCommand == 'отмена' || normalizedCommand == 'отменить') {
      undo();
      _pendingBlocksCount = 0;
      _collectedBlockNames.clear();
    } else if (_pendingBlocksCount > 0) {
      _handleBlockNameInput(command);
    } else if (_session.blocks.isEmpty || _context is TrainingSession) {
      _handleBlockCountInput(normalizedCommand);
    } else if (_context is Block) {
      _handleAddSets(normalizedCommand);
    } else if (_context is Set) {
      _handleAddExercise(normalizedCommand);
    } else {
      _addBotMessage("Я вас не поняла, повторите, пожалуйста.");
    }
  }

  void _handleBlockCountInput(String command) {
    final count = _parseNumberWord(command);
    if (count > 0) {
      _pendingBlocksCount = count;
      _collectedBlockNames.clear();
      _addBotMessage('Назовите название для блока 1.');
      _voskService.startListening();
    } else {
      _addBotMessage(
        "Я не поняла число. Пожалуйста, назовите количество блоков, например: 'три'",
      );
      _voskService.startListening();
    }
  }

  void _handleBlockNameInput(String command) {
    _collectedBlockNames.add(command.capitalize());

    if (_collectedBlockNames.length < _pendingBlocksCount) {
      _addBotMessage(
        'Отлично. Назовите название для блока ${_collectedBlockNames.length + 1}.',
      );
      _voskService.startListening();
    } else {
      _saveStateForUndo();
      final newBlocks = <Block>[];
      for (final name in _collectedBlockNames) {
        final newBlock = Block(
          id: _generateId(),
          type: 'Разминка',
          label: name,
          sets: [],
        );
        newBlocks.add(newBlock);
      }
      _session.blocks.addAll(newBlocks);
      _context = _session.blocks.last;
      _closeVoiceChatController.add(null);
      notifyListeners();

      // Reset state
      _pendingBlocksCount = 0;
      _collectedBlockNames.clear();
    }
  }

  void _handleAddSets(String command) {
    final count = _parseNumberWord(command.trim());
    if (count > 0 && _context is Block) {
      final block = _context as Block;
      _saveStateForUndo();
      final newSets = <Set>[];
      for (int i = 0; i < count; i++) {
        final newSet = Set(
          id: _generateId(),
          items: [],
          label: 'Сет ${block.sets.length + i + 1}',
        );
        newSets.add(newSet);
      }
      block.sets.addAll(newSets);
      _context = block.sets.last;
      _closeVoiceChatController.add(null);
      notifyListeners();
    } else {
      _addBotMessage(
        "Я вас не поняла, повторите, пожалуйста. Назовите количество сетов, например: 'пять'",
      );
      _voskService.startListening();
    }
  }

  void _handleAddExercise(String command) {
    if (_context is! Set) return;
    final currentSet = _context as Set;
    var exerciseName = command;

    int? reps;
    int? duration;
    double? weight;

    final repsRegex = RegExp(r'(\d+)\s*(раз|повторений|повторения)');
    final durationRegex = RegExp(r'(\d+)\s*(секунд|сек)');
    final weightRegex = RegExp(r'(\d+)\s*(килограмм|кг)');

    final repsMatch = repsRegex.firstMatch(command);
    if (repsMatch != null) {
      reps = int.tryParse(repsMatch.group(1)!);
      exerciseName = exerciseName.replaceAll(repsMatch.group(0)!, '').trim();
    }

    final durationMatch = durationRegex.firstMatch(command);
    if (durationMatch != null) {
      duration = int.tryParse(durationMatch.group(1)!);
      exerciseName = exerciseName
          .replaceAll(durationMatch.group(0)!, '')
          .trim();
    }

    final weightMatch = weightRegex.firstMatch(command);
    if (weightMatch != null) {
      weight = double.tryParse(weightMatch.group(1)!);
      exerciseName = exerciseName.replaceAll(weightMatch.group(0)!, '').trim();
    }

    exerciseName = exerciseName.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (exerciseName.isEmpty) {
      _addBotMessage(
        "Я вас не поняла, повторите, пожалуйста. Назовите упражнение.",
      );
      _voskService.startListening();
      return;
    }

    _saveStateForUndo();
    final newExercise = Exercise(
      id: _generateId(),
      name: exerciseName.capitalize(),
      reps: reps ?? 10,
      durationSec: duration ?? 30,
      isRepsBased: duration == null,
      loadKg: weight,
    );

    currentSet.items.add(newExercise);
    _closeVoiceChatController.add(null);
    notifyListeners();
  }

  int _parseNumberWord(String word) {
    final Map<String, int> numberWords = {
      'один': 1,
      'одна': 1,
      'два': 2,
      'две': 2,
      'три': 3,
      'четыре': 4,
      'пять': 5,
      'шесть': 6,
      'семь': 7,
      'восемь': 8,
      'девять': 9,
      'десять': 10,
    };
    return numberWords[word.toLowerCase()] ?? int.tryParse(word) ?? 0;
  }

  void updateBlockLabel(Block block, String label) {
    if (label.isNotEmpty) {
      block.label = label;
      notifyListeners();
    }
  }

  void addBlock([String? label]) {
    _saveStateForUndo();
    final newBlock = Block(
      id: _generateId(),
      type: 'Основная часть',
      label: label,
      sets: [],
    );
    _session.blocks.add(newBlock);
    _context = newBlock;
    notifyListeners();
  }

  void addSet(Block block, [String? label]) {
    _saveStateForUndo();
    final newSet = Set(id: _generateId(), items: [], label: label);
    block.sets.add(newSet);
    _context = newSet;
    notifyListeners();
  }

  void addExercise(Set set, [String name = 'Новое упражнение']) {
    _saveStateForUndo();
    set.items.add(Exercise(id: _generateId(), name: name));
    notifyListeners();
  }

  void addRest(Set set, [int duration = 60]) {
    _saveStateForUndo();
    set.items.add(Rest(id: _generateId(), durationSec: duration));
    notifyListeners();
  }

  void insertItem(Set targetSet, int index, SetItem item) {
    targetSet.items.insert(index, item);
    notifyListeners();
  }

  void duplicateBlock(int blockIndex) {
    _saveStateForUndo();
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
    _saveStateForUndo();
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
    _saveStateForUndo();
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
    _saveStateForUndo();
    _session.blocks.removeAt(blockIndex);
    notifyListeners();
  }

  void deleteSet(Block block, Set setToDelete) {
    _saveStateForUndo();
    block.sets.remove(setToDelete);
    notifyListeners();
  }

  void deleteItem(Set set, SetItem itemToDelete) {
    _saveStateForUndo();
    set.items.remove(itemToDelete);
    notifyListeners();
  }

  void updateSetRepeat(Set set, int newCount) {
    _saveStateForUndo();
    if (newCount > 0) {
      set.repeat = newCount;
      notifyListeners();
    }
  }

  void reorderBlock(int oldIndex, int newIndex) {
    _saveStateForUndo();
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _session.blocks.removeAt(oldIndex);
    _session.blocks.insert(newIndex, item);
    notifyListeners();
  }

  void reorderSetsInBlock(Block block, int oldIndex, int newIndex) {
    _saveStateForUndo();
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final set = block.sets.removeAt(oldIndex);
    block.sets.insert(newIndex, set);
    notifyListeners();
  }

  void reorderSetItem(Set set, int oldIndex, int newIndex) {
    _saveStateForUndo();
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
