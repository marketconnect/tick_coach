import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';
import 'package:tick_coach/conf.dart';
import 'package:tick_coach/data/datasources/database_helper.dart';

import 'package:tick_coach/data/repositories/chat_repository_impl.dart';
import 'package:tick_coach/data/repositories/workout_repository_impl.dart';
import 'package:tick_coach/data/services/vosk_service.dart';
import 'package:tick_coach/data/services/websocket_service.dart';
import 'package:tick_coach/domain/repositories/chat_repository.dart';
import 'package:tick_coach/domain/repositories/workout_repository.dart';
import 'package:flutter/material.dart';
import 'presentation/workouts_screen.dart';

void main() => runApp(const AppWrapper());

const _seed = Color(0xFF6750A4); // fixed seed, no placeholders

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseHelper>(create: (_) => DatabaseHelper.instance),
        Provider<WebSocketService>(
          create: (_) => WebSocketService(Conf.baseUrl),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<VoskService>(
          create: (_) {
            final service = VoskService.instance;
            service.initialize('assets/models/vosk-model-small-ru-0.22.zip');
            return service;
          },
          dispose: (_, service) => service.dispose(),
        ),
        ProxyProvider<DatabaseHelper, WorkoutRepository>(
          update: (_, dbHelper, __) => WorkoutRepositoryImpl(dbHelper),
        ),
        ProxyProvider2<WebSocketService, DatabaseHelper, ChatRepository>(
          update: (_, ws, db, __) => ChatRepositoryImpl(ws, db),
        ),
      ],
      child: const App(),
    );
  }
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme lightScheme =
            lightDynamic ?? ColorScheme.fromSeed(seedColor: _seed);
        final ColorScheme darkScheme =
            darkDynamic ??
            ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark);

        return MaterialApp(
          theme: ThemeData(colorScheme: lightScheme),
          darkTheme: ThemeData(colorScheme: darkScheme),
          themeMode: ThemeMode.system,
          home: const WorkoutsScreen(),
        );
      },
    );
  }
}
