import 'dart:async';
import 'package:flutter/material.dart' hide Interval;
import 'package:audioplayers/audioplayers.dart';
import 'package:tick_coach/domain/models/interval.dart' show IntervalKind;
import 'package:tick_coach/domain/models/interval.dart' show Interval;
import '../utils/database_helper.dart';

import 'workouts_screen.dart'; // For Workout

class WorkoutTimerScreen extends StatefulWidget {
  final Workout workout;

  const WorkoutTimerScreen({super.key, required this.workout});

  @override
  State<WorkoutTimerScreen> createState() => _WorkoutTimerScreenState();
}

class _WorkoutTimerScreenState extends State<WorkoutTimerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Interval> _workoutPlan = [];
  int _totalSets = 1;
  int _currentIntervalIndex = 0;
  int _currentSet = 1;
  int _remainingTime = 0;
  Timer? _timer;
  bool _isPaused = true;
  final AudioPlayer _audioPlayer = AudioPlayer();

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
      final dbHelper = DatabaseHelper.instance;
      final intervals = await dbHelper.getIntervalsForWorkout(
        widget.workout.id,
      );
      final setCount = await dbHelper.getSetCountForWorkout(widget.workout.id);

      if (!mounted) return;

      if (intervals.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'В этой тренировке нет этапов.';
        });
        return;
      }

      setState(() {
        _workoutPlan = intervals;
        _totalSets = setCount;
        _remainingTime = _workoutPlan.first.durationSec;
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
    if (_timer != null && _timer!.isActive) return;
    if (_workoutPlan[_currentIntervalIndex].isRepsBased) {
      return;
    }
    setState(() {
      _isPaused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime == 5) {
        // 4 seconds before transition, check next interval
        Interval? nextInterval;
        if (_currentIntervalIndex < _workoutPlan.length - 1) {
          nextInterval = _workoutPlan[_currentIntervalIndex + 1];
        } else if (_currentSet < _totalSets) {
          // This is the last interval of a set, check first interval of next set
          nextInterval = _workoutPlan.first;
        }
        if (nextInterval != null &&
            (nextInterval.kind == IntervalKind.work ||
                nextInterval.kind == IntervalKind.rest)) {
          _audioPlayer.play(AssetSource('sounds/start.mp3'));
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
    if (_currentIntervalIndex < _workoutPlan.length - 1) {
      // Move to next interval in the current set
      setState(() {
        _currentIntervalIndex++;
        _remainingTime = _workoutPlan[_currentIntervalIndex].durationSec;
      });
    } else if (_currentSet < _totalSets) {
      // Move to the next set
      setState(() {
        _currentSet++;
        _currentIntervalIndex = 0;
        _remainingTime = _workoutPlan[0].durationSec;
      });
    } else {
      // Workout finished
      _timer?.cancel();
      _audioPlayer.play(AssetSource('sounds/finish.mp3'));
      setState(() {
        _isPaused = true;
      });
      _showCompletionDialog();
      return;
    }
    // If the new interval is reps-based, pause the timer.
    if (_workoutPlan[_currentIntervalIndex].isRepsBased) {
      _pauseTimer();
    } else {
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

  Color _getBackgroundColor(IntervalKind kind) {
    final colors = Theme.of(context).colorScheme;
    switch (kind) {
      case IntervalKind.prepare:
        return colors.tertiaryContainer;
      case IntervalKind.work:
        return colors.errorContainer;
      case IntervalKind.rest:
        // return colors.primaryContainer;
        return Theme.of(context).colorScheme.surfaceContainerHigh;

      case IntervalKind.between_sets:
        return colors.secondaryContainer;
      default:
        return Theme.of(context).scaffoldBackgroundColor;
    }
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

    final currentInterval = _workoutPlan[_currentIntervalIndex];
    final backgroundColor = _getBackgroundColor(currentInterval.kind);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.workout.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Сет: $_currentSet / $_totalSets',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                currentInterval.title ?? currentInterval.kind.name,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (currentInterval.description != null &&
                  currentInterval.description!.isNotEmpty)
                Text(
                  currentInterval.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              const Spacer(),
              if (currentInterval.isRepsBased)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${currentInterval.reps}',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 100,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('повторений'),
                    const SizedBox(height: 20),
                    IconButton(
                      icon: const Icon(Icons.forward_rounded),
                      iconSize: 60,
                      onPressed: _moveToNextInterval,
                    ),
                  ],
                )
              else
                Text(
                  _formatDuration(_remainingTime),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 100,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const Spacer(),
            ],
          ),
        ),
      ),
      floatingActionButton: currentInterval.isRepsBased
          ? null
          : FloatingActionButton.large(
              onPressed: _isPaused ? _startTimer : _pauseTimer,
              child: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
