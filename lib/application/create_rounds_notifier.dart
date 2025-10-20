import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tick_coach/domain/models/rounds_config.dart';
import 'package:tick_coach/domain/models/training_session.dart';
import 'package:tick_coach/domain/repositories/workout_repository.dart';

class CreateRoundsNotifier extends ChangeNotifier {
  final WorkoutRepository _workoutRepository;
  TrainingSession? _originalSession;

  late String _sessionName;
  String get sessionName => _sessionName;

  late RoundsConfig _config;
  RoundsConfig get config => _config;

  bool get isEditing => _originalSession != null;

  CreateRoundsNotifier(this._workoutRepository, TrainingSession? session) {
    _originalSession = session;
    if (session != null) {
      _sessionName = session.name;
      _config = RoundsConfig.fromJsonString(session.roundsConfigJson ?? '');
    } else {
      _sessionName = 'Тренировка Раунды';
      _config = RoundsConfig();
    }
  }

  void updateName(String newName) {
    _sessionName = newName;
    notifyListeners();
  }

  void updateRoundCount(double value) {
    _config.roundCount = value.toInt();
    notifyListeners();
  }

  void updateRoundTime(int seconds) {
    _config.roundTimeSec = seconds;
    notifyListeners();
  }

  void updateRestTime(int seconds) {
    _config.restTimeSec = seconds;
    notifyListeners();
  }

  void updatePrepareTime(int seconds) {
    _config.prepareTimeSec = seconds;
    notifyListeners();
  }

  void updateEndOfRoundSignal(int seconds) {
    _config.endOfRoundSignalSec = seconds;
    notifyListeners();
  }

  void updateInRoundSignalPeriod(int seconds) {
    _config.inRoundSignalPeriodSec = seconds;
    notifyListeners();
  }

  String _generateId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';

  Future<bool> saveWorkout() async {
    final session = _originalSession?.copyWith() ??
        TrainingSession(id: _generateId(), name: _sessionName);

    session.name = _sessionName;
    session.workoutType = 'rounds';
    session.roundsConfigJson = jsonEncode(_config.toJson());
    session.blocks = _generateBlocks();

    try {
      await _workoutRepository.saveTrainingSession(session);
      return true;
    } catch (e) {
      debugPrint('Error saving rounds workout: $e');
      return false;
    }
  }

  List<Block> _generateBlocks() {
    final blocks = <Block>[];

    // 1. Preparation Block
    if (_config.prepareTimeSec > 0) {
      final prepBlock = Block(
        id: _generateId(),
        type: 'Подготовка',
        label: 'Подготовка',
        sets: [
          Set(
            id: _generateId(),
            items: [
              Rest(id: _generateId(), durationSec: _config.prepareTimeSec),
            ],
          ),
        ],
      );
      blocks.add(prepBlock);
    }

    // 2. Main Rounds Block
    final roundsItems = <SetItem>[];
    for (int i = 0; i < _config.roundCount; i++) {
      final roundNumber = i + 1;
      // Round work
      roundsItems.add(Exercise(
        id: _generateId(),
        name: 'Раунд $roundNumber/${_config.roundCount}',
        isRepsBased: false,
        durationSec: _config.roundTimeSec,
      ));

      // Round rest (except for the last one)
      if (_config.restTimeSec > 0 && roundNumber < _config.roundCount) {
        roundsItems.add(Rest(
          id: _generateId(),
          durationSec: _config.restTimeSec,
        ));
      }
    }

    final mainBlock = Block(id: _generateId(), type: 'Основная часть', label: 'Раунды', sets: [Set(id: _generateId(), items: roundsItems, repeat: 1, label: 'Все раунды')]);
    blocks.add(mainBlock);

    return blocks;
  }
}