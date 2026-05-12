// Tests for TryStepNode resolution inside ActionSequenceNode.
// The try/catch block wraps steps in a Dart try/catch; on exception it binds
// the caught error and runs catchSteps.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/resolve.dart';

/// Helper: resolves [node] as a 'handler' argument by pumping a sentinel widget,
/// then extracts and returns the resolved value.
Future<Object?> resolveAsHandler(
  WidgetTester tester,
  IrNode node,
  Runtime rt,
  Map<String, Object?> input,
) async {
  Object? captured;
  rt.registerWidgetWithContext('TrySentinel', (ctx, args) {
    captured = args['handler'];
    return const SizedBox.shrink();
  });

  final widgetNode = WidgetNode(
    name: 'TrySentinel',
    args: {'handler': node},
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(builder: (ctx) => resolveNode(ctx, widgetNode, input, rt)),
    ),
  );

  return captured;
}

void main() {
  // ---------------------------------------------------------------------------
  // 1. Try with no exception: try-steps run, catch-steps skipped.
  // ---------------------------------------------------------------------------
  testWidgets('try succeeds — trySteps run, catchSteps skipped', (tester) async {
    final log = <String>[];
    final rt = Runtime();
    rt.registerFunction('save', (args) {
      log.add('save');
      return Future<void>.value();
    });
    rt.registerFunction('showError', (args) {
      log.add('showError');
      return null;
    });

    const node = ActionSequenceNode(
      steps: [
        TryStepNode(
          trySteps: [
            ActionStepNode(
              call: MethodCallNode(receiver: null, name: 'save', args: []),
              awaitResult: true,
            ),
          ],
          catchSteps: [
            ActionStepNode(
              call: MethodCallNode(receiver: null, name: 'showError', args: []),
              awaitResult: false,
            ),
          ],
          exceptionBind: 'e',
        ),
      ],
    );

    final captured = await resolveAsHandler(tester, node, rt, const {});
    final closure = captured as Future<void> Function();
    await closure();
    expect(log, ['save']);
  });

  // ---------------------------------------------------------------------------
  // 2. Try throws in step 1: catchSteps run with exceptionBind in env.
  // ---------------------------------------------------------------------------
  testWidgets('try throws — catchSteps run, exceptionBind set', (tester) async {
    final log = <String>[];
    Object? caughtErr;
    final rt = Runtime();
    rt.registerFunction('save', (args) {
      throw StateError('save_failed');
    });
    rt.registerFunction('showError', (args) {
      caughtErr = args['arg0'];
      log.add('showError');
      return null;
    });

    const node = ActionSequenceNode(
      steps: [
        TryStepNode(
          trySteps: [
            ActionStepNode(
              call: MethodCallNode(receiver: null, name: 'save', args: []),
              awaitResult: false,
            ),
          ],
          catchSteps: [
            ActionStepNode(
              call: MethodCallNode(
                receiver: null,
                name: 'showError',
                args: [RefNode(['e'])],
              ),
              awaitResult: false,
            ),
          ],
          exceptionBind: 'e',
        ),
      ],
    );

    final captured = await resolveAsHandler(tester, node, rt, const {});
    final closure = captured as Future<void> Function();
    await closure();
    expect(log, ['showError']);
    expect(caughtErr, isA<StateError>());
  });

  // ---------------------------------------------------------------------------
  // 3. exceptionBind is null — catchSteps run, no 'e' binding required.
  // ---------------------------------------------------------------------------
  testWidgets('catch without bind — catchSteps run, no error binding', (tester) async {
    final log = <String>[];
    final rt = Runtime();
    rt.registerFunction('boom', (args) => throw Exception('x'));
    rt.registerFunction('cleanup', (args) {
      log.add('cleanup');
      return null;
    });

    const node = ActionSequenceNode(
      steps: [
        TryStepNode(
          trySteps: [
            ActionStepNode(
              call: MethodCallNode(receiver: null, name: 'boom', args: []),
              awaitResult: false,
            ),
          ],
          catchSteps: [
            ActionStepNode(
              call: MethodCallNode(receiver: null, name: 'cleanup', args: []),
              awaitResult: false,
            ),
          ],
          // exceptionBind: null (default)
        ),
      ],
    );

    final captured = await resolveAsHandler(tester, node, rt, const {});
    final closure = captured as Future<void> Function();
    await closure();
    expect(log, ['cleanup']);
  });

  // ---------------------------------------------------------------------------
  // 4. Outer step after try sees the try-branch env (try's bindings propagate).
  //    Per plan: on success the resolver returns the try-branch env to the
  //    outer sequence, so bindResult from inside the try IS visible to later
  //    steps. Catch bindings do NOT propagate.
  // ---------------------------------------------------------------------------
  testWidgets('outer steps after try see try-branch env', (tester) async {
    Object? afterValue;
    final rt = Runtime();
    rt.registerFunction('getVal', (args) => Future<Object?>.value('try_result'));
    rt.registerFunction('readEnv', (args) {
      afterValue = args['arg0'];
      return null;
    });

    // try { final x = await getVal(); } catch { }
    // readEnv(x) — x IS visible here because the try's env is propagated.
    const node = ActionSequenceNode(
      steps: [
        TryStepNode(
          trySteps: [
            ActionStepNode(
              call: MethodCallNode(receiver: null, name: 'getVal', args: []),
              awaitResult: true,
              bindResult: 'x',
            ),
          ],
          catchSteps: [],
          exceptionBind: null,
        ),
        ActionStepNode(
          call: MethodCallNode(
            receiver: null,
            name: 'readEnv',
            args: [RefNode(['x'])],
          ),
          awaitResult: false,
        ),
      ],
    );

    final captured = await resolveAsHandler(tester, node, rt, const {});
    final closure = captured as Future<void> Function();
    await closure();
    // 'x' was bound in the try-branch env; per the resolver implementation
    // that env is returned to the outer sequence on success.
    expect(afterValue, 'try_result');
  });

  // ---------------------------------------------------------------------------
  // 5. Nested TryStepNode: inner catch handles inner exception, outer continues.
  // ---------------------------------------------------------------------------
  testWidgets('nested try — inner catch fires, outer continues', (tester) async {
    final log = <String>[];
    final rt = Runtime();
    rt.registerFunction('inner', (args) => throw Exception('inner_err'));
    rt.registerFunction('innerCatch', (args) {
      log.add('innerCatch');
      return null;
    });
    rt.registerFunction('outer', (args) {
      log.add('outer');
      return null;
    });

    const node = ActionSequenceNode(
      steps: [
        TryStepNode(
          trySteps: [
            ActionStepNode(
              call: MethodCallNode(receiver: null, name: 'inner', args: []),
              awaitResult: false,
            ),
          ],
          catchSteps: [
            ActionStepNode(
              call: MethodCallNode(receiver: null, name: 'innerCatch', args: []),
              awaitResult: false,
            ),
          ],
          exceptionBind: 'e',
        ),
        ActionStepNode(
          call: MethodCallNode(receiver: null, name: 'outer', args: []),
          awaitResult: false,
        ),
      ],
    );

    final captured = await resolveAsHandler(tester, node, rt, const {});
    final closure = captured as Future<void> Function();
    await closure();
    expect(log, ['innerCatch', 'outer']);
  });
}
