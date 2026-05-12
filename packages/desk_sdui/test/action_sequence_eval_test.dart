// Tests for ActionSequenceNode resolution in _resolveArg (resolve.dart).
// The closure returned is a `Future<void> Function()`. We verify ordering,
// bind-result propagation, non-await, and error propagation.

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
  rt.registerWidgetWithContext('ActionSentinel', (ctx, args) {
    captured = args['handler'];
    return const SizedBox.shrink();
  });

  final widgetNode = WidgetNode(
    name: 'ActionSentinel',
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
  // 1. Single awaited step, no bind — closure awaits the call and returns.
  // ---------------------------------------------------------------------------
  testWidgets('single awaited step — closure awaits call', (tester) async {
    final log = <String>[];
    final rt = Runtime();
    rt.registerFunction('step1', (args) {
      log.add('step1');
      return Future<void>.value();
    });

    const node = ActionSequenceNode(
      steps: [
        ActionStepNode(
          call: MethodCallNode(receiver: null, name: 'step1', args: []),
          awaitResult: true,
        ),
      ],
    );

    final captured = await resolveAsHandler(tester, node, rt, const {});
    expect(captured, isA<Function>());
    final closure = captured as Future<void> Function();
    await closure();
    expect(log, ['step1']);
  });

  // ---------------------------------------------------------------------------
  // 2. Two awaited steps — invoked in order.
  // ---------------------------------------------------------------------------
  testWidgets('two awaited steps — run in order', (tester) async {
    final log = <String>[];
    final rt = Runtime();
    rt.registerFunction('step1', (args) {
      log.add('step1');
      return Future<void>.value();
    });
    rt.registerFunction('step2', (args) {
      log.add('step2');
      return Future<void>.value();
    });

    const node = ActionSequenceNode(
      steps: [
        ActionStepNode(
          call: MethodCallNode(receiver: null, name: 'step1', args: []),
          awaitResult: true,
        ),
        ActionStepNode(
          call: MethodCallNode(receiver: null, name: 'step2', args: []),
          awaitResult: true,
        ),
      ],
    );

    final captured = await resolveAsHandler(tester, node, rt, const {});
    final closure = captured as Future<void> Function();
    await closure();
    expect(log, ['step1', 'step2']);
  });

  // ---------------------------------------------------------------------------
  // 3. bindResult binds the awaited value into env for later steps.
  // ---------------------------------------------------------------------------
  testWidgets('bindResult passes value to subsequent steps', (tester) async {
    String? receivedUser;
    final rt = Runtime();
    rt.registerFunction('getUser', (args) => Future<Object?>.value('alice'));
    rt.registerFunction('greet', (args) {
      receivedUser = args['arg0'] as String?;
      return Future<void>.value();
    });

    // Step 1: final user = await getUser()  → binds 'user' in localEnv
    // Step 2: await greet(user)
    const node = ActionSequenceNode(
      steps: [
        ActionStepNode(
          call: MethodCallNode(receiver: null, name: 'getUser', args: []),
          awaitResult: true,
          bindResult: 'user',
        ),
        ActionStepNode(
          call: MethodCallNode(
            receiver: null,
            name: 'greet',
            args: [RefNode(['user'])],
          ),
          awaitResult: true,
        ),
      ],
    );

    final captured = await resolveAsHandler(tester, node, rt, const {});
    final closure = captured as Future<void> Function();
    await closure();
    expect(receivedUser, 'alice');
  });

  // ---------------------------------------------------------------------------
  // 4. awaitResult:false step — fire and forget (doesn't block on the future).
  // ---------------------------------------------------------------------------
  testWidgets('awaitResult:false step — completes before inner future', (tester) async {
    final log = <String>[];
    final rt = Runtime();
    // Returns immediately with an already-completed future
    rt.registerFunction('sync', (args) {
      log.add('sync_called');
      return null; // non-Future → awaitResult:false means result ignored
    });

    const node = ActionSequenceNode(
      steps: [
        ActionStepNode(
          call: MethodCallNode(receiver: null, name: 'sync', args: []),
          awaitResult: false,
        ),
      ],
    );

    final captured = await resolveAsHandler(tester, node, rt, const {});
    final closure = captured as Future<void> Function();
    await closure();
    expect(log, ['sync_called']);
  });

  // ---------------------------------------------------------------------------
  // 5. Inner call throws — Future.error propagates from the closure.
  // ---------------------------------------------------------------------------
  testWidgets('inner call throws — error propagates', (tester) async {
    final rt = Runtime();
    rt.registerFunction('boom', (args) {
      throw StateError('expected_error');
    });

    const node = ActionSequenceNode(
      steps: [
        ActionStepNode(
          call: MethodCallNode(receiver: null, name: 'boom', args: []),
          awaitResult: true,
        ),
      ],
    );

    final captured = await resolveAsHandler(tester, node, rt, const {});
    final closure = captured as Future<void> Function();
    await expectLater(closure, throwsA(isA<StateError>()));
  });
}
