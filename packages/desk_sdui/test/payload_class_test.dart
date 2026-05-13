import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/src/payload_class.dart';
import 'package:desk_sdui/src/runtime.dart';
import 'package:desk_sdui/src/cell.dart';

void main() {
  group('PayloadClass registry', () {
    // Reset the global registry before each test
    setUp(() {
      clearPayloadClassesForTest();
    });

    test('registerPayloadClass adds entry to payloadClasses', () {
      final order = PayloadClass(name: 'Order');
      registerPayloadClass(order);
      expect(payloadClasses['Order'], same(order));
    });

    test('registerPayloadClass with duplicate name throws StateError', () {
      final order1 = PayloadClass(name: 'Order');
      final order2 = PayloadClass(name: 'Order');
      registerPayloadClass(order1);
      expect(
        () => registerPayloadClass(order2),
        throwsA(isA<StateError>()),
      );
    });

    test('methodLookupOrder for simple class is [self]', () {
      final simple = PayloadClass(name: 'Simple');
      registerPayloadClass(simple);
      expect(simple.methodLookupOrder, [simple]);
    });

    test('methodLookupOrder with mixins is [self, M2, M1] (reversed order)', () {
      final m1 = PayloadClass(name: 'M1');
      final m2 = PayloadClass(name: 'M2');
      registerPayloadClass(m1);
      registerPayloadClass(m2);

      final clsWithMixins = PayloadClass(
        name: 'WithMixins',
        mixins: [m1, m2],
      );
      registerPayloadClass(clsWithMixins);

      expect(clsWithMixins.methodLookupOrder, [clsWithMixins, m2, m1]);
    });

    test('methodLookupOrder with supertype includes supertype mro', () {
      final parent = PayloadClass(name: 'Parent');
      registerPayloadClass(parent);

      final child = PayloadClass(
        name: 'Child',
        supertype: parent,
      );
      registerPayloadClass(child);

      expect(child.methodLookupOrder, [child, parent]);
    });

    test('PayloadInstance toString includes class name and field values', () {
      final klass = PayloadClass(name: 'Person');
      registerPayloadClass(klass);

      final instance = PayloadInstance(
        type: klass,
        fields: {
          'name': Cell('Alice'),
          'age': Cell(30),
        },
      );

      final str = instance.toString();
      expect(str, contains('Person'));
      expect(str, contains('name'));
      expect(str, contains('Alice'));
      expect(str, contains('age'));
      expect(str, contains('30'));
    });

    test('registering child before supertype throws StateError', () {
      final parent = PayloadClass(name: 'Parent');
      final child = PayloadClass(name: 'Child', supertype: parent);
      expect(() => registerPayloadClass(child), throwsA(isA<StateError>()));
    });

    test('registering class with unregistered mixin throws StateError', () {
      final m = PayloadClass(name: 'M');
      final cls = PayloadClass(name: 'C', mixins: [m]);
      expect(() => registerPayloadClass(cls), throwsA(isA<StateError>()));
    });
  });
}
