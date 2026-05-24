import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/resolve.dart';

void main() {
  testWidgets(
    'WidgetNode.listenablePaths rebuilds only its subtree on state change',
    (tester) async {
      final rt = Runtime();
      var outerBuilds = 0;
      var innerBuilds = 0;
      rt.registerWidgetWithContext('Outer', (ctx, args) {
        outerBuilds++;
        return Column(
          children: (args['children']! as List).cast<Widget>(),
        );
      });
      rt.registerWidgetWithContext('Inner', (ctx, args) {
        innerBuilds++;
        return Text(
          args['label'].toString(),
          textDirection: TextDirection.ltr,
        );
      });

      final notifier = ValueNotifier<int>(0);
      final input = <String, Object?>{
        '__reactive__': {'count': notifier},
      };

      const ir = WidgetNode(
        name: 'Outer',
        args: {
          'children': ListNode([
            WidgetNode(
              name: 'Inner',
              listenablePaths: {'count'},
              args: {
                'label': RefNode(['count'], reactive: true),
              },
            ),
          ]),
        },
      );

      await tester.pumpWidget(Builder(builder: (ctx) {
        return resolveNode(ctx, ir, input, rt);
      },),);

      expect(outerBuilds, 1);
      expect(innerBuilds, 1);
      expect(find.text('0'), findsOneWidget);

      notifier.value = 1;
      await tester.pump();

      expect(outerBuilds, 1, reason: 'outer should not rebuild');
      expect(innerBuilds, 2, reason: 'inner rebuilt by ListenableBuilder');
      expect(find.text('1'), findsOneWidget);
    },
  );
}
