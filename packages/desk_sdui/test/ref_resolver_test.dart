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
      // int is not a Map, List, String, or Iterable — resolveRef throws
      // a StateError rather than silently swallowing the bug.
      expect(
        () => resolveRef(['a', 'b'], {'a': 42}),
        throwsA(isA<StateError>()),
      );
    });

    group('String core accessors', () {
      test('isNotEmpty on non-empty string', () {
        expect(resolveRef(['s', 'isNotEmpty'], {'s': 'hello'}), isTrue);
      });

      test('isNotEmpty on empty string', () {
        expect(resolveRef(['s', 'isNotEmpty'], {'s': ''}), isFalse);
      });

      test('isEmpty on empty string', () {
        expect(resolveRef(['s', 'isEmpty'], {'s': ''}), isTrue);
      });

      test('isEmpty on non-empty string', () {
        expect(resolveRef(['s', 'isEmpty'], {'s': 'hi'}), isFalse);
      });

      test('length on string', () {
        expect(resolveRef(['s', 'length'], {'s': 'hi'}), 2);
      });

      test('unknown String accessor returns null gracefully', () {
        expect(resolveRef(['s', 'unknownProp'], {'s': 'hi'}), isNull);
      });
    });

    group('Iterable/List core accessors', () {
      test('isNotEmpty on non-empty list', () {
        expect(resolveRef(['list', 'isNotEmpty'], {'list': [1, 2]}), isTrue);
      });

      test('isNotEmpty on empty list', () {
        expect(resolveRef(['list', 'isNotEmpty'], {'list': []}), isFalse);
      });

      test('isEmpty on empty list', () {
        expect(resolveRef(['list', 'isEmpty'], {'list': []}), isTrue);
      });

      test('length on list', () {
        expect(resolveRef(['list', 'length'], {'list': [1, 2, 3]}), 3);
      });

      test('first on non-empty list', () {
        expect(resolveRef(['list', 'first'], {'list': ['a', 'b']}), 'a');
      });

      test('first on empty list returns null without crash', () {
        expect(resolveRef(['list', 'first'], {'list': []}), isNull);
      });

      test('last on non-empty list', () {
        expect(resolveRef(['list', 'last'], {'list': ['a', 'b']}), 'b');
      });

      test('last on empty list returns null without crash', () {
        expect(resolveRef(['list', 'last'], {'list': []}), isNull);
      });

      test('unknown Iterable accessor returns null gracefully', () {
        expect(resolveRef(['list', 'unknownProp'], {'list': [1, 2]}), isNull);
      });
    });
  });
}
