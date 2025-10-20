import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tick_coach/domain/models/training_session.dart';
import 'package:tick_coach/presentation/workout_preview_screen.dart';
import 'package:tick_coach/domain/repositories/workout_repository.dart';
import 'package:tick_coach/domain/models/rounds_config.dart';

class TimerStep {
  final SetItem item;
  final int currentSet;
  final int totalSets;
  final int currentExerciseInSet;
  final int totalExercisesInSet;

  TimerStep(
    this.item,
    this.currentSet,
    this.totalSets,
    this.currentExerciseInSet,
    this.totalExercisesInSet,
  );
}

class WorkoutTimerScreen extends StatefulWidget {
  final TrainingSession session;
  const WorkoutTimerScreen({super.key, required this.session});

  @override
  State<WorkoutTimerScreen> createState() => _WorkoutTimerScreenState();
}

class _WorkoutTimerScreenState extends State<WorkoutTimerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  final List<TimerStep> _workoutPlan = [];
  int _currentIntervalIndex = 0;

  int _remainingTime = 0;
  Timer? _timer;
  bool _isPaused = true;

  final AudioPlayer _audioPlayer = AudioPlayer();
  // State for rounds-specific logic
  bool _isRoundsWorkout = false;
  RoundsConfig? _roundsConfig;
  bool _isFirstPlay = true;

  @override
  void initState() {
    super.initState();
    _loadWorkoutData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadWorkoutData() async {
    try {
      final repo = Provider.of<WorkoutRepository>(context, listen: false);
      final session = await repo.getTrainingSession(widget.session.id);

      if (!mounted) return;
      if (session == null || session.blocks.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'В этой тренировке нет этапов.';
        });
        return;
      }
      if (session.workoutType == 'rounds' && session.roundsConfigJson != null) {
        setState(() {
          _isRoundsWorkout = true;
          _roundsConfig = RoundsConfig.fromJsonString(
            session.roundsConfigJson!,
          );
        });
      }
      // Flatten the workout structure into a linear list of steps
      for (final block in session.blocks) {
        for (final set in block.sets) {
          final totalExercisesInSetAcrossRounds =
              set.items.whereType<Exercise>().length * set.repeat;
          int exerciseCounterForThisSet = 0;
          for (int i = 0; i < set.repeat; i++) {
            for (final item in set.items) {
              if (item is Exercise) {
                exerciseCounterForThisSet++;
              }
              _workoutPlan.add(
                TimerStep(
                  item,
                  i + 1,
                  set.repeat,
                  exerciseCounterForThisSet,
                  totalExercisesInSetAcrossRounds,
                ),
              );
            }
          }
        }
      }
      setState(() {
        final firstStep = _workoutPlan.first.item;
        if (firstStep is Rest) {
          _remainingTime = firstStep.durationSec;
        } else if (firstStep is Exercise && !firstStep.isRepsBased) {
          _remainingTime = firstStep.durationSec;
        } else {
          _remainingTime = 0;
        }
        _isLoading = false;
        // Start paused, waiting for user to press play
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка загрузки тренировки: $e';
      });
    }
  }

  void _startTimer() {
    final currentItem = _workoutPlan[_currentIntervalIndex].item;
    if (currentItem is Exercise && currentItem.isRepsBased) {
      // Do not start timer for rep-based exercises
      return;
    }

    if (_isFirstPlay) {
      _isFirstPlay = false;
      // Play bell on first round start
      if (_isRoundsWorkout && currentItem is Exercise) {
        _audioPlayer.play(AssetSource('sounds/bell-in-the-boxing-ring.mp3'));
      }
    }

    setState(() {
      _isPaused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Standard workout countdown sound
      if (!_isRoundsWorkout && _remainingTime == 5) {
        _audioPlayer.play(AssetSource('sounds/start.mp3'));
      }

      // Rounds workout specific sounds

      if (_isRoundsWorkout &&
          currentItem is Exercise &&
          _roundsConfig != null) {
        // End of round warning (highest priority)
        if (_roundsConfig!.endOfRoundSignalSec > 0 &&
            _remainingTime == _roundsConfig!.endOfRoundSignalSec + 1) {
          _audioPlayer.play(AssetSource('sounds/door-knock-solid-door.mp3'));
        }
        // In-round periodic signal (lower priority)
        else if (_roundsConfig!.inRoundSignalPeriodSec > 0 &&
            _remainingTime > 0 &&
            _remainingTime < currentItem.durationSec &&
            _remainingTime % _roundsConfig!.inRoundSignalPeriodSec == 0) {
          _audioPlayer.play(
            AssetSource('sounds/short-ringing-notification-sound.mp3'),
          );
        }
      }

      if (_remainingTime > 1) {
        setState(() {
          _remainingTime--;
        });
      } else {
        _moveToNextInterval();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isPaused = true;
    });
  }

  void _moveToNextInterval() {
    _timer
        ?.cancel(); // Ensure the old timer is stopped before starting a new one.
    HapticFeedback.selectionClick();
    final finishedItem = _workoutPlan[_currentIntervalIndex].item;
    final isLastItem = _currentIntervalIndex >= _workoutPlan.length - 1;
    if (_isRoundsWorkout) {
      final nextItem = isLastItem
          ? null
          : _workoutPlan[_currentIntervalIndex + 1].item;
      // Play bell on transitions to/from a round
      if (finishedItem is Exercise ||
          (finishedItem is Rest && nextItem is Exercise)) {
        _audioPlayer.play(AssetSource('sounds/bell-in-the-boxing-ring.mp3'));
      }
    }
    if (!isLastItem) {
      setState(() {
        _currentIntervalIndex++;
        final currentItem = _workoutPlan[_currentIntervalIndex].item;
        if (currentItem is Rest) {
          _remainingTime = currentItem.durationSec;
        } else if (currentItem is Exercise && !currentItem.isRepsBased) {
          _remainingTime = currentItem.durationSec;
        } else {
          _remainingTime = 0;
        }
      });
    } else {
      if (!_isRoundsWorkout) {
        // For rounds, bell already played for last round end
        _audioPlayer.play(AssetSource('sounds/finish.mp3'));
      }
      setState(() {
        _isPaused = true;
      });
      _showCompletionDialog();
      return;
    }
    final currentItem = _workoutPlan[_currentIntervalIndex].item;
    if (currentItem is Exercise && currentItem.isRepsBased) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _moveToPreviousInterval() {
    HapticFeedback.selectionClick();
    final wasPaused = _isPaused;
    _pauseTimer();

    setState(() {
      if (_currentIntervalIndex > 0) {
        _currentIntervalIndex--;
      } else {
        if (!wasPaused) _startTimer(); // Resume if it was playing
        return;
      }

      final currentItem = _workoutPlan[_currentIntervalIndex].item;
      if (currentItem is Rest) {
        _remainingTime = currentItem.durationSec;
      } else if (currentItem is Exercise && !currentItem.isRepsBased) {
        _remainingTime = currentItem.durationSec;
      } else {
        _remainingTime = 0;
      }
    });

    final currentItem = _workoutPlan[_currentIntervalIndex].item;
    if (!wasPaused &&
        (currentItem is Rest ||
            (currentItem is Exercise && !currentItem.isRepsBased))) {
      _startTimer();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Тренировка завершена!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to workouts screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(SetItem item) {
    final colors = Theme.of(context).colorScheme;
    if (item is Exercise) {
      return colors.errorContainer;
    }
    if (item is Rest) {
      return Theme.of(context).colorScheme.surfaceContainerHigh;
    }
    return Theme.of(context).scaffoldBackgroundColor;
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_errorMessage!)),
      );
    }

    final currentStep = _workoutPlan[_currentIntervalIndex];
    final currentItem = currentStep.item;
    final backgroundColor = _getBackgroundColor(currentItem);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.session.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Обзор тренировки',
            onPressed: () {
              String? highlightedId;
              final currentItem = _workoutPlan[_currentIntervalIndex].item;

              if (currentItem is Exercise) {
                highlightedId = currentItem.id;
              } else if (currentItem is Rest) {
                for (
                  int i = _currentIntervalIndex + 1;
                  i < _workoutPlan.length;
                  i++
                ) {
                  final nextItem = _workoutPlan[i].item;
                  if (nextItem is Exercise) {
                    highlightedId = nextItem.id;
                    break;
                  }
                }
              }

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => WorkoutPreviewScreen(
                    session: widget.session,
                    highlightedItemId: highlightedId,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
                minWidth: constraints.maxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back arrow
                        if (_currentIntervalIndex > 0)
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new),
                            onPressed: _moveToPreviousInterval,
                          )
                        else
                          const SizedBox(width: 48), // Keep space consistent
                        // Text
                        if (currentItem is Exercise)
                          Semantics(
                            label:
                                'Упражнение ${currentStep.currentExerciseInSet} из ${currentStep.totalExercisesInSet}',
                            child: Text(
                              '${currentStep.currentExerciseInSet} / ${currentStep.totalExercisesInSet}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),

                        // Forward arrow
                        if (_currentIntervalIndex < _workoutPlan.length - 1)
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _moveToNextInterval();
                            },
                          )
                        else
                          const SizedBox(width: 48), // Keep space consistent
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (currentItem is Exercise)
                      Text(
                        currentItem.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                    if (currentItem is Rest)
                      Text(
                        currentItem.reason ?? 'Отдых',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 8),

                    if (currentItem is Exercise && currentItem.isRepsBased)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${currentItem.reps}',
                              style: Theme.of(context).textTheme.displayLarge
                                  ?.copyWith(
                                    fontSize: 100,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          const Text('повторений'),
                        ],
                      )
                    else // Timed exercise or Rest
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatDuration(_remainingTime),
                              style: Theme.of(context).textTheme.displayLarge
                                  ?.copyWith(
                                    fontSize: 100,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 16),

                    // Add padding at the bottom so the FAB doesn't overlap content
                    if (currentItem is Rest ||
                        (currentItem is Exercise && !currentItem.isRepsBased))
                      const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          );
        },
      ),

      floatingActionButton: (currentItem is Exercise && currentItem.isRepsBased)
          ? null
          : FloatingActionButton.large(
              onPressed: () {
                HapticFeedback.selectionClick();
                _isPaused ? _startTimer() : _pauseTimer();
              },
              child: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
