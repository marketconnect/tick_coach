import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:tick_coach/application/create_rounds_notifier.dart';
import 'package:tick_coach/domain/models/training_session.dart';
import 'package:tick_coach/domain/repositories/workout_repository.dart';

class CreateRoundsScreen extends StatelessWidget {
  final TrainingSession? session;
  const CreateRoundsScreen({super.key, this.session});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CreateRoundsNotifier(
        context.read<WorkoutRepository>(),
        session,
      ),
      child: const _CreateRoundsScreenView(),
    );
  }
}

class _CreateRoundsScreenView extends StatefulWidget {
  const _CreateRoundsScreenView();

  @override
  State<_CreateRoundsScreenView> createState() =>
      _CreateRoundsScreenViewState();
}

class _CreateRoundsScreenViewState extends State<_CreateRoundsScreenView> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: context.read<CreateRoundsNotifier>().sessionName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveWorkout(CreateRoundsNotifier notifier) async {
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

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<CreateRoundsNotifier>();
    final config = notifier.config;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          notifier.isEditing ? 'Редактировать раунды' : 'Создать раунды',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Сохранить',
            onPressed: () => _saveWorkout(notifier),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Название тренировки',
              border: OutlineInputBorder(),
            ),
            onChanged: notifier.updateName,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          const _RoundsStepper(),
          const SizedBox(height: 16),
          _TimeInputRow(
            label: 'Время раунда',
            seconds: config.roundTimeSec,
            onChanged: notifier.updateRoundTime,
          ),
          const SizedBox(height: 16),
          _TimeInputRow(
            label: 'Время отдыха',
            seconds: config.restTimeSec,
            onChanged: notifier.updateRestTime,
          ),
          const SizedBox(height: 16),
          _TimeInputRow(
            label: 'Время для подготовки',
            seconds: config.prepareTimeSec,
            onChanged: notifier.updatePrepareTime,
          ),
          const SizedBox(height: 16),
          _TimeInputRow(
            label: 'Сигнал конца раунда (в сек)',
            seconds: config.endOfRoundSignalSec,
            onChanged: notifier.updateEndOfRoundSignal,
            isMinutes: false,
          ),
          const SizedBox(height: 16),
          _TimeInputRow(
            label: 'Период сигнала внутри раунда (в сек)',
            seconds: config.inRoundSignalPeriodSec,
            onChanged: notifier.updateInRoundSignalPeriod,
            isMinutes: false,
          ),
        ],
      ),
    );
  }

}

class _TimeInputRow extends StatefulWidget {
  final String label;
  final int seconds;
  final ValueChanged<int> onChanged;
  final bool isMinutes;

  const _TimeInputRow({
    required this.label,
    required this.seconds,
    required this.onChanged,
    this.isMinutes = true,
  });

  @override
  State<_TimeInputRow> createState() => _TimeInputRowState();
}

class _TimeInputRowState extends State<_TimeInputRow> {
  late final TextEditingController _minController;
  late final TextEditingController _secController;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController();
    _secController = TextEditingController();
    _updateControllers(widget.seconds);
  }

  @override
  void didUpdateWidget(covariant _TimeInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds) {
      _updateControllers(widget.seconds);
    }
  }

  void _updateControllers(int totalSeconds) {
    if (widget.isMinutes) {
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      _minController.text = minutes.toString();
      _secController.text = seconds.toString();
    } else {
      _secController.text = totalSeconds.toString();
    }
  }

  void _notifyChange() {
    if (widget.isMinutes) {
      final minutes = int.tryParse(_minController.text) ?? 0;
      final seconds = int.tryParse(_secController.text) ?? 0;
      widget.onChanged(minutes * 60 + seconds);
    } else {
      final seconds = int.tryParse(_secController.text) ?? 0;
      widget.onChanged(seconds);
    }
  }

  @override
  void dispose() {
    _minController.dispose();
    _secController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(widget.label,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        if (widget.isMinutes) ...[
          Expanded(
            flex: 1,
            child: TextField(
              controller: _minController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Мин',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _notifyChange(),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          flex: 1,
          child: TextField(
            controller: _secController,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Сек',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _notifyChange(),
          ),
        ),
      ],
    );
  }
}

class _RoundsStepper extends StatefulWidget {
  const _RoundsStepper();

  @override
  State<_RoundsStepper> createState() => _RoundsStepperState();
}

class _RoundsStepperState extends State<_RoundsStepper> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  late final CreateRoundsNotifier _notifier;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _notifier = context.read<CreateRoundsNotifier>();
    _controller = TextEditingController(
      text: _notifier.config.roundCount.toString(),
    );
    _notifier.addListener(_onNotifierUpdate);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _notifier.removeListener(_onNotifierUpdate);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _onNotifierUpdate() {
    final newText = _notifier.config.roundCount.toString();
    if (_controller.text != newText) {
      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _notifier.setRoundCount(_controller.text);
    }
  }

  void _startAcceleratedChange(void Function() action) {
    HapticFeedback.selectionClick();
    action(); // Fire once on long press start
    _timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      action();
      HapticFeedback.selectionClick();
    });
  }

  void _stopAcceleratedChange() {
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            'Количество раундов',
            style: theme.textTheme.titleMedium,
          ),
        ),
        GestureDetector(
          onLongPressStart: (_) =>
              _startAcceleratedChange(_notifier.decrementRounds),
          onLongPressEnd: (_) => _stopAcceleratedChange(),
          child: IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () {
              HapticFeedback.selectionClick();
              _notifier.decrementRounds();
            },
          ),
        ),
        SizedBox(
          width: 60,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
            ),
            onSubmitted: _notifier.setRoundCount,
          ),
        ),
        GestureDetector(
          onLongPressStart: (_) =>
              _startAcceleratedChange(_notifier.incrementRounds),
          onLongPressEnd: (_) => _stopAcceleratedChange(),
          child: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              HapticFeedback.selectionClick();
              _notifier.incrementRounds();
            },
          ),
        ),
      ],
    );
  }
}