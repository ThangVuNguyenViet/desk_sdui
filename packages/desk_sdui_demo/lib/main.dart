import 'dart:io' show ProcessInfo;

import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_demo/desk_sdui_setup.g.dart';
import 'package:desk_sdui_demo/screens/counter_demo.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});
  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  late final Runtime rt;
  late final Counter _counter;
  late final CounterActions _actions;
  bool _darkMode = true;

  @override
  void initState() {
    super.initState();
    rt = Runtime();

    final rssBefore = ProcessInfo.currentRss;
    final sw = Stopwatch()..start();
    registerAllScreens(rt);
    sw.stop();
    final rssAfter = ProcessInfo.currentRss;
    debugPrint('[sdui-probe] registerAllScreens: '
        '${sw.elapsedMicroseconds} µs, '
        'RSS delta ${(rssAfter - rssBefore) ~/ 1024} KB '
        '(before ${rssBefore ~/ 1024} KB, after ${rssAfter ~/ 1024} KB)');

    _counter = Counter();
    _actions = CounterActions();
  }

  void _toggleTheme() => setState(() => _darkMode = !_darkMode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'desk_sdui — counter',
      theme: ThemeData(
        useMaterial3: true,
        brightness: _darkMode ? Brightness.dark : Brightness.light,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('desk_sdui — counter'),
          actions: [
            IconButton(
              icon: Icon(_darkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: _toggleTheme,
            ),
          ],
        ),
        body: SduiScreen(
          runtime: rt,
          name: 'counter_demo',
          inputs: {'c': _counter, 'a': _actions},
        ),
      ),
    );
  }
}
