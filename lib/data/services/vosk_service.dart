import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

// 1. Управление состоянием сервиса
enum VoskState { uninitialized, loading, ready, listening, error }

class VoskService {
  // 3. Жизненный цикл и область видимости сервиса (синглтон)
  VoskService._();
  static final VoskService instance = VoskService._();

  VoskFlutterPlugin? _vosk;
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  // 1. Управление состоянием сервиса
  final ValueNotifier<VoskState> state = ValueNotifier<VoskState>(
    VoskState.uninitialized,
  );

  // 2. Формат возвращаемых данных
  final _resultController = StreamController<String>.broadcast();
  Stream<String> get recognitionResultStream => _resultController.stream;

  StreamSubscription<String>? _resultSubscription;
  Completer<void>? _initCompleter;

  // 4. Обработка ошибок инициализации & 5. Зависимости и конфигурация
  Future<void> initialize(String modelAssetPath) {
    if (_initCompleter == null) {
      _initCompleter = Completer<void>();
      _initialize(modelAssetPath);
    }
    return _initCompleter!.future;
  }

  Future<void> _initialize(String modelAssetPath) async {
    try {
      state.value = VoskState.loading;
      _vosk = VoskFlutterPlugin.instance();

      final modelPath = await _loadModelFromAssets(modelAssetPath);
      _model = await _vosk!.createModel(modelPath);
      _recognizer = await _vosk!.createRecognizer(
        model: _model!,
        sampleRate: 16000,
      );

      _speechService = await _vosk!.initSpeechService(_recognizer!);

      _resultSubscription = _speechService!.onResult().listen((result) {
        try {
          final jsonResult = jsonDecode(result);
          final text = jsonResult['text'] as String?;
          if (text != null) {
            if (text.isNotEmpty) {
              _resultController.add(text);
            }
          }
        } catch (e) {
          // Ignore parsing errors for partial results
        }
      });

      state.value = VoskState.ready;
      _initCompleter!.complete();
    } catch (e) {
      if (e is PlatformException &&
          e.message!.contains('SpeechService instance already exist')) {
        debugPrint(
          'VoskService: Instance already exists (hot restart). Setting state to error.',
        );
        state.value = VoskState.ready;
        _initCompleter!.complete();
      } else {
        state.value = VoskState.error;
        _initCompleter!.completeError(e, StackTrace.current);
      }
    }
  }

  Future<void> startListening() async {
    if (state.value != VoskState.ready || _speechService == null) return;
    try {
      await _speechService!.start();
      state.value = VoskState.listening;
    } catch (e) {
      state.value = VoskState.error;
    }
  }

  Future<void> stopListening() async {
    if (state.value != VoskState.listening || _speechService == null) return;
    try {
      await _speechService!.stop();
      state.value = VoskState.ready;
    } catch (e) {
      state.value = VoskState.error;
    }
  }

  Future<String> _loadModelFromAssets(String assetPath) async {
    final tempDir = await getTemporaryDirectory();
    final modelName = assetPath.split('/').last.replaceAll('.zip', '');
    final modelDir = Directory('${tempDir.path}/$modelName');

    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
      final assetData = await rootBundle.load(assetPath);
      final bytes = assetData.buffer.asUint8List();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = '${modelDir.path}/${file.name}';
        if (file.isFile) {
          final outFile = File(filename);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filename).create(recursive: true);
        }
      }
    }
    return '${modelDir.path}/$modelName';
  }

  void dispose() {
    _resultSubscription?.cancel();
    _speechService?.stop();
    _resultController.close();
    state.dispose();
  }
}
