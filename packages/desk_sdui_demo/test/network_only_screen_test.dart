import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/resolve.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'network-only @Screen using @RegisterForSdui-only widget renders',
    (tester) async {
      final rt = Runtime()
        // This registration is the exact code emitted by desk_sdui_setup.g.dart's
        // registerSduiCoverage function, generated from @RegisterForSdui([PageView]).
        ..registerWidget(
          'PageView',
          (args) => PageView(
            children: (args['children'] as List?)?.cast<Widget>() ?? const [],
          ),
        )
        ..registerWidget(
          'Text',
          (args) => Text(args['data'] as String? ?? ''),
        );

      const ir = WidgetNode(
        name: 'PageView',
        args: {
          'children': ListNode([
            WidgetNode(name: 'Text', args: {'data': LiteralNode('page1')}),
            WidgetNode(name: 'Text', args: {'data': LiteralNode('page2')}),
          ]),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Builder(
              builder: (ctx) => resolveNode(ctx, ir, const {}, rt),
            ),
          ),
        ),
      );

      expect(find.byType(PageView), findsOneWidget);
    },
  );
}
