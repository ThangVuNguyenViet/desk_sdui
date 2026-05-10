import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/resolve.dart';
import 'package:desk_sdui/src/builtins/builtin_widgets.dart';

void main() {
  late Runtime rt;
  setUp(() {
    rt = Runtime();
    registerBuiltinWidgets(rt);
  });

  Widget resolveOnce(IrNode root, Map<String, Object?> input) {
    return MaterialApp(
      home: Builder(
        builder: (ctx) => resolveNode(ctx, root, input, rt),
      ),
    );
  }

  testWidgets('Column with two Text children', (tester) async {
    const ir = WidgetNode(name: 'Column', args: {
      'children': ListNode([
        WidgetNode(name: 'Text', args: {'data': LiteralNode('a')}),
        WidgetNode(name: 'Text', args: {'data': LiteralNode('b')}),
      ]),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('Padding wraps child', (tester) async {
    const ir = WidgetNode(name: 'Padding', args: {
      'padding': LiteralNode(EdgeInsets.all(8)),
      'child': WidgetNode(name: 'Text', args: {
        'data': LiteralNode('p'),
      },),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('p'), findsOneWidget);
    expect(find.byType(Padding), findsWidgets);
  });

  testWidgets('Container renders with child', (tester) async {
    const ir = WidgetNode(name: 'Container', args: {
      'child': WidgetNode(name: 'Text', args: {
        'data': LiteralNode('c'),
      },),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('SizedBox renders with dimensions', (tester) async {
    const ir = WidgetNode(name: 'SizedBox', args: {
      'width': LiteralNode(100),
      'height': LiteralNode(50),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    final box = tester.widget<SizedBox>(find.byType(SizedBox));
    expect(box.width, 100);
    expect(box.height, 50);
  });

  testWidgets('Row with children', (tester) async {
    const ir = WidgetNode(name: 'Row', args: {
      'children': ListNode([
        WidgetNode(name: 'Text', args: {'data': LiteralNode('r1')}),
        WidgetNode(name: 'Text', args: {'data': LiteralNode('r2')}),
      ]),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('r1'), findsOneWidget);
    expect(find.text('r2'), findsOneWidget);
  });

  testWidgets('Stack with children', (tester) async {
    const ir = WidgetNode(name: 'Stack', args: {
      'children': ListNode([
        WidgetNode(name: 'Text', args: {'data': LiteralNode('s')}),
      ]),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('s'), findsOneWidget);
  });

  testWidgets('Center wraps child', (tester) async {
    const ir = WidgetNode(name: 'Center', args: {
      'child': WidgetNode(name: 'Text', args: {
        'data': LiteralNode('centered'),
      },),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('centered'), findsOneWidget);
  });

  testWidgets('Align wraps child', (tester) async {
    const ir = WidgetNode(name: 'Align', args: {
      'child': WidgetNode(name: 'Text', args: {
        'data': LiteralNode('aligned'),
      },),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('aligned'), findsOneWidget);
  });

  testWidgets('Expanded wraps child', (tester) async {
    const ir = WidgetNode(name: 'Column', args: {
      'children': ListNode([
        WidgetNode(name: 'Expanded', args: {
          'child': WidgetNode(name: 'Text', args: {
            'data': LiteralNode('exp'),
          },),
        },),
      ]),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('exp'), findsOneWidget);
  });

  testWidgets('Flexible wraps child', (tester) async {
    const ir = WidgetNode(name: 'Column', args: {
      'children': ListNode([
        WidgetNode(name: 'Flexible', args: {
          'child': WidgetNode(name: 'Text', args: {
            'data': LiteralNode('flex'),
          },),
        },),
      ]),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('flex'), findsOneWidget);
  });

  testWidgets('InkWell wraps child', (tester) async {
    const ir = WidgetNode(name: 'Material', args: {
      'child': WidgetNode(name: 'InkWell', args: {
        'child': WidgetNode(name: 'Text', args: {
          'data': LiteralNode('tap'),
        },),
      },),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('tap'), findsOneWidget);
  });

  testWidgets('GestureDetector wraps child', (tester) async {
    const ir = WidgetNode(name: 'GestureDetector', args: {
      'child': WidgetNode(name: 'Text', args: {
        'data': LiteralNode('gesture'),
      },),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('gesture'), findsOneWidget);
  });

  testWidgets('ClipRRect wraps child', (tester) async {
    const ir = WidgetNode(name: 'ClipRRect', args: {
      'child': WidgetNode(name: 'Text', args: {
        'data': LiteralNode('clip'),
      },),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('clip'), findsOneWidget);
  });

  testWidgets('Card wraps child', (tester) async {
    const ir = WidgetNode(name: 'Card', args: {
      'child': WidgetNode(name: 'Text', args: {
        'data': LiteralNode('card'),
      },),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('card'), findsOneWidget);
  });

  testWidgets('Divider renders', (tester) async {
    const ir = WidgetNode(name: 'Divider', args: {});
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('Spacer renders', (tester) async {
    const ir = WidgetNode(name: 'Column', args: {
      'children': ListNode([
        WidgetNode(name: 'Spacer', args: {}),
      ]),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.byType(Spacer), findsOneWidget);
  });

  testWidgets('AspectRatio wraps child', (tester) async {
    const ir = WidgetNode(name: 'AspectRatio', args: {
      'aspectRatio': LiteralNode(2.0),
      'child': WidgetNode(name: 'Text', args: {
        'data': LiteralNode('aspect'),
      },),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('aspect'), findsOneWidget);
  });

  testWidgets('Wrap with children', (tester) async {
    const ir = WidgetNode(name: 'Wrap', args: {
      'children': ListNode([
        WidgetNode(name: 'Text', args: {'data': LiteralNode('w1')}),
      ]),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('w1'), findsOneWidget);
  });

  testWidgets('IntrinsicHeight wraps child', (tester) async {
    const ir = WidgetNode(name: 'IntrinsicHeight', args: {
      'child': WidgetNode(name: 'Text', args: {
        'data': LiteralNode('intrinsic'),
      },),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('intrinsic'), findsOneWidget);
  });

  testWidgets('SafeArea wraps child', (tester) async {
    const ir = WidgetNode(name: 'SafeArea', args: {
      'child': WidgetNode(name: 'Text', args: {
        'data': LiteralNode('safe'),
      },),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('safe'), findsOneWidget);
  });

  testWidgets('SingleChildScrollView wraps child', (tester) async {
    const ir = WidgetNode(name: 'SingleChildScrollView', args: {
      'child': WidgetNode(name: 'Text', args: {
        'data': LiteralNode('scroll'),
      },),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('scroll'), findsOneWidget);
  });

  testWidgets('ListView with children', (tester) async {
    const ir = WidgetNode(name: 'ListView', args: {
      'children': ListNode([
        WidgetNode(name: 'Text', args: {'data': LiteralNode('lv')}),
      ]),
    },);
    await tester.pumpWidget(resolveOnce(ir, {}));
    expect(find.text('lv'), findsOneWidget);
  });

  testWidgets('NetworkImage builder registered', (tester) async {
    final builder = rt.widgetFor('NetworkImage');
    expect(builder, isNotNull);
  });

  testWidgets('AssetImage builder registered', (tester) async {
    final builder = rt.widgetFor('AssetImage');
    expect(builder, isNotNull);
  });
}
