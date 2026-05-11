// ignore_for_file: avoid_catches_without_on_clauses

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/resolve.dart';

/// Helper: resolves [node] as an argument value (not a widget) within a
/// [BuildContext] by pumping a throwaway widget and calling _resolveArg
/// indirectly — we use a Text widget whose label arg is resolved from [node].
///
/// For MethodCallNode and ValueCtorNode (which live in arg position), we wire
/// them as the 'label' arg of a sentinel Text widget so the resolver exercises
/// the full _resolveArg → new cases path.
///
/// For the WidgetNode regression, we pump a widget built directly.

void main() {
  // -----------------------------------------------------------------------
  // MethodCallNode — resolved via Runtime.invokeMethod
  // -----------------------------------------------------------------------
  testWidgets('MethodCallNode resolves via Runtime.invokeMethod', (tester) async {
    final rt = Runtime();
    rt.registerMethod(
      'String.toUpperCase',
      (recv, _) => (recv as String).toUpperCase(),
    );
    // Register a sentinel Text that uses the method-call result as its label.
    rt.registerWidgetWithContext('Sentinel', (ctx, args) {
      return Text(
        args['label'] as String? ?? '',
        textDirection: TextDirection.ltr,
      );
    });

    const node = WidgetNode(
      name: 'Sentinel',
      args: {
        'label': MethodCallNode(
          receiver: LiteralNode('hello'),
          name: 'String.toUpperCase',
          args: [],
        ),
      },
    );

    await tester.pumpWidget(
      Builder(builder: (ctx) => resolveNode(ctx, node, const {}, rt)),
    );

    expect(find.text('HELLO'), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // ValueCtorNode — resolved via Runtime.invokeValueBuilder
  // -----------------------------------------------------------------------
  testWidgets('ValueCtorNode resolves via Runtime.invokeValueBuilder',
      (tester) async {
    final rt = Runtime();
    rt.registerValueBuilder(
      'EdgeInsets.all',
      (args) => EdgeInsets.all(args['arg0'] as double),
    );
    rt.registerWidgetWithContext('PaddingWrapper', (ctx, args) {
      return Padding(
        padding: args['padding'] as EdgeInsetsGeometry,
        child: const SizedBox.shrink(),
      );
    });

    const node = WidgetNode(
      name: 'PaddingWrapper',
      args: {
        'padding': ValueCtorNode(
          name: 'EdgeInsets.all',
          args: [LiteralNode(8.0)],
        ),
      },
    );

    await tester.pumpWidget(
      Builder(builder: (ctx) => resolveNode(ctx, node, const {}, rt)),
    );

    final paddingWidget = tester.widget<Padding>(find.byType(Padding));
    expect(paddingWidget.padding, const EdgeInsets.all(8));
  });

  // -----------------------------------------------------------------------
  // WidgetNode regression — resolveWidget path still works
  // -----------------------------------------------------------------------
  testWidgets('WidgetNode resolves via Runtime.resolveWidget (regression)',
      (tester) async {
    final rt = Runtime();
    rt.registerValueBuilder(
      'EdgeInsets.all',
      (args) => EdgeInsets.all(args['arg0'] as double),
    );
    // Register via registerWidget (new codegen path) — uses _sduiWidgets.
    rt.registerWidget('Padding', (args) {
      return Padding(
        padding: args['padding'] as EdgeInsetsGeometry,
        child: args['child'] as Widget? ?? const SizedBox.shrink(),
      );
    });

    const node = WidgetNode(
      name: 'Padding',
      args: {
        'padding': ValueCtorNode(
          name: 'EdgeInsets.all',
          args: [LiteralNode(8.0)],
        ),
        'child': LiteralNode(null),
      },
    );

    await tester.pumpWidget(
      Builder(builder: (ctx) => resolveNode(ctx, node, const {}, rt)),
    );

    expect(find.byType(Padding), findsOneWidget);
    final p = tester.widget<Padding>(find.byType(Padding));
    expect(p.padding, const EdgeInsets.all(8));
  });

  // -----------------------------------------------------------------------
  // Error cases — unregistered handlers throw StateError
  // -----------------------------------------------------------------------
  test('MethodCallNode throws StateError if handler not registered', () {
    final rt = Runtime();
    rt.registerWidgetWithContext('Sentinel', (ctx, args) {
      return Text(
        args['label'] as String? ?? '',
        textDirection: TextDirection.ltr,
      );
    });

    const node = WidgetNode(
      name: 'Sentinel',
      args: {
        'label': MethodCallNode(
          receiver: LiteralNode('hello'),
          name: 'String.toUpperCase',
          args: [],
        ),
      },
    );

    expect(
      () => resolveNode(_FakeBuildContext(), node, const {}, rt),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('String.toUpperCase'),
        ),
      ),
    );
  });

  test('ValueCtorNode throws StateError if builder not registered', () {
    final rt = Runtime();
    rt.registerWidgetWithContext('PaddingWrapper', (ctx, args) {
      return Padding(
        padding: args['padding'] as EdgeInsetsGeometry,
        child: const SizedBox.shrink(),
      );
    });

    const node = WidgetNode(
      name: 'PaddingWrapper',
      args: {
        'padding': ValueCtorNode(
          name: 'EdgeInsets.all',
          args: [LiteralNode(8.0)],
        ),
      },
    );

    expect(
      () => resolveNode(_FakeBuildContext(), node, const {}, rt),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('EdgeInsets.all'),
        ),
      ),
    );
  });
}

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
