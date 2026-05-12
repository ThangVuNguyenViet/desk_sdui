import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/resolve.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for runtime-side `IrStatefulNode` handling (Plan #11).
///
/// These cover:
///   - field initializers run once in initState
///   - field cells persist across rebuilds (state shadows VM inputs)
///   - a sync block-bodied lambda mutates a cell and the setState hook
///     triggers a rebuild
void main() {
  late Runtime rt;

  setUp(() {
    rt = Runtime();
    rt.registerWidgetWithContext('Label', (ctx, args) {
      return Text(
        args['text'] as String? ?? '',
        textDirection: TextDirection.ltr,
      );
    });
    rt.registerWidgetWithContext('TapBox', (ctx, args) {
      final onTap = args['onTap'] as void Function()?;
      final child = args['child'] as Widget?;
      return GestureDetector(onTap: onTap, child: child);
    });
    rt.registerWidgetWithContext('Pair', (ctx, args) {
      return Column(
        textDirection: TextDirection.ltr,
        children: [
          args['top']! as Widget,
          args['bottom']! as Widget,
        ],
      );
    });
  });

  Widget resolveOnce(IrNode root, Map<String, Object?> input) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(builder: (ctx) => resolveNode(ctx, root, input, rt)),
    );
  }

  testWidgets('IrStatefulNode initializes field cells once', (tester) async {
    // Stateful screen with a single `count = 7` field and a Label that
    // interpolates `$count`. The body is a ReturnNode wrapping a Label.
    const ir = IrStatefulNode(
      fields: [
        IrStatefulFieldNode(
          name: 'count',
          initializer: LiteralNode(7),
          isFinal: false,
        ),
      ],
      body: WidgetNode(
        name: 'Label',
        args: {
          'text': StringInterpNode(['v=', RefNode(['count'])]),
        },
      ),
    );
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('v=7'), findsOneWidget);
  });

  testWidgets(
      'IrStatefulNode: tapping a block-bodied sync lambda mutates the cell and rebuilds',
      (tester) async {
    // Equivalent to:
    //   var count = 0;
    //   return Pair(
    //     top: Label(text: 'v=$count'),
    //     bottom: TapBox(onTap: () { count = count + 1; }, child: Label(text: 'tap')),
    //   );
    const ir = IrStatefulNode(
      fields: [
        IrStatefulFieldNode(
          name: 'count',
          initializer: LiteralNode(0),
          isFinal: false,
        ),
      ],
      body: WidgetNode(
        name: 'Pair',
        args: {
          'top': WidgetNode(
            name: 'Label',
            args: {
              'text': StringInterpNode(['v=', RefNode(['count'])]),
            },
          ),
          'bottom': WidgetNode(
            name: 'TapBox',
            args: {
              'onTap': LambdaNode(
                params: [],
                body: BlockNode(
                  statements: [
                    AssignNode(
                      name: 'count',
                      value: ArithOpNode(
                        op: ArithOp.add,
                        left: RefNode(['count']),
                        right: LiteralNode(1),
                      ),
                    ),
                  ],
                ),
              ),
              'child': WidgetNode(
                name: 'Label',
                args: {'text': LiteralNode('tap')},
              ),
            },
          ),
        },
      ),
    );
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('v=0'), findsOneWidget);
    await tester.tap(find.text('tap'));
    await tester.pump();
    expect(find.text('v=1'), findsOneWidget);
    await tester.tap(find.text('tap'));
    await tester.pump();
    expect(find.text('v=2'), findsOneWidget);
  });

  testWidgets(
      'IrStatefulNode: multiple fields, second initializer references first',
      (tester) async {
    // var a = 3; var b = a + 1; → b should be 4.
    const ir = IrStatefulNode(
      fields: [
        IrStatefulFieldNode(
          name: 'a',
          initializer: LiteralNode(3),
          isFinal: false,
        ),
        IrStatefulFieldNode(
          name: 'b',
          initializer: ArithOpNode(
            op: ArithOp.add,
            left: RefNode(['a']),
            right: LiteralNode(1),
          ),
          isFinal: false,
        ),
      ],
      body: WidgetNode(
        name: 'Label',
        args: {
          'text': StringInterpNode(['a=', RefNode(['a']), ' b=', RefNode(['b'])]),
        },
      ),
    );
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('a=3 b=4'), findsOneWidget);
  });
}
