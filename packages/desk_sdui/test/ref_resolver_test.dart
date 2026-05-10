import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/src/ref_resolver.dart';

void main() {
  group('RefResolver', () {
    test('resolves single segment from map', () {
      expect(resolveRef(['count'], {'count': 7}), 7);
    });

    test('resolves nested map paths', () {
      final input = {
        'data': {'title': 'Hello'},
      };
      expect(resolveRef(['data', 'title'], input), 'Hello');
    });

    test('resolves list index segments', () {
      final input = {
        'data': {
          'items': [
            {'id': 'a'},
            {'id': 'b'},
          ],
        },
      };
      expect(resolveRef(['data', 'items', '0', 'id'], input), 'a');
      expect(resolveRef(['data', 'items', '1', 'id'], input), 'b');
    });

    test('resolves through getter accessors via __getters__ map', () {
      final input = {
        'data': {
          '__getters__': {
            'title': () => 'Computed',
          },
        },
      };
      expect(resolveRef(['data', 'title'], input), 'Computed');
    });

    test('returns null on missing path', () {
      expect(resolveRef(['missing'], {}), isNull);
      expect(resolveRef(['data', 'missing'], {'data': {}}), isNull);
    });

    test('throws on non-indexable mid-path', () {
      expect(
        () => resolveRef(['a', 'b'], {'a': 42}),
        throwsA(isA<StateError>()),
      );
    });
  });
}
