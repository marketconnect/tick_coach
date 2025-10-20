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

  // --- Voice Exercise Creation State ---
  var _exerciseCreationStep = _ExerciseCreationStep.none;
  Exercise? _exerciseInProgress;
  int? _pendingRepsOrTimeValue;

  // --- Chatbot State ---

  List<String> _conversationLog = [];
  List<String> get conversationLog => _conversationLog;

  Object? _context;
  Object? get context => _context;

  String? _expandedBlockId;
  String? get expandedBlockId => _expandedBlockId;

  String? _expandedSetId;
  String? get expandedSetId => _expandedSetId;

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

  void setContext(Object? newContext) {
    if (_context != newContext) {
      _context = newContext;
      notifyListeners();
    }
  }

  void toggleBlockExpansion(String blockId) {
    if (_expandedBlockId == blockId) {
      _expandedBlockId = null;
      if (_context is Block && (_context as Block).id == blockId) {
        _context = _session;
      }
    } else {
      _expandedBlockId = blockId;
      _context = _session.blocks.firstWhere((b) => b.id == blockId);
    }
    _expandedSetId = null; // Collapse sets when a block is toggled
    notifyListeners();
  }

  void toggleSetExpansion(String setId, Block block) {
    if (_expandedSetId == setId) {
      _expandedSetId = null;
      if (_context is Set && (_context as Set).id == setId) {
        _context = block;
      }
    } else {
      _expandedSetId = setId;
      _context = block.sets.firstWhere((s) => s.id == setId);
    }
    notifyListeners();
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
        _addBotMessage('Назовите упражнение, которое хотите добавить?');
      }
    }
  }

  void _resetExerciseCreation() {
    _exerciseCreationStep = _ExerciseCreationStep.none;
    _exerciseInProgress = null;
    _pendingRepsOrTimeValue = null;
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
      if (_exerciseCreationStep != _ExerciseCreationStep.none) {
        _resetExerciseCreation();
        _addBotMessage("Добавление упражнения отменено.");
        return;
      }
      undo();
      _pendingBlocksCount = 0;
      _collectedBlockNames.clear();
    } else if (_exerciseCreationStep != _ExerciseCreationStep.none) {
      _handleExerciseCreationStep(command);
    } else if (_pendingBlocksCount > 0) {
      _handleBlockNameInput(command);
    } else if (_session.blocks.isEmpty || _context is TrainingSession) {
      _handleBlockCountInput(normalizedCommand);
    } else if (_context is Block) {
      _handleAddSets(normalizedCommand);
    } else if (_context is Set) {
      // This is the first step of creating an exercise: getting the name.
      _exerciseInProgress = Exercise(
        id: _generateId(),
        name: command.capitalize(),
      );
      _exerciseCreationStep = _ExerciseCreationStep.awaitingRepsOrTime;
      _addBotMessage('Отлично. Сколько повторений или секунд?');
      _voskService.startListening();
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

  void _finalizeExerciseCreation({int? restDuration}) {
    if (_context is! Set || _exerciseInProgress == null) {
      _resetExerciseCreation();
      return;
    }
    final currentSet = _context as Set;
    _saveStateForUndo();
    currentSet.items.add(_exerciseInProgress!);

    if (restDuration != null && restDuration > 0) {
      final newRest = Rest(id: _generateId(), durationSec: restDuration);
      currentSet.items.add(newRest);
    }

    var confirmation = 'Готово, добавила ${_exerciseInProgress!.name}';
    if (_exerciseInProgress!.isRepsBased) {
      confirmation += ', ${_exerciseInProgress!.reps} повторений';
    } else {
      confirmation += ', ${_exerciseInProgress!.durationSec} секунд';
    }
    if (_exerciseInProgress!.loadKg != null) {
      confirmation += ', вес ${_exerciseInProgress!.loadKg} кг';
    }
    if (_exerciseInProgress!.tempo != null &&
        _exerciseInProgress!.tempo!.isNotEmpty) {
      confirmation += ', темп ${_exerciseInProgress!.tempo}';
    }
    if (restDuration != null && restDuration > 0) {
      confirmation += ', и отдых $restDuration секунд';
    }
    confirmation += '.';
    _addBotMessage(confirmation);

    _resetExerciseCreation();
    _closeVoiceChatController.add(null);
    notifyListeners();
  }

  void _handleExerciseCreationStep(String command) {
    final normalizedCommand = command.toLowerCase();
    final skipWords = ['пропустить', 'дальше', 'не знаю', 'пропуск', 'нет'];

    if (skipWords.contains(normalizedCommand)) {
      switch (_exerciseCreationStep) {
        case _ExerciseCreationStep.awaitingRepsOrTime:
          _exerciseCreationStep = _ExerciseCreationStep.awaitingWeight;
          _addBotMessage('Какой вес?');
          _voskService.startListening();
          break;
        case _ExerciseCreationStep.awaitingWeight:
          _exerciseCreationStep = _ExerciseCreationStep.awaitingTempo;
          _addBotMessage('Какой темп?');
          _voskService.startListening();
          break;
        case _ExerciseCreationStep.awaitingTempo:
          _exerciseCreationStep = _ExerciseCreationStep.awaitingRest;
          _addBotMessage('Сколько секунд отдыха добавить?');
          _voskService.startListening();
          break;
        case _ExerciseCreationStep.awaitingRest:
          _finalizeExerciseCreation(); // Finalize without rest
          break;
        default:
          break;
      }
      return;
    }

    switch (_exerciseCreationStep) {
      case _ExerciseCreationStep.awaitingRepsOrTime:
        final repsWords = ['раз', 'повторений', 'повторения', 'повторов'];
        final secsWords = ['секунд', 'сек'];
        String numberPart = normalizedCommand;
        String? unit;

        for (final word in repsWords) {
          if (normalizedCommand.contains(word)) {
            unit = 'reps';
            numberPart =
                normalizedCommand.substring(0, normalizedCommand.indexOf(word)).trim();
            break;
          }
        }

        if (unit == null) {
          for (final word in secsWords) {
            if (normalizedCommand.contains(word)) {
              unit = 'secs';
              numberPart =
                  normalizedCommand.substring(0, normalizedCommand.indexOf(word)).trim();
              break;
            }
          }
        }

        final value = _parseNumberWord(numberPart);

        if (value > 0) {
          if (unit == 'reps') {
            _exerciseInProgress!.reps = value;
            _exerciseInProgress!.isRepsBased = true;
            _exerciseCreationStep = _ExerciseCreationStep.awaitingWeight;
            _addBotMessage('Какой вес?');
            _voskService.startListening();
          } else if (unit == 'secs') {
            _exerciseInProgress!.durationSec = value;
            _exerciseInProgress!.isRepsBased = false;
            _exerciseCreationStep = _ExerciseCreationStep.awaitingWeight;
            _addBotMessage('Какой вес?');
            _voskService.startListening();
          } else {
            // No unit found, but a number was.
            _pendingRepsOrTimeValue = value;
            _exerciseCreationStep =
                _ExerciseCreationStep.awaitingRepsOrTimeClarification;
            _addBotMessage('$value повторений или секунд?');
            _voskService.startListening();
          }
        } else {
          // No valid number found.
          _addBotMessage('Не поняла. Сколько повторений или секунд?');
          _voskService.startListening();
        }
        break;
      case _ExerciseCreationStep.awaitingRepsOrTimeClarification:
        if (normalizedCommand.contains('повторений') ||
            normalizedCommand.contains('раз')) {
          _exerciseInProgress!.reps = _pendingRepsOrTimeValue!;
          _exerciseInProgress!.isRepsBased = true;
          _pendingRepsOrTimeValue = null;
          _exerciseCreationStep = _ExerciseCreationStep.awaitingWeight;
          _addBotMessage('Какой вес?');
          _voskService.startListening();
        } else if (normalizedCommand.contains('секунд')) {
          _exerciseInProgress!.durationSec = _pendingRepsOrTimeValue!;
          _exerciseInProgress!.isRepsBased = false;
          _pendingRepsOrTimeValue = null;
          _exerciseCreationStep = _ExerciseCreationStep.awaitingWeight;
          _addBotMessage('Какой вес?');
          _voskService.startListening();
        } else {
          _addBotMessage('Пожалуйста, уточните: повторений или секунд?');
          _voskService.startListening();
        }
        break;
      case _ExerciseCreationStep.awaitingWeight:
        String numberPart = normalizedCommand;
        final weightUnits = ['килограмм', 'кг'];

        for (final unit in weightUnits) {
          if (normalizedCommand.contains(unit)) {
            numberPart =
                normalizedCommand.substring(0, normalizedCommand.indexOf(unit)).trim();
            break;
          }
        }

        // Try parsing as a double first (e.g., "12.5", "12,5")
        double? weightValue = double.tryParse(numberPart.replaceAll(',', '.'));

        // If that fails, try parsing as a word-number
        if (weightValue == null) {
          final intValue = _parseNumberWord(numberPart);
          if (intValue > 0) {
            weightValue = intValue.toDouble();
          }
        }

        if (weightValue != null) {
          _exerciseInProgress!.loadKg = weightValue;
        }

        _exerciseCreationStep = _ExerciseCreationStep.awaitingTempo;
        _addBotMessage('Какой темп?');
        _voskService.startListening();
        break;
      case _ExerciseCreationStep.awaitingTempo:
        final parsedTempo = _parseTempo(command);
        if (parsedTempo.isNotEmpty) {
          _exerciseInProgress!.tempo = parsedTempo;
        }
        _exerciseCreationStep = _ExerciseCreationStep.awaitingRest;
        _addBotMessage('Сколько секунд отдыха добавить?');
        _voskService.startListening();
        break;
      case _ExerciseCreationStep.awaitingRest:
        String numberPart = normalizedCommand;
        final secsWords = ['секунд', 'сек'];
        for (final word in secsWords) {
          if (normalizedCommand.contains(word)) {
            numberPart =
                normalizedCommand.substring(0, normalizedCommand.indexOf(word)).trim();
            break;
          }
        }
        final duration = _parseNumberWord(numberPart);
        _finalizeExerciseCreation(restDuration: duration > 0 ? duration : null);
        break;
      default:
        _resetExerciseCreation();
        break;
    }
  }

  String _parseTempo(String command) {
    final singleNumberWords = {
      'ноль': '0', 'один': '1', 'два': '2', 'три': '3', 'четыре': '4',
      'пять': '5', 'шесть': '6', 'семь': '7', 'восемь': '8', 'девять': '9',
    };

    final words = command.toLowerCase().replaceAll('-', ' ').split(' ').where((s) => s.isNotEmpty);
    final resultParts = <String>[];

    for (final word in words) {
      if (singleNumberWords.containsKey(word)) {
        resultParts.add(singleNumberWords[word]!);
      } else if (int.tryParse(word) != null && word.length == 1) {
        resultParts.add(word);
      }
    }

    return resultParts.join('-');
  }

  int _parseNumberWord(String word) {
    final numberWords = {
      'один': 1, 'одна': 1, 'два': 2, 'две': 2, 'три': 3, 'четыре': 4, 'пять': 5,
      'шесть': 6, 'семь': 7, 'восемь': 8, 'девять': 9, 'десять': 10,
      'одиннадцать': 11, 'двенадцать': 12, 'тринадцать': 13, 'четырнадцать': 14,
      'пятнадцать': 15, 'шестнадцать': 16, 'семнадцать': 17, 'восемнадцать': 18,
      'девятнадцать': 19, 'двадцать': 20, 'тридцать': 30, 'сорок': 40, 'пятьдесят': 50,
      'шестьдесят': 60, 'семьдесят': 70, 'восемьдесят': 80, 'девяносто': 90,
    };

    final trimmedText = word.trim().toLowerCase();

    // First, try to parse the whole string as a digit
    final digit = int.tryParse(trimmedText);
    if (digit != null) {
      return digit;
    }

    // If not a digit, parse as words
    final words = trimmedText.split(' ');
    int value = 0;

    for (final word in words) {
      final numVal = numberWords[word];
      if (numVal != null) {
        value += numVal;
      } else {
        // If a word is not a number, parsing fails for the whole phrase
        return 0;
      }
    }

    return value;
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
    _expandedBlockId = newBlock.id;
    _expandedSetId = null;
    notifyListeners();
  }

  void addSet(Block block, [String? label]) {
    _saveStateForUndo();
    final newSet = Set(id: _generateId(), items: [], label: label);
    block.sets.add(newSet);
    _context = newSet;
    _expandedBlockId = block.id;
    _expandedSetId = newSet.id;
    notifyListeners();
  }

  void addExercise(Set set, [String name = 'Новое упражнение']) {
    _saveStateForUndo();
    final newExercise = Exercise(id: _generateId(), name: name);
    set.items.add(newExercise);
    _context = newExercise;
    notifyListeners();
  }

  void addRest(Set set, [int duration = 60]) {
    _saveStateForUndo();
    final newRest = Rest(id: _generateId(), durationSec: duration);
    set.items.add(newRest);
    _context = newRest;
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

enum _ExerciseCreationStep {
  none,
  awaitingName,
  awaitingRepsOrTime,
  awaitingRepsOrTimeClarification,
  awaitingWeight,
  awaitingTempo,
  awaitingRest,
}

extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
