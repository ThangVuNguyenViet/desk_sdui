import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/resolve.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Runtime rt;

  setUp(() {
    rt = Runtime();
    rt.registerWidgetWithContext('Sentinel', (ctx, args) {
      return Text(
        args['label'] as String? ?? '',
        textDirection: TextDirection.ltr,
      );
    });
  });

  Widget resolveOnce(IrNode root, Map<String, Object?> input) {
    return Builder(
      builder: (ctx) => resolveNode(ctx, root, input, rt),
    );
  }

  group('resolveNode(BlockNode)', () {
    // Test 1: a BlockNode containing just a ReturnNode renders the returned
    // widget IR.
    testWidgets('BlockNode([Return(Widget)]) renders the widget', (tester) async {
      const ir = BlockNode(statements: [
        ReturnNode(
          value: WidgetNode(name: 'Sentinel', args: {
            'label': LiteralNode('hello'),
          }),
        ),
      ]);
      await tester.pumpWidget(resolveOnce(ir, {}));
      expect(find.text('hello'), findsOneWidget);
    });

    // Test 2: BlockNode with an early-return inside a true if-branch
    // returns the if-branch widget (else-branch ignored).
    testWidgets('BlockNode early-return via IfStatementNode (true cond)',
        (tester) async {
      const ir = BlockNode(statements: [
        IfStatementNode(
          cond: LiteralNode(true),
          then: ReturnNode(
            value: WidgetNode(name: 'Sentinel', args: {
              'label': LiteralNode('then'),
            }),
          ),
        ),
        ReturnNode(
          value: WidgetNode(name: 'Sentinel', args: {
            'label': LiteralNode('fallthrough'),
          }),
        ),
      ]);
      await tester.pumpWidget(resolveOnce(ir, {}));
      expect(find.text('then'), findsOneWidget);
      expect(find.text('fallthrough'), findsNothing);
    });

    // Test 3: false-cond if-branch falls through; trailing return renders.
    testWidgets('BlockNode falls through false IfStatementNode to trailing return',
        (tester) async {
      const ir = BlockNode(statements: [
        IfStatementNode(
          cond: LiteralNode(false),
          then: ReturnNode(
            value: WidgetNode(name: 'Sentinel', args: {
              'label': LiteralNode('then'),
            }),
          ),
        ),
        ReturnNode(
          value: WidgetNode(name: 'Sentinel', args: {
            'label': LiteralNode('fallthrough'),
          }),
        ),
      ]);
      await tester.pumpWidget(resolveOnce(ir, {}));
      expect(find.text('then'), findsNothing);
      expect(find.text('fallthrough'), findsOneWidget);
    });

    // Test 4: a BlockNode that never returns throws a clear StateError.
    testWidgets('BlockNode without any return throws StateError', (tester) async {
      const ir = BlockNode(statements: [
        // No ReturnNode anywhere.
        LetStatementNode(name: 'x', value: LiteralNode(1), isFinal: false),
      ]);
      await tester.pumpWidget(
        Builder(builder: (ctx) {
          return Builder(
            builder: (ctx2) {
              expect(
                () => resolveNode(ctx2, ir, {}, rt),
                throwsA(
                  isA<StateError>().having(
                    (e) => e.message,
                    'message',
                    contains('fell through without a return'),
                  ),
                ),
              );
              return const SizedBox.shrink();
            },
          );
        }),
      );
    });

    // Test 5: a BreakNode at widget position throws.
    testWidgets('BreakNode at screen root throws StateError', (tester) async {
      const ir = BlockNode(statements: [BreakNode()]);
      await tester.pumpWidget(
        Builder(builder: (ctx) {
          expect(
            () => resolveNode(ctx, ir, {}, rt),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('`break` at screen root is illegal'),
              ),
            ),
          );
          return const SizedBox.shrink();
        }),
      );
    });
  });
}
