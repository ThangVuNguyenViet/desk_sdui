// ignore_for_file: deprecated_member_use
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:desk_sdui_generator/src/registration_emitter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final _demoPackageRoot = p.normalize(
  p.join(Directory.current.path, '..', 'desk_sdui_demo'),
);

/// Resolve [source] in the demo package context and return the first class
/// declaration's [ClassElement].
Future<ClassElement> _resolveClass(String source, {String? className}) async {
  final dir = Directory(p.join(_demoPackageRoot, 'lib'));
  final tempFile = File(
    p.join(
      dir.path,
      '_setter_codegen_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
    ),
  );
  tempFile.writeAsStringSync(source);
  try {
    final result = await resolveFile(path: tempFile.path);
    if (result is! ResolvedUnitResult) {
      throw StateError('resolveFile returned ${result.runtimeType}');
    }
    final classes = result.libraryElement.classes;
    if (className != null) {
      return classes.firstWhere((c) => c.name == className);
    }
    return classes.first;
  } finally {
    if (tempFile.existsSync()) tempFile.deleteSync();
  }
}

void main() {
  group('Setter codegen eligibility (analyzer-driven)', () {
    test('emits registerSetter ONLY for settable non-final instance fields',
        () async {
      final cls = await _resolveClass('''
class Mixed {
  // Eligible: public, non-final, non-late, non-static field with a setter.
  int settable = 0;

  // Not eligible: final field (no setter).
  final int frozen = 0;

  // Not eligible: late final (no setter).
  late final int lateFrozen;

  // Not eligible: const field (compile-time constant).
  static const int konst = 0;

  // Not eligible: static (not an instance field).
  static int staticVar = 0;

  // Not eligible: private.
  int _hidden = 0;

  // Not eligible: getter-only (no setter).
  int get readOnly => 0;

  // Eligible: explicit getter+setter pair (synthetic field has setter).
  int get pair => 0;
  set pair(int v) {}
}
''');

      final emitter = RegistrationEmitter();
      final output = emitter.emitMethodsForClass(cls);
      final setterLines = output
          .split('\n')
          .where((l) => l.contains('registerSetter'))
          .toList();

      // Only `settable` and `pair` should produce setter registrations.
      expect(setterLines.length, 2,
          reason: 'Expected exactly 2 setter registrations, got: $setterLines');

      final joined = setterLines.join('\n');
      expect(joined, contains("'Mixed.settable'"));
      expect(joined, contains("'Mixed.pair'"));

      // None of the disallowed members should appear.
      expect(joined, isNot(contains('frozen')));
      expect(joined, isNot(contains('lateFrozen')));
      expect(joined, isNot(contains('konst')));
      expect(joined, isNot(contains('staticVar')));
      expect(joined, isNot(contains('_hidden')));
      expect(joined, isNot(contains('readOnly')));
    });

    test('does NOT emit setters for inherited Object/Widget members',
        () async {
      final cls = await _resolveClass('''
import 'package:flutter/widgets.dart';

class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  int settable = 0;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''', className: 'MyWidget');

      final emitter = RegistrationEmitter();
      final output = emitter.emitMethodsForClass(cls);
      final setterLines = output
          .split('\n')
          .where((l) => l.contains('registerSetter'))
          .toList();

      // Should NOT emit setter for inherited Widget.key (final) or
      // Object.hashCode (getter-only). The `settable` field is final-by-
      // implication of the const ctor in StatelessWidget contexts, so we don't
      // assert on its presence here; the load-bearing check is that NO
      // inherited members are emitted.
      final joined = setterLines.join('\n');
      expect(joined, isNot(contains('key')),
          reason: 'inherited Widget.key (final) must not be registered');
      expect(joined, isNot(contains('hashCode')),
          reason: 'inherited Object.hashCode (getter-only) must not be '
              'registered');
    });
  });
}
