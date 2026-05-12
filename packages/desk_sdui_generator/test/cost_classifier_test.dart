// ignore_for_file: lines_longer_than_80_chars
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_generator/src/cost_classifier/classifier.dart';
import 'package:desk_sdui_generator/src/cost_classifier/diagnostics.dart';
import 'package:test/test.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // Part 1 — Classifier unit tests on synthetic IR
  // ─────────────────────────────────────────────────────────────────────────

  group('CostClassifier', () {
    // 1. Widget foo() { return Text('a'); } → pureBounded
    // Represented as a WidgetNode with a single LiteralNode arg.
    test('simple widget body → pureBounded', () {
      final body = WidgetNode(
        name: 'Text',
        args: {'data': LiteralNode('a')},
      );
      expect(classify(body, selfName: 'foo'), CostClass.pureBounded);
    });

    // 2. String foo(List<int> xs) { var s = ''; for (var x in xs) s += '$x'; return s; }
    // Represented as a ForNode whose source is a RefNode (parameter reference).
    test('for-loop over param ref → linearInArg', () {
      final body = ForNode(
        variable: 'x',
        source: RefNode(['xs']), // xs is a parameter → data-dependent
        body: LiteralNode(0), // body irrelevant for classification
      );
      expect(classify(body, selfName: 'foo'), CostClass.linearInArg);
    });

    // For-loop over a literal list → pureBounded (literal source)
    test('for-loop over literal list → pureBounded', () {
      final body = ForNode(
        variable: 'x',
        source: ListNode([LiteralNode(1), LiteralNode(2), LiteralNode(3)]),
        body: LiteralNode(0),
      );
      expect(classify(body, selfName: 'foo'), CostClass.pureBounded);
    });

    // 3. int run(int x) { var i = 0; while (vm.notDone()) i++; return i; }
    // WhileNode doesn't exist in current IR; we simulate it via unbounded
    // by constructing a _Findings with hasUnboundedLoop manually.
    // Instead, we test the classify() logic path for unbounded using a
    // ForNode with a non-literal, non-ref source (conservative path).
    //
    // In current IR: unbounded loops can't be represented, so this tests
    // the conservative MethodCallNode-source path.
    test('for-loop over method call result → linearInArg (conservative)', () {
      // Source is a MethodCallNode result — not a literal, so data-dependent.
      final body = ForNode(
        variable: 'x',
        source: MethodCallNode(
          receiver: RefNode(['vm']),
          name: 'getItems',
          args: [],
        ),
        body: LiteralNode(0),
      );
      expect(classify(body, selfName: 'run'), CostClass.linearInArg);
    });

    // 4. int fact(int n) { if (n <= 1) return 1; return n * fact(n - 1); }
    // Represented as a ConditionalNode with a recursive MethodCallNode
    // whose first arg is ArithOpNode(n - 1).
    test('recursive call with size-decreasing arg → recursiveSizeDecreasing', () {
      // fact(n - 1): the call has one arg = ArithOpNode(ref(n) - literal(1))
      final body = ConditionalNode(
        condition: CompareOpNode(
          op: CompareOp.lte,
          left: RefNode(['n']),
          right: LiteralNode(1),
        ),
        thenBranch: LiteralNode(1),
        elseBranch: MethodCallNode(
          receiver: null,
          name: 'fact', // self-call
          args: [
            ArithOpNode(
              op: ArithOp.sub,
              left: RefNode(['n']),
              right: LiteralNode(1), // size-decrement
            ),
          ],
        ),
      );
      expect(classify(body, selfName: 'fact'), CostClass.recursiveSizeDecreasing);
    });

    // 5. int foo(int n) { return foo(n + 1); } → recursiveFree
    // The self-call has ArithOpNode(n + 1) as arg — addition is not a
    // size-decrement, so it's free recursion.
    test('recursive call without size-decreasing arg → recursiveFree', () {
      final body = MethodCallNode(
        receiver: null,
        name: 'foo',
        args: [
          ArithOpNode(
            op: ArithOp.add,
            left: RefNode(['n']),
            right: LiteralNode(1), // + 1, not - 1
          ),
        ],
      );
      expect(classify(body, selfName: 'foo'), CostClass.recursiveFree);
    });

    // Free recursion beats size-decreasing when both present.
    test('mixed recursion (free + size-dec) → recursiveFree wins', () {
      // Two branches: one has size-dec arg, one has free arg.
      final body = ConditionalNode(
        condition: LiteralNode(true),
        thenBranch: MethodCallNode(
          receiver: null,
          name: 'bar',
          args: [ArithOpNode(op: ArithOp.sub, left: RefNode(['n']), right: LiteralNode(1))],
        ),
        elseBranch: MethodCallNode(
          receiver: null,
          name: 'bar',
          args: [RefNode(['n'])], // no decrement
        ),
      );
      expect(classify(body, selfName: 'bar'), CostClass.recursiveFree);
    });

    // No self-name: MethodCallNode is not treated as self-recursion.
    test('no selfName → external calls not flagged as recursion', () {
      final body = MethodCallNode(
        receiver: null,
        name: 'helper',
        args: [],
      );
      expect(classify(body, selfName: null), CostClass.pureBounded);
      expect(classify(body, selfName: 'other'), CostClass.pureBounded);
    });

    // Nested ForNode: inner loop counts too.
    test('nested for-loops over param → linearInArg', () {
      final inner = ForNode(
        variable: 'j',
        source: RefNode(['ys']),
        body: LiteralNode(0),
      );
      final body = ForNode(
        variable: 'i',
        source: RefNode(['xs']),
        body: inner,
      );
      expect(classify(body, selfName: 'foo'), CostClass.linearInArg);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Part 2 — Diagnostic emission tests
  // ─────────────────────────────────────────────────────────────────────────

  group('emitCostDiagnostics', () {
    // 1. Linear function called from build → info diagnostic
    test('linearInArg in build → info severity', () {
      final sites = [
        const CallSiteRecord(
          calleeName: 'sumPositives',
          callerName: 'myScreen',
          context: CallSiteContext.build,
        ),
      ];
      final classes = {'sumPositives': CostClass.linearInArg};
      final diags = emitCostDiagnostics(sites, classes);
      expect(diags.length, 1);
      expect(diags.first.severity, Severity.info);
      expect(diags.first.code, 'sdui_potential_cost.linear_in_build');
      expect(diags.first.message, contains('"sumPositives" is O(N)'));
      expect(diags.first.message, contains('build'));
    });

    // 2. Same linear function called from action → no diagnostic
    test('linearInArg in action → silent', () {
      final sites = [
        const CallSiteRecord(
          calleeName: 'sumPositives',
          callerName: 'myScreen',
          context: CallSiteContext.action,
        ),
      ];
      final classes = {'sumPositives': CostClass.linearInArg};
      final diags = emitCostDiagnostics(sites, classes);
      expect(diags, isEmpty);
    });

    // 3. Unbounded called from build → warning
    test('unbounded in build → warning', () {
      final sites = [
        const CallSiteRecord(
          calleeName: 'doWork',
          callerName: 'myScreen',
          context: CallSiteContext.build,
        ),
      ];
      final classes = {'doWork': CostClass.unbounded};
      final diags = emitCostDiagnostics(sites, classes);
      expect(diags.length, 1);
      expect(diags.first.severity, Severity.warning);
      expect(diags.first.code, 'sdui_potential_cost.unbounded_in_build');
      expect(diags.first.message, contains('"doWork"'));
      expect(diags.first.message, contains('per-frame'));
    });

    // 4. Unbounded called from action → info
    test('unbounded in action → info', () {
      final sites = [
        const CallSiteRecord(
          calleeName: 'doWork',
          callerName: 'myScreen',
          context: CallSiteContext.action,
        ),
      ];
      final classes = {'doWork': CostClass.unbounded};
      final diags = emitCostDiagnostics(sites, classes);
      expect(diags.length, 1);
      expect(diags.first.severity, Severity.info);
      expect(diags.first.code, 'sdui_potential_cost.unbounded_in_action');
    });

    // 5. Free-recursion called anywhere → warning
    test('recursiveFree in build → warning', () {
      final sites = [
        const CallSiteRecord(
          calleeName: 'infiniteLoop',
          callerName: 'myScreen',
          context: CallSiteContext.build,
        ),
      ];
      final classes = {'infiniteLoop': CostClass.recursiveFree};
      final diags = emitCostDiagnostics(sites, classes);
      expect(diags.length, 1);
      expect(diags.first.severity, Severity.warning);
      expect(diags.first.code, 'sdui_potential_cost.recursive_free');
    });

    test('recursiveFree in action → warning', () {
      final sites = [
        const CallSiteRecord(
          calleeName: 'infiniteLoop',
          callerName: 'myScreen',
          context: CallSiteContext.action,
        ),
      ];
      final classes = {'infiniteLoop': CostClass.recursiveFree};
      final diags = emitCostDiagnostics(sites, classes);
      expect(diags.length, 1);
      expect(diags.first.severity, Severity.warning);
    });

    // 6. Pure-bounded called from anywhere → silent
    test('pureBounded anywhere → silent', () {
      final sites = [
        const CallSiteRecord(
          calleeName: 'label',
          callerName: 'myScreen',
          context: CallSiteContext.build,
        ),
        const CallSiteRecord(
          calleeName: 'label',
          callerName: 'myScreen',
          context: CallSiteContext.signal,
        ),
        const CallSiteRecord(
          calleeName: 'label',
          callerName: 'myScreen',
          context: CallSiteContext.action,
        ),
      ];
      final classes = {'label': CostClass.pureBounded};
      final diags = emitCostDiagnostics(sites, classes);
      expect(diags, isEmpty);
    });

    // Unknown callee → no diagnostic emitted (graceful)
    test('unknown callee → no diagnostic', () {
      final sites = [
        const CallSiteRecord(
          calleeName: 'unknown',
          callerName: 'myScreen',
          context: CallSiteContext.build,
        ),
      ];
      final classes = <String, CostClass>{}; // not classified
      final diags = emitCostDiagnostics(sites, classes);
      expect(diags, isEmpty);
    });

    // recursiveSizeDecreasing in signal → info
    test('recursiveSizeDecreasing in signal → info', () {
      final sites = [
        const CallSiteRecord(
          calleeName: 'fact',
          callerName: 'myScreen',
          context: CallSiteContext.signal,
        ),
      ];
      final classes = {'fact': CostClass.recursiveSizeDecreasing};
      final diags = emitCostDiagnostics(sites, classes);
      expect(diags.length, 1);
      expect(diags.first.severity, Severity.info);
    });

    // linearInArg in signal → info
    test('linearInArg in signal → info', () {
      final sites = [
        const CallSiteRecord(
          calleeName: 'buildList',
          callerName: 'myScreen',
          context: CallSiteContext.signal,
        ),
      ];
      final classes = {'buildList': CostClass.linearInArg};
      final diags = emitCostDiagnostics(sites, classes);
      expect(diags.length, 1);
      expect(diags.first.severity, Severity.info);
      expect(diags.first.code, 'sdui_potential_cost.linear_in_signal');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Part 3 — diagnosticFor matrix completeness
  // ─────────────────────────────────────────────────────────────────────────

  group('diagnosticFor matrix', () {
    test('pureBounded is always null', () {
      for (final ctx in CallSiteContext.values) {
        expect(
          diagnosticFor(CostClass.pureBounded, ctx),
          isNull,
          reason: 'pureBounded in ${ctx.name} should be silent',
        );
      }
    });

    test('recursiveFree is always warning', () {
      for (final ctx in CallSiteContext.values) {
        expect(
          diagnosticFor(CostClass.recursiveFree, ctx),
          Severity.warning,
          reason: 'recursiveFree in ${ctx.name} should be warning',
        );
      }
    });
  });
}
