import 'dart:io' show ProcessInfo;

import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_demo/desk_sdui_setup.g.dart';

import 'package:desk_sdui_demo/screens/product_demo_v1.dart';
import 'package:desk_sdui_demo/screens/product_demo_v2.dart';
import 'package:fdb_helper/fdb_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/dart.dart';



void main() {
  if (!kReleaseMode) {
    FdbBinding.ensureInitialized();
  }
  runApp(const DemoApp());
}

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});
  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  late final Runtime rt;
  late final List<Product> _products;
  late final ProductViewModel _vm;
  
  bool _darkMode = true;
  String _currentVariant = 'product_demo_v1';
  bool _showJson = false;
  IrTree? _currentIr;

  final _codeController = CodeController(
    language: dart,
  );

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

    _products = [
      Product(id: '1', title: 'Wireless Headphones', price: 99.99, description: 'Noise cancelling overhead headphones'),
      Product(id: '2', title: 'Mechanical Keyboard', price: 149.00, description: 'RGB backlit tactile switches'),
      Product(id: '3', title: 'Gaming Mouse', price: 59.99, description: 'High precision optical sensor'),
    ];

    _vm = ProductViewModel(_products);
    _vm.addListener(() {
      setState(() {});
    });
    
    _loadCodeSnippet();
    _loadIr();
  }
  
  Future<void> _loadIr() async {
    final path = 'lib/screens/$_currentVariant.sdui.json';
    final data = await rootBundle.load(path);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    setState(() {
      _currentIr = rt.parseIr(bytes);
    });
  }
  
  Future<void> _loadCodeSnippet() async {
    String path = _showJson ? 'lib/screens/$_currentVariant.sdui.g.dart' : 'lib/screens/$_currentVariant.dart';
    try {
      final code = await rootBundle.loadString(path);
      setState(() {
        _codeController.text = code;
      });
    } catch (e) {
      setState(() {
        _codeController.text = '// Error loading $path\n$e';
      });
    }
  }

  void _toggleTheme() => setState(() => _darkMode = !_darkMode);
  
  void _toggleVariant() {
    setState(() {
      _currentVariant = _currentVariant == 'product_demo_v1' ? 'product_demo_v2' : 'product_demo_v1';
      _currentIr = null; // show loading
    });
    _loadCodeSnippet();
    _loadIr();
  }
  
  void _toggleCodeView() {
    setState(() {
      _showJson = !_showJson;
    });
    _loadCodeSnippet();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'desk_sdui — SDUI Demo',
      theme: ThemeData(
        useMaterial3: true,
        brightness: _darkMode ? Brightness.dark : Brightness.light,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('SDUI Split Screen Demo'),
          actions: [
            TextButton(
              onPressed: _toggleVariant,
              child: Text('Variant: $_currentVariant', style: TextStyle(color: _darkMode ? Colors.white : Colors.black)),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: _toggleCodeView,
              child: Text('Code: ${_showJson ? "SDUI IR" : "Dart"}', style: TextStyle(color: _darkMode ? Colors.white : Colors.black)),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: Icon(_darkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: _toggleTheme,
            ),
          ],
        ),
        body: Row(
          children: [
            // Left Pane - UI Simulator
            Expanded(
              flex: 4,
              child: Center(
                child: Container(
                  width: 375, // iPhone approx width
                  height: 812, // iPhone approx height
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, width: 8),
                    borderRadius: BorderRadius.circular(40),
                    color: _darkMode ? Colors.black : Colors.white,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _currentIr == null
                      ? const Center(child: CircularProgressIndicator())
                      : ProductViewModelProvider(
                          vm: _vm,
                          child: SduiScreen(
                            key: ValueKey(_currentVariant),
                            runtime: rt,
                            ir: _currentIr!,
                          ),
                        ),
                ),
              ),
            ),
            // Right Pane - Code Viewer
            Expanded(
              flex: 6,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.grey.shade800, width: 2)),
                  color: const Color(0xFF23241f), // Match monokai background roughly
                ),
                child: CodeTheme(
                  data: CodeThemeData(styles: monokaiSublimeTheme),
                  child: SingleChildScrollView(
                    child: CodeField(
                      controller: _codeController,
                      textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
