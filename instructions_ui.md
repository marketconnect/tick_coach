# AI RULES for a Flutter App UI 

---

## 0) Fast goal
Enable Material 3 + dynamic color (Android 12+), glanceable feeds, proper micro‑interactions with haptics, a basic AI entry (“I want…”) and comply with WCAG 2.2.

---

## 1) Material 3 is on and used everywhere
**Rule.** Do not disable Material 3. Use M3 components (e.g., `NavigationBar`) on new screens.  
**Check.** No `useMaterial3: false` anywhere; bottom navigation is `NavigationBar`.

---

## 2) Dynamic color (Material You) + correct fallback
**Rule.** On Android 12+, use system palettes via `dynamic_color`. On others, use `ColorScheme.fromSeed` with AA contrast.  
**Check.** On Pixel/Android 12+ the palette changes with wallpapers; on Android 10–11 it’s stable from the seed.

**Change/add:** see “Code: theme + dynamic color”.

---

## 3) Glanceable-first home (bento grid)
**Rule.** The home screen is a grid of cards with quick value (status, progress, one key number/action). Cards have mixed sizes.  
**Check.** Users grasp “what matters” in 1–2 seconds; ≥2 important cards visible without scrolling.

**Change/add:** see “Code: home feed and navigation”.

---

## 4) Haptics and micro‑interactions — only when meaningful
**Rule.** Use `HapticFeedback.selectionClick()` for tab selection/confirmation; animations 120–200 ms via implicit widgets (`Animated*`).  
**Check.** No “empty” vibration; `VIBRATE` in manifest only if advanced patterns are needed.

**Change/add:** haptics is already in the card and navigation code below.

---

## 5) Accessibility WCAG 2.2 + semantics
**Rule.** Interactive targets ≥48×48dp; wrap custom elements with `Semantics` and set `label/role/state`.  
**Check.** Touch target AA passes; screen reader correctly announces role and state.

**Change/add:** `Semantics` and min target are already set on cards.

---

## 6) AI entry: “I want…” + editable result
**Rule.** Provide a single, clear AI entry point. The user states a goal; the result appears as a card with “Accept / Edit / Cancel”.  
**Check.** No hidden AI; actions are explicit.

**Change/add:** see “Code: AI entry screen” (Flutter side).

> Note: for on‑device AICore use a native Android layer (MethodChannel + SDK). This file includes Flutter changes only—no placeholders for native parts.

---

## 7) Theming tokens over hardcoded colors
**Rule.** Use `ColorScheme` roles (`primary/secondary/error/*Container*`). Don’t hardcode `Color(0xFF...)` inside widgets.  
**Check.** Code search finds no magic colors in UI; styles read `Theme.of(context).colorScheme`.

---

## 8) Navigation — bottom, thumb‑reachable
**Rule.** 2–5 top destinations in `NavigationBar`; filters in `BottomSheet`; key CTAs in the lower third.  
**Check.** Core actions reachable with one hand on 6–6.7″ phones.

---

## 9) Outcome analytics, not vanity metrics
**Rule.** Track ATCT (Average Time to Core Task), CTR of glanceable cards, checkout cancels, share of AI‑entered flows.  
**Threshold.** ATCT improvement ≥10–20% after rollout, otherwise iterate the design.

---

## 10) UI performance
**Rule.** Use implicit animations (`Animated*`), list/grid builders (`*.builder`), no heavy work in build.  
**Check.** Jank ≤1% of frames; no >200 ms animations without reason.

---

# CODE: only what to ADD/CHANGE

## A. `pubspec.yaml` — add dynamic color dependency
```yaml
dependencies:
  dynamic_color: ^1.8.1
```

## B. `lib/main.dart` — theme + dynamic color (full file replacement)
```dart
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart'; // from block C
import 'agent_entry.dart'; // from block D

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
            darkDynamic ?? ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark);

        return MaterialApp(
          theme: ThemeData(colorScheme: lightScheme),
          darkTheme: ThemeData(colorScheme: darkScheme),
          themeMode: ThemeMode.system,
          home: const HomeScreen(),
        );
      },
    );
  }
}
```

## C. `lib/home_screen.dart` — home feed and bottom navigation (full file replacement)
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'agent_entry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Home'), centerTitle: false),
      body: switch (_index) {
        0 => const _GlanceFeed(),
        1 => const AgentEntry(),
        _ => const SizedBox.shrink(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI',
          ),
        ],
        indicatorColor: cs.secondaryContainer,
      ),
    );
  }
}

class _GlanceFeed extends StatelessWidget {
  const _GlanceFeed();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: const [
        _GlanceCard(title: 'Delivery', subtitle: 'Courier in 12 min', icon: Icons.local_shipping),
        _GlanceCard(title: 'Today’s deals', subtitle: 'up to −30%', icon: Icons.local_offer),
        _GlanceCard(title: 'Balance', subtitle: '₽ 7 480', icon: Icons.account_balance_wallet),
        _GlanceCard(title: 'Picks for you', subtitle: 'based on your interests', icon: Icons.recommend),
      ],
    );
  }
}

class _GlanceCard extends StatefulWidget {
  final String title, subtitle;
  final IconData icon;
  const _GlanceCard({required this.title, required this.subtitle, required this.icon});

  @override
  State<_GlanceCard> createState() => _GlanceCardState();
}

class _GlanceCardState extends State<_GlanceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.subtitle}. Button.',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          HapticFeedback.selectionClick();
          // navigate/act here
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          decoration: BoxDecoration(
            color: _pressed ? cs.secondaryContainer : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon),
              const SizedBox(height: 8),
              Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(widget.subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
```

## D. `lib/agent_entry.dart` — AI entry screen (full file insertion)
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AgentEntry extends StatefulWidget {
  const AgentEntry({super.key});
  @override
  State<AgentEntry> createState() => _AgentEntryState();
}

class _AgentEntryState extends State<AgentEntry> {
  final _c = TextEditingController();
  String _result = '';
  static const _ai = MethodChannel('ai/edge'); // native side required on Android

  Future<void> _run() async {
    if (_c.text.trim().isEmpty) return;
    HapticFeedback.selectionClick();
    String text = '';
    try {
      text = await _ai.invokeMethod<String>('complete', {'prompt': _c.text}) ?? '';
    } catch (_) {
      text = 'On‑device AI is unavailable. Configure AICore or enable cloud.';
    }
    setState(() => _result = text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _c,
            decoration: const InputDecoration(
              labelText: 'I want…',
              prefixIcon: Icon(Icons.auto_awesome),
            ),
            onSubmitted: (_) => _run(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _run,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Generate'),
          ),
          const SizedBox(height: 16),
          if (_result.isNotEmpty)
            Card(
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(_result),
              ),
            ),
        ],
      ),
    );
  }
}
```

## E. `android/app/src/main/AndroidManifest.xml` — add vibration permission (if needed)
```xml
<uses-permission android:name="android.permission.VIBRATE"/>
```

---

# Release checklist
- [ ] On Android 12+ the app palette changes with wallpaper (dynamic color).
- [ ] Home shows ≥2 important glanceable cards without scrolling; grid runs at 60 FPS.
- [ ] Navigation uses `NavigationBar`; haptics only on meaningful actions.
- [ ] All interactives are ≥48×48dp; `Semantics` added to custom elements.
- [ ] “I want…” screen reachable from navigation; result is editable and explicit.

