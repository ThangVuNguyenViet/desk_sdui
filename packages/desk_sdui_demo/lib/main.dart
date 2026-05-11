import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_demo/desk_sdui_setup.g.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});
  @override
  State<DemoApp> createState() => _DemoAppState();
}

enum _Variant {
  minimal('counter_minimal', 'Minimal', 0),
  bouncy('counter_bouncy', 'Bouncy', 0),
  burst('counter_burst', 'Burst', 24),
  stress('counter_stress', 'Stress', 500);

  const _Variant(this.screenName, this.label, this.chipCount);
  final String screenName;
  final String label;
  final int chipCount;
}

class _DemoAppState extends State<DemoApp> {
  late final Runtime rt;
  int value = 0;
  _Variant variant = _Variant.bouncy;

  @override
  void initState() {
    super.initState();
    rt = Runtime();
    registerAllScreens(rt);
  }

  void _bump(int delta) => setState(() => value += delta);
  void _reset() => setState(() => value = 0);

  @override
  Widget build(BuildContext context) {
    final chips = List<int>.generate(variant.chipCount, (i) => i);
    return MaterialApp(
      title: 'desk_sdui — counter',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('desk_sdui — counter'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SegmentedButton<_Variant>(
                segments: [
                  for (final v in _Variant.values)
                    ButtonSegment(value: v, label: Text(v.label)),
                ],
                selected: {variant},
                onSelectionChanged: (s) => setState(() => variant = s.first),
              ),
            ),
          ),
        ),
        body: SduiScreen(
          runtime: rt,
          name: variant.screenName,
          inputs: {
            'data': {'value': value, 'chips': chips},
          },
        ),
        floatingActionButton: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'dec',
              onPressed: () => _bump(-1),
              child: const Icon(Icons.remove),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.extended(
              heroTag: 'reset',
              onPressed: _reset,
              label: const Text('Reset'),
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              heroTag: 'inc',
              onPressed: () => _bump(1),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
