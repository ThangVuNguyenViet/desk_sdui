import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/resolve.dart';

void main() {
  late Runtime rt;

  setUp(() {
    rt = Runtime();
    rt.registerWidget('Sentinel', (ctx, args) {
      return Text(
        args['label'] as String? ?? '',
        textDirection: TextDirection.ltr,
      );
    });
    rt.registerWidget('Container', (ctx, args) {
      return Container(child: args['child'] as Widget?);
    });
    rt.registerWidget('Column', (ctx, args) {
      return Column(
        children: (args['children'] as List).cast<Widget>(),
      );
    });
  });

  Widget resolveOnce(IrNode root, Map<String, Object?> input) {
    return Builder(
      builder: (ctx) => resolveNode(ctx, root, input, rt),
    );
  }

  testWidgets('WidgetNode looks up registered builder', (tester) async {
    final ir = WidgetNode(name: 'Sentinel', args: {
      'label': const LiteralNode('hi'),
    });
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('hi'), findsOneWidget);
  });

  testWidgets('WidgetNode resolves RefNode args', (tester) async {
    final ir = WidgetNode(name: 'Sentinel', args: {
      'label': const RefNode(['greeting']),
    });
    await tester.pumpWidget(resolveOnce(ir, {'greeting': 'hello'}));
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('ListNode of WidgetNodes resolves to List<Widget>',
      (tester) async {
    final ir = WidgetNode(name: 'Column', args: {
      'children': ListNode([
        WidgetNode(name: 'Sentinel', args: {
          'label': const LiteralNode('a'),
        }),
        WidgetNode(name: 'Sentinel', args: {
          'label': const LiteralNode('b'),
        }),
      ]),
    });
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('ConditionalNode picks then-branch when condition true',
      (tester) async {
    final ir = ConditionalNode(
      condition: const LiteralNode(true),
      thenBranch: WidgetNode(name: 'Sentinel', args: {
        'label': const LiteralNode('y'),
      }),
      elseBranch: WidgetNode(name: 'Sentinel', args: {
        'label': const LiteralNode('n'),
      }),
    );
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('y'), findsOneWidget);
    expect(find.text('n'), findsNothing);
  });

  testWidgets('ConditionalNode without else returns SizedBox.shrink',
      (tester) async {
    final ir = WidgetNode(name: 'Column', args: {
      'children': ListNode([
        ConditionalNode(
          condition: const LiteralNode(false),
          thenBranch: WidgetNode(name: 'Sentinel', args: {
            'label': const LiteralNode('x'),
          }),
        ),
      ]),
    });
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('x'), findsNothing);
  });

  testWidgets('ForNode iterates and resolves body', (tester) async {
    final ir = WidgetNode(name: 'Column', args: {
      'children': ForNode(
        variable: 'item',
        source: const RefNode(['xs']),
        body: WidgetNode(name: 'Sentinel', args: {
          'label': const RefNode(['item']),
        }),
      ),
    });
    await tester.pumpWidget(resolveOnce(ir, {'xs': ['a', 'b', 'c']}));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('ForNode destructured iterates with indexed pair',
      (tester) async {
    final ir = WidgetNode(name: 'Column', args: {
      'children': ForNode.destructured(
        variables: ['i', 'x'],
        source: const RefNode(['xs']),
        body: WidgetNode(name: 'Sentinel', args: {
          'label': StringInterpNode([
            const RefNode(['i']),
            ':',
            const RefNode(['x']),
          ]),
        }),
      ),
    });
    await tester.pumpWidget(resolveOnce(ir, {
      'xs': [
        {'first': 0, 'second': 'a'},
        {'first': 1, 'second': 'b'},
      ],
    }));
    expect(find.text('0:a'), findsOneWidget);
    expect(find.text('1:b'), findsOneWidget);
  });

  testWidgets('SpreadNode flattens into surrounding list', (tester) async {
    final ir = WidgetNode(name: 'Column', args: {
      'children': ListNode([
        WidgetNode(name: 'Sentinel', args: {
          'label': const LiteralNode('head'),
        }),
        SpreadNode(ListNode([
          WidgetNode(name: 'Sentinel', args: {
            'label': const LiteralNode('m1'),
          }),
          WidgetNode(name: 'Sentinel', args: {
            'label': const LiteralNode('m2'),
          }),
        ])),
        WidgetNode(name: 'Sentinel', args: {
          'label': const LiteralNode('tail'),
        }),
      ]),
    });
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('head'), findsOneWidget);
    expect(find.text('m1'), findsOneWidget);
    expect(find.text('m2'), findsOneWidget);
    expect(find.text('tail'), findsOneWidget);
  });

  testWidgets('Unregistered widget throws useful error', (tester) async {
    final ir = WidgetNode(name: 'NotRegistered', args: {});
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        try {
          return resolveNode(ctx, ir, {}, rt);
        } catch (e) {
          return Text(
            'caught:${e.runtimeType}',
            textDirection: TextDirection.ltr,
          );
        }
      }),
    ));
    expect(find.textContaining('caught:'), findsOneWidget);
  });
}
