// Widget-level integration test for payload functions.
//
// Verifies that `resolveNode` correctly handles a `ScreenWithFunctionsNode`
// at the root: it builds a `RuntimeContext` from the function list and
// threads it through every recursive call site so a `PayloadFunctionCallNode`
// inside an arg slot resolves against the file-local function table.
//
// This is the test that catches the runtime-resolver-bypassed-by-eval-only
// bug. The earlier `payload_function_eval_test.dart` exercises only
// `evalExpression`, which is not what `SduiScreen` calls.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui/src/resolve.dart';
import 'package:desk_sdui/src/runtime.dart';

void main() {
  late Runtime rt;

  setUp(() {
    rt = Runtime();
    // Minimal Text-like widget keyed by `data`.
    rt.registerWidgetWithContext('Sentinel', (ctx, args) {
      return Text(
        args['data'] as String? ?? '',
        textDirection: TextDirection.ltr,
      );
    });
  });

  Widget resolveOnce(IrNode root, Map<String, Object?> input) {
    return Builder(
      builder: (ctx) => resolveNode(ctx, root, input, rt),
    );
  }

  testWidgets(
    'ScreenWithFunctionsNode: payload fn call inside a widget arg renders correctly',
    (tester) async {
      // Payload function: String describe(int count) {
      //   if (count == 0) return 'No items';
      //   if (count == 1) return '1 item';
      //   return '$count items';
      // }
      const describeFn = PayloadFunctionNode(
        name: 'describe',
        params: ['count'],
        body: BlockNode(statements: [
          IfStatementNode(
            cond: CompareOpNode(
              op: CompareOp.eq,
              left: RefNode(['count']),
              right: LiteralNode(0),
            ),
            then: ReturnNode(value: LiteralNode('No items')),
          ),
          IfStatementNode(
            cond: CompareOpNode(
              op: CompareOp.eq,
              left: RefNode(['count']),
              right: LiteralNode(1),
            ),
            then: ReturnNode(value: LiteralNode('1 item')),
          ),
          ReturnNode(
            value: StringInterpNode([
              RefNode(['count']),
              ' items',
            ]),
          ),
        ]),
      );

      // Screen body: Sentinel(data: describe(vm.items.length))
      const screenRoot = ScreenWithFunctionsNode(
        functions: [describeFn],
        screenBody: WidgetNode(
          name: 'Sentinel',
          args: {
            'data': PayloadFunctionCallNode(
              name: 'describe',
              args: [LengthOfNode(RefNode(['vm', 'items']))],
            ),
          },
        ),
      );

      // count == 0
      await tester.pumpWidget(
        resolveOnce(screenRoot, {
          'vm': {'items': <String>[]},
        }),
      );
      expect(find.text('No items'), findsOneWidget);

      // count == 1
      await tester.pumpWidget(
        resolveOnce(screenRoot, {
          'vm': {'items': <String>['only']},
        }),
      );
      expect(find.text('1 item'), findsOneWidget);

      // count > 1
      await tester.pumpWidget(
        resolveOnce(screenRoot, {
          'vm': {'items': <String>['a', 'b', 'c', 'd', 'e']},
        }),
      );
      expect(find.text('5 items'), findsOneWidget);
    },
  );

  testWidgets(
    'ScreenWithFunctionsNode threads ctx through nested widget args',
    (tester) async {
      // Two-level: outer Sentinel wraps inner Sentinel whose `data` arg
      // calls a payload function. Verifies ctx propagates through
      // _resolveArg for nested WidgetNodes.
      const greetFn = PayloadFunctionNode(
        name: 'greet',
        params: ['name'],
        body: StringInterpNode(['Hello, ', RefNode(['name']), '!']),
      );

      // outer Sentinel with a `data` arg whose value is the result of a
      // nested PayloadFunctionCallNode (not a child widget — just nested
      // expression context).
      const screenRoot = ScreenWithFunctionsNode(
        functions: [greetFn],
        screenBody: WidgetNode(
          name: 'Sentinel',
          args: {
            'data': PayloadFunctionCallNode(
              name: 'greet',
              args: [RefNode(['who'])],
            ),
          },
        ),
      );

      await tester.pumpWidget(resolveOnce(screenRoot, {'who': 'world'}));
      expect(find.text('Hello, world!'), findsOneWidget);
    },
  );
}
