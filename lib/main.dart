import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'presentation/workouts_screen.dart';

void main() => runApp(const App());

const _seed = Color(0xFF6750A4); // fixed seed, no placeholders

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
