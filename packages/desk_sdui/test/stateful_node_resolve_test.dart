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

  testWidgets(
      'IrStatefulNode: sibling stateful subscreens with distinct ids keep '
      'independent state', (tester) async {
    // Two `IrStatefulNode`s side-by-side, each with its own `count`. We
    // mutate only the left one; the right one must NOT see the mutation.
    // Without a per-node `ValueKey` Flutter element-reuse would assign the
    // State<> by sibling position and the two would share cells.
    IrStatefulNode mkCounter(String id) => IrStatefulNode(
          id: id,
          fields: const [
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
                  'text': StringInterpNode([id, '=', const RefNode(['count'])]),
                },
              ),
              'bottom': WidgetNode(
                name: 'TapBox',
                args: {
                  'onTap': const LambdaNode(
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
                    args: {'text': LiteralNode('tap-$id')},
                  ),
                },
              ),
            },
          ),
        );

    final ir = WidgetNode(
      name: 'Pair',
      args: {
        'top': mkCounter('left'),
        'bottom': mkCounter('right'),
      },
    );
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('left=0'), findsOneWidget);
    expect(find.text('right=0'), findsOneWidget);

    await tester.tap(find.text('tap-left'));
    await tester.pump();
    expect(find.text('left=1'), findsOneWidget);
    expect(find.text('right=0'), findsOneWidget);

    await tester.tap(find.text('tap-right'));
    await tester.pump();
    await tester.tap(find.text('tap-right'));
    await tester.pump();
    expect(find.text('left=1'), findsOneWidget);
    expect(find.text('right=2'), findsOneWidget);
  });

  testWidgets(
      'IrStatefulNode: conditional swap preserves per-id state (no cross-talk)',
      (tester) async {
    // Render one of two stateful subtrees based on a flag held outside the
    // SDUI tree. Each has a distinct id, so swapping should NOT carry the
    // counter value across (each branch resumes its own value if revisited).
    const aNode = IrStatefulNode(
      id: 'a',
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
              'text': StringInterpNode(['a=', RefNode(['count'])]),
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
                args: {'text': LiteralNode('bump-a')},
              ),
            },
          ),
        },
      ),
    );
    const bNode = IrStatefulNode(
      id: 'b',
      fields: [
        IrStatefulFieldNode(
          name: 'count',
          initializer: LiteralNode(100),
          isFinal: false,
        ),
      ],
      body: WidgetNode(
        name: 'Label',
        args: {
          'text': StringInterpNode(['b=', RefNode(['count'])]),
        },
      ),
    );

    var showA = true;
    late void Function(void Function()) setOuter;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StatefulBuilder(
          builder: (ctx, setState) {
            setOuter = setState;
            return resolveNode(ctx, showA ? aNode : bNode, const {}, rt);
          },
        ),
      ),
    );

    expect(find.text('a=0'), findsOneWidget);
    await tester.tap(find.text('bump-a'));
    await tester.pump();
    await tester.tap(find.text('bump-a'));
    await tester.pump();
    expect(find.text('a=2'), findsOneWidget);

    // Swap to B — its initializer should run fresh (count = 100).
    setOuter(() => showA = false);
    await tester.pump();
    expect(find.text('b=100'), findsOneWidget);
    // No leftover `a=2` label should be present.
    expect(find.text('a=2'), findsNothing);
  });
}
