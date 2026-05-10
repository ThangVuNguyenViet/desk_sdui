// test/runtime_registration_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/desk_sdui.dart';

void main() {
  test('registerWidget then resolveWidget returns the builder', () {
    final rt = Runtime();
    rt.registerWidget('Padding', (a) => Padding(
      padding: a['padding'] as EdgeInsetsGeometry,
      child: a['child'] as Widget?,
    ));
    final builder = rt.resolveWidget('Padding');
    expect(builder, isNotNull);
    final widget = builder!({'padding': const EdgeInsets.all(8), 'child': null});
    expect(widget, isA<Padding>());
    expect((widget as Padding).padding, const EdgeInsets.all(8));
  });

  test('registerConstant then resolveConstant returns the value', () {
    final rt = Runtime();
    rt.registerConstant('CrossAxisAlignment.start', CrossAxisAlignment.start);
    expect(rt.resolveConstant('CrossAxisAlignment.start'), CrossAxisAlignment.start);
  });

  test('registerMethod then invokeMethod runs the handler', () {
    final rt = Runtime();
    rt.registerMethod('String.toUpperCase', (recv, _) => (recv as String).toUpperCase());
    expect(rt.invokeMethod('String.toUpperCase', 'hello', const []), 'HELLO');
  });

  test('registerSubscript then invokeSubscript runs the handler', () {
    final rt = Runtime();
    rt.registerSubscript('Map.[]', (recv, key) => (recv as Map)[key]);
    expect(rt.invokeSubscript('Map.[]', {'a': 1, 'b': 2}, 'a'), 1);
  });

  test('registerValueBuilder then invokeValueBuilder runs the builder', () {
    final rt = Runtime();
    rt.registerValueBuilder('EdgeInsets.all', (a) => EdgeInsets.all(a[0] as double));
    final result = rt.invokeValueBuilder('EdgeInsets.all', const [8.0]);
    expect(result, const EdgeInsets.all(8.0));
  });

  test('resolveWidget returns null for unregistered name', () {
    final rt = Runtime();
    expect(rt.resolveWidget('NeverRegistered'), isNull);
  });
}
