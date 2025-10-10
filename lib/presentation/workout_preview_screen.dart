import 'dart:io';
import 'package:flutter/material.dart' hide Interval;
import 'package:tick_coach/domain/models/interval.dart';
import 'package:tick_coach/domain/models/workout.dart';
import 'package:tick_coach/utils/database_helper.dart';

class WorkoutPreviewScreen extends StatefulWidget {
  final Workout workout;

  const WorkoutPreviewScreen({super.key, required this.workout});

  @override
  State<WorkoutPreviewScreen> createState() => _WorkoutPreviewScreenState();
}

class _WorkoutPreviewScreenState extends State<WorkoutPreviewScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Interval> _intervals = [];
  int _setCount = 1;

  @override
  void initState() {
    super.initState();
    _fetchWorkoutDetails();
  }

  Future<void> _fetchWorkoutDetails() async {
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

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.workout.title)),
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
    if (_intervals.isEmpty) {
      return const Center(child: Text('В этой тренировке нет упражнений.'));
    }

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          color: colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Обзор тренировки', style: textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Количество сетов:'),
                    Text(
                      '$_setCount',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Этапов в сете:'),
                    Text(
                      '${_intervals.length}',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Общее время:'),
                    Text(
                      widget.workout.totalTime.inSeconds > 0
                          ? _formatDuration(widget.workout.totalTime.inSeconds)
                          : 'На основе повторений',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Этапы', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        ..._intervals.map(
          (interval) => _IntervalPreviewCard(
            interval: interval,
            formatDuration: _formatDuration,
          ),
        ),
      ],
    );
  }
}

class _IntervalPreviewCard extends StatelessWidget {
  final Interval interval;
  final String Function(int) formatDuration;

  const _IntervalPreviewCard({
    required this.interval,
    required this.formatDuration,
  });

  IconData _getIconForKind(IntervalKind kind) {
    switch (kind) {
      case IntervalKind.prepare:
        return Icons.hourglass_top;
      case IntervalKind.work:
        return Icons.fitness_center;
      case IntervalKind.rest:
        return Icons.pause_circle_filled;
      case IntervalKind.between_sets:
        return Icons.repeat_one;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final isRepsBased = interval.isRepsBased;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForKind(interval.kind),
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    interval.title ?? 'Без названия',
                    style: textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isRepsBased
                      ? '${interval.reps} повт.'
                      : formatDuration(interval.durationSec),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (interval.description != null &&
                interval.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 36.0), // Align with title
                child: Text(interval.description!, style: textTheme.bodyMedium),
              ),
            ],
            if (interval.imageUri != null && interval.imageUri!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 36.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Image.file(
                    File(interval.imageUri!),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
