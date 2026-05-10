import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:test/test.dart';

void main() {
  group('Screen', () {
    test('stores the name', () {
      const annotation = Screen('cart');
      expect(annotation.name, 'cart');
    });

    test('two annotations with same name are equal', () {
      expect(const Screen('home'), const Screen('home'));
      expect(const Screen('home').hashCode, const Screen('home').hashCode);
    });

    test('two annotations with different names are not equal', () {
      expect(const Screen('a') == const Screen('b'), isFalse);
    });

    test('toString includes the name', () {
      expect(const Screen('cart').toString(), contains('cart'));
    });
  });
}
