import 'dart:io';

import 'package:desk_sdui_generator/src/compile_to_ir.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Absolute path to the desk_sdui_demo package root.
///
/// We use this as the analysis context root so that `package:flutter/...`
/// can be resolved (the generator package itself is not a Flutter project).
final _demoPackageRoot = p.normalize(
  p.join(
    Directory.current.path,
    '..',
    'desk_sdui_demo',
  ),
);

void main() {
  group('compileToIr', () {
    test('compiles a simple Text screen with catalog', () async {
      final result = await compileToIrForTest(
        packageRoot: _demoPackageRoot,
        screenSource: '''
@Screen('hello')
Widget hello() => Text('hi');
''',
        catalogSource: '''
@Register([Text])
class _Catalog {}
''',
      );

      expect(result, isA<CompileSuccess>());
      final success = result as CompileSuccess;
      expect(success.ir['name'], 'hello');
      expect(success.ir['version'], 1);
      expect(success.ir['root'], isA<Map<String, Object?>>());
    });

    test('fails for unregistered widget', () async {
      final result = await compileToIrForTest(
        packageRoot: _demoPackageRoot,
        screenSource: '''
@Screen('hello')
Widget hello() => Text('hi');
''',
        // No catalog -> Text is unregistered
      );

      expect(result, isA<CompileFailure>());
      final failure = result as CompileFailure;
      expect(failure.errors, isNotEmpty);
      expect(
        failure.errors.first.message,
        contains('unregistered widget'),
      );
    });

    test('fails for analyzer error', () async {
      final result = await compileToIrForTest(
        packageRoot: _demoPackageRoot,
        screenSource: '''
@Screen('hello')
Widget hello() => UnknownWidget('hi');
''',
      );

      expect(result, isA<CompileFailure>());
      final failure = result as CompileFailure;
      expect(failure.errors, isNotEmpty);
    });

    test('produces IR byte-identical to build_runner golden', () async {
      final result = await compileToIrForTest(
        packageRoot: _demoPackageRoot,
        dataModelSource: '''
class CounterData {
  const CounterData({required this.value, this.chips = const []});
  final int value;
  final List<int> chips;
}
''',
        catalogSource: '''
@Register([Center, Text])
class _Catalog {}
''',
        screenSource: '''
@Screen('counter_minimal')
Widget counterMinimal(CounterData data) => Center(
      child: Text(
        '\${data.value}',
        style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w800),
      ),
    );
''',
      );

      expect(result, isA<CompileSuccess>());
      final success = result as CompileSuccess;

      // Golden produced by build_runner on the same source.
      const golden = <String, Object?>{
        'name': 'counter_minimal',
        'version': 1,
        'root': <String, Object?>{
          r'$type': 'widget',
          'name': 'Center',
          'args': <String, Object?>{
            'child': <String, Object?>{
              r'$type': 'widget',
              'name': 'Text',
              'args': <String, Object?>{
                'data': <String, Object?>{
                  r'$type': 'interp',
                  'parts': <Object?>[
                    <String, Object?>{
                      r'$type': 'ref',
                      'path': <Object?>['data', 'value'],
                    },
                  ],
                },
                'style': <String, Object?>{
                  r'$type': 'widget',
                  'name': 'TextStyle',
                  'args': <String, Object?>{
                    'fontSize': <String, Object?>{
                      r'$type': 'literal',
                      'value': 96,
                    },
                    'fontWeight': <String, Object?>{
                      r'$type': 'ref',
                      'path': <Object?>['FontWeight', 'w800'],
                    },
                  },
                },
              },
            },
          },
        },
      };

      expect(success.ir, equals(golden));
    });
  });
}
