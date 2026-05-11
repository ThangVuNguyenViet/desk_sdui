import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/desk_sdui.dart';

void main() {
  testWidgets('SduiScreen mounts and resolves a registered screen',
      (tester) async {
    final rt = Runtime();
    rt.registerWidget('Text', (args) => Text(args['data']! as String));
    rt.registerScreen(
      const ScreenBinding(
        name: 'hello',
        ir: IrTree(
          name: 'hello',
          version: 1,
          root: WidgetNode(
            name: 'Text',
            args: const {'data': LiteralNode('hello world')},
          ),
        ),
        inputs: [],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: SduiScreen(name: 'hello', runtime: rt)),
    );
    await tester.pumpAndSettle();
    expect(find.text('hello world'), findsOneWidget);
  });

  testWidgets('SduiScreen shows error when screen not found',
      (tester) async {
    final rt = Runtime();
    await tester.pumpWidget(
      MaterialApp(home: SduiScreen(name: 'missing', runtime: rt)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ErrorWidget), findsOneWidget);
  });

  testWidgets('SduiScreen passes inputs to resolved tree', (tester) async {
    final rt = Runtime();
    rt.registerWidget('Text', (args) => Text(args['data']! as String));
    rt.registerScreen(
      const ScreenBinding(
        name: 'greet',
        ir: IrTree(
          name: 'greet',
          version: 1,
          root: WidgetNode(
            name: 'Text',
            args: const {'data': RefNode(['msg'])},
          ),
        ),
        inputs: [],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SduiScreen(
          name: 'greet',
          runtime: rt,
          inputs: const {'msg': 'hey'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('hey'), findsOneWidget);
  });

  testWidgets('SduiScreen uses custom errorBuilder', (tester) async {
    final rt = Runtime(
      errorBuilder: (ctx, err) => Text(
        'custom: $err',
        textDirection: TextDirection.ltr,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: SduiScreen(name: 'nope', runtime: rt)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('custom:'), findsOneWidget);
  });

  testWidgets('SduiScreen uses custom loadingBuilder', (tester) async {
    final rt = Runtime(
      loadingBuilder: (ctx) => const Text(
        'loading...',
        textDirection: TextDirection.ltr,
      ),
    );
    rt.registerWidget('Text', (args) => Text(args['data']! as String));
    rt.registerScreen(
      const ScreenBinding(
        name: 'slow',
        ir: IrTree(
          name: 'slow',
          version: 1,
          root: WidgetNode(
            name: 'Text',
            args: const {'data': LiteralNode('done')},
          ),
        ),
        inputs: [],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: SduiScreen(name: 'slow', runtime: rt)),
    );
    expect(find.text('loading...'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('done'), findsOneWidget);
  });

  testWidgets('SduiScreen injects BuildContext as reserved context key',
      (tester) async {
    BuildContext? capturedContext;
    final rt = Runtime();
    rt.registerWidget('CaptureContext', (args) {
      capturedContext = args['ctx'] as BuildContext?;
      return const SizedBox();
    });
    rt.registerScreen(
      const ScreenBinding(
        name: 'ctx_test',
        ir: IrTree(
          name: 'ctx_test',
          version: 1,
          root: WidgetNode(
            name: 'CaptureContext',
            args: {'ctx': RefNode(['context'])},
          ),
        ),
        inputs: [],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: SduiScreen(name: 'ctx_test', runtime: rt)),
    );
    await tester.pumpAndSettle();
    expect(capturedContext, isNotNull);
    expect(capturedContext, isA<BuildContext>());
  });

  testWidgets('SduiScreen host-supplied context overrides auto-injected',
      (tester) async {
    BuildContext? capturedContext;
    final overrideContext =
        _FakeBuildContext('host-override-context');
    final rt = Runtime();
    rt.registerWidget('CaptureContext', (args) {
      capturedContext = args['ctx'] as BuildContext?;
      return const SizedBox();
    });
    rt.registerScreen(
      const ScreenBinding(
        name: 'ctx_override',
        ir: IrTree(
          name: 'ctx_override',
          version: 1,
          root: WidgetNode(
            name: 'CaptureContext',
            args: {'ctx': RefNode(['context'])},
          ),
        ),
        inputs: [],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SduiScreen(
          name: 'ctx_override',
          runtime: rt,
          inputs: {'context': overrideContext},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(capturedContext, same(overrideContext));
  });
}

class _FakeBuildContext implements BuildContext {
  _FakeBuildContext(this._label);
  final String _label;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  String toString() => _label;
}
