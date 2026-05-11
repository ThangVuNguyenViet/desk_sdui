import 'dart:convert';

import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/resolve.dart';
import 'package:desk_sdui_demo/desk_sdui_setup.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'network-only @Screen using @Register-only widget renders',
    (tester) async {
      final payload = jsonEncode({
        r'$type': 'widget',
        'name': 'PageView',
        'args': {
          'children': {
            r'$type': 'list',
            'children': [
              {
                r'$type': 'widget',
                'name': 'Text',
                'args': {
                  'data': {r'$type': 'literal', 'value': 'page1'},
                },
              },
              {
                r'$type': 'widget',
                'name': 'Text',
                'args': {
                  'data': {r'$type': 'literal', 'value': 'page2'},
                },
              },
            ],
          },
        },
      });

      final rt = Runtime();
      registerAllScreens(rt);

      final ir = const JsonIrCodec().decode(
        jsonDecode(payload) as Map<String, Object?>,
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
