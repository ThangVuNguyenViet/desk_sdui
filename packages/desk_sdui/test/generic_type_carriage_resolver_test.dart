import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/resolve.dart';

void main() {
  group('Resolver — __typeArgs__ injection', () {
    late Runtime rt;

    setUp(() {
      rt = Runtime();
    });

    testWidgets('ValueCtorNode with typeArgs passes __typeArgs__ to builder',
        (tester) async {
      List<String>? capturedTypeArgs;

      rt.registerValueBuilder('MyList', (args) {
        capturedTypeArgs = args['__typeArgs__'] as List<String>?;
        return <Object?>[];
      });

      // A simple widget that reads the value-ctor result.
      rt.registerWidgetWithContext('Sentinel', (ctx, args) {
        return const SizedBox.shrink();
      });

      const ir = WidgetNode(
        name: 'Sentinel',
        args: {
          'items': ValueCtorNode(
            name: 'MyList',
            args: [],
            typeArgs: ['MyItem'],
          ),
        },
      );

      await tester.pumpWidget(
        Builder(builder: (ctx) => resolveNode(ctx, ir, {}, rt)),
      );

      expect(capturedTypeArgs, equals(['MyItem']));
    });

    testWidgets('ValueCtorNode without typeArgs → builder receives no __typeArgs__',
        (tester) async {
      var called = false;
      List<String>? capturedTypeArgs;

      rt.registerValueBuilder('MyList', (args) {
        called = true;
        capturedTypeArgs = args['__typeArgs__'] as List<String>?;
        return <Object?>[];
      });

      rt.registerWidgetWithContext('Sentinel', (ctx, args) {
        return const SizedBox.shrink();
      });

      const ir = WidgetNode(
        name: 'Sentinel',
        args: {
          'items': ValueCtorNode(name: 'MyList', args: []),
        },
      );

      await tester.pumpWidget(
        Builder(builder: (ctx) => resolveNode(ctx, ir, {}, rt)),
      );

      expect(called, isTrue);
      expect(capturedTypeArgs, isNull);
    });
  });
}
