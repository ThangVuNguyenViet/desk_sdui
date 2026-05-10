import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/desk_sdui.dart';

void main() {
  group('InputBinding', () {
    test('stores name and reader', () {
      final binding = InputBinding<int>(
        name: 'count',
        read: (input) => input! as int,
      );
      expect(binding.name, 'count');
      expect(binding.read(42), 42);
    });
  });

  group('Runtime', () {
    test('register and look up widget', () {
      final rt = Runtime();
      rt.registerWidget('Sentinel', (ctx, args) => const SizedBox());
      expect(rt.widgetFor('Sentinel'), isNotNull);
    });

    test('register and look up fn', () {
      final rt = Runtime();
      rt.registerFn('double', (int x) => x * 2);
      final fn = rt.fnFor('double');
      expect(fn, isNotNull);
      expect(Function.apply(fn!, [3]), 6);
    });

    test('register and look up screen', () {
      final rt = Runtime();
      const binding = ScreenBinding(
        name: 'home',
        ir: IrTree(name: 'home', version: 1, root: LiteralNode(null)),
        inputs: [],
      );
      rt.registerScreen(binding);
      expect(rt.screenFor('home')?.name, 'home');
    });

    testWidgets('load falls back to in-binary ScreenBinding', (tester) async {
      final rt = Runtime();
      const binding = ScreenBinding(
        name: 'fallback',
        ir: IrTree(name: 'fallback', version: 1, root: LiteralNode(null)),
        inputs: [],
      );
      rt.registerScreen(binding);
      final tree = await rt.load('fallback');
      expect(tree.name, 'fallback');
    });

    testWidgets('load throws when no source found', (tester) async {
      final rt = Runtime();
      expect(
        () => rt.load('nonexistent'),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('load uses fetcher when available', (tester) async {
      final jsonBytes = utf8.encode(
        r'{"name":"remote","version":1,"root":{"$type":"literal","value":42}}',
      );
      final rt = Runtime(
        fetcher: _FakeFetcher({'remote': jsonBytes}),
      );
      final tree = await rt.load('remote');
      expect(tree.name, 'remote');
      expect(tree.version, 1);
    });

    testWidgets('load caches identical bytes', (tester) async {
      var fetchCount = 0;
      final jsonBytes = utf8.encode(
        r'{"name":"cached","version":1,"root":{"$type":"literal","value":1}}',
      );
      final rt = Runtime(
        fetcher: _FakeFetcher(
          {'cached': jsonBytes},
          onFetch: (_) => fetchCount++,
        ),
      );
      final t1 = await rt.load('cached');
      final t2 = await rt.load('cached');
      expect(identical(t1, t2), isTrue);
      expect(fetchCount, 2, reason: 'fetcher called twice but cache hit');
    });

    testWidgets('load rejects newer IR version', (tester) async {
      final jsonBytes = utf8.encode(
        r'{"name":"future","version":999,"root":{"$type":"literal","value":0}}',
      );
      final rt = Runtime(
        fetcher: _FakeFetcher({'future': jsonBytes}),
      );
      expect(
        () => rt.load('future'),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _FakeFetcher implements IrFetcher {
  _FakeFetcher(this._data, {this.onFetch});
  final Map<String, List<int>> _data;
  final void Function(String)? onFetch;

  @override
  Future<List<int>> fetch(String name) async {
    onFetch?.call(name);
    final bytes = _data[name];
    if (bytes == null) throw StateError('not found: $name');
    return bytes;
  }
}
