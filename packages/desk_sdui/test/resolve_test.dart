import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/resolve.dart';

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
    rt.registerWidgetWithContext('Container', (ctx, args) {
      return Container(child: args['child'] as Widget?);
    });
    rt.registerWidgetWithContext('Column', (ctx, args) {
      return Column(
        children: (args['children']! as List).cast<Widget>(),
      );
    });
  });

  Widget resolveOnce(IrNode root, Map<String, Object?> input) {
    return Builder(
      builder: (ctx) => resolveNode(ctx, root, input, rt),
    );
  }

  testWidgets('WidgetNode looks up registered builder', (tester) async {
    const ir = WidgetNode(name: 'Sentinel', args: {
      'label': LiteralNode('hi'),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('hi'), findsOneWidget);
  });

  testWidgets('WidgetNode resolves RefNode args', (tester) async {
    const ir = WidgetNode(name: 'Sentinel', args: {
      'label': RefNode(['greeting']),
    },);
    await tester.pumpWidget(resolveOnce(ir, {'greeting': 'hello'}));
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('ListNode of WidgetNodes resolves to List<Widget>',
      (tester) async {
    const ir = WidgetNode(name: 'Column', args: {
      'children': ListNode([
        WidgetNode(name: 'Sentinel', args: {
          'label': LiteralNode('a'),
        },),
        WidgetNode(name: 'Sentinel', args: {
          'label': LiteralNode('b'),
        },),
      ]),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('ConditionalNode picks then-branch when condition true',
      (tester) async {
    const ir = ConditionalNode(
      condition: LiteralNode(true),
      thenBranch: WidgetNode(name: 'Sentinel', args: {
        'label': LiteralNode('y'),
      },),
      elseBranch: WidgetNode(name: 'Sentinel', args: {
        'label': LiteralNode('n'),
      },),
    );
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('y'), findsOneWidget);
    expect(find.text('n'), findsNothing);
  });

  testWidgets('ConditionalNode without else returns SizedBox.shrink',
      (tester) async {
    const ir = WidgetNode(name: 'Column', args: {
      'children': ListNode([
        ConditionalNode(
          condition: LiteralNode(false),
          thenBranch: WidgetNode(name: 'Sentinel', args: {
            'label': LiteralNode('x'),
          },),
        ),
      ]),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('x'), findsNothing);
  });

  testWidgets('ForNode iterates and resolves body', (tester) async {
    const ir = WidgetNode(name: 'Column', args: {
      'children': ForNode(
        variable: 'item',
        source: RefNode(['xs']),
        body: WidgetNode(name: 'Sentinel', args: {
          'label': RefNode(['item']),
        },),
      ),
    },);
    await tester.pumpWidget(resolveOnce(ir, {'xs': ['a', 'b', 'c']}));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('ForNode destructured iterates with indexed pair',
      (tester) async {
    const ir = WidgetNode(name: 'Column', args: {
      'children': ForNode.destructured(
        variables: ['i', 'x'],
        source: RefNode(['xs']),
        body: WidgetNode(name: 'Sentinel', args: {
          'label': StringInterpNode([
            RefNode(['i']),
            ':',
            RefNode(['x']),
          ]),
        },),
      ),
    },);
    await tester.pumpWidget(resolveOnce(ir, {
      'xs': [
        {'first': 0, 'second': 'a'},
        {'first': 1, 'second': 'b'},
      ],
    }),);
    expect(find.text('0:a'), findsOneWidget);
    expect(find.text('1:b'), findsOneWidget);
  });

  testWidgets('SpreadNode flattens into surrounding list', (tester) async {
    const ir = WidgetNode(name: 'Column', args: {
      'children': ListNode([
        WidgetNode(name: 'Sentinel', args: {
          'label': LiteralNode('head'),
        },),
        SpreadNode(ListNode([
          WidgetNode(name: 'Sentinel', args: {
            'label': LiteralNode('m1'),
          },),
          WidgetNode(name: 'Sentinel', args: {
            'label': LiteralNode('m2'),
          },),
        ]),),
        WidgetNode(name: 'Sentinel', args: {
          'label': LiteralNode('tail'),
        },),
      ]),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('head'), findsOneWidget);
    expect(find.text('m1'), findsOneWidget);
    expect(find.text('m2'), findsOneWidget);
    expect(find.text('tail'), findsOneWidget);
  });

  test('resolveNode throws for unregistered widget', () {
    const ir = WidgetNode(name: 'NotRegistered', args: {});
    expect(
      () => resolveNode(
        _FakeBuildContext(),
        ir,
        {},
        rt,
      ),
      throwsA(isA<StateError>()),
    );
  });
}

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
