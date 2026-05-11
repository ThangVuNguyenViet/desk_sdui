/// Tests for the registration diagnostic: the registry builder must detect
/// when a `@Screen` body references a widget type that is NOT listed in any
/// `@RegisterForSdui` annotation.
///
/// These tests exercise the diagnostic logic directly using the resolved-AST
/// fixture pattern (resolveFile into desk_sdui_demo/lib) so that Flutter types
/// are resolvable without running build_runner.
// ignore_for_file: deprecated_member_use
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:desk_sdui_generator/src/registry/registry_generator.dart';
import 'package:desk_sdui_generator/src/type_collector.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

// ---------------------------------------------------------------------------
// Shared setup
// ---------------------------------------------------------------------------

const _demoPackageRoot =
    // ignore: lines_longer_than_80_chars
    '/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/packages/desk_sdui_demo';

/// Resolve a Dart source string in the desk_sdui_demo context and return the
/// [ResolvedUnitResult].
Future<ResolvedUnitResult> _resolveSource(String source) async {
  final dir = Directory(p.join(_demoPackageRoot, 'lib'));
  final tempFile = File(
    p.join(
      dir.path,
      '_diag_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
    ),
  );
  tempFile.writeAsStringSync(source);
  try {
    final result = await resolveFile(path: tempFile.path);
    if (result is! ResolvedUnitResult) {
      throw StateError('resolveFile returned ${result.runtimeType}');
    }
    return result;
  } finally {
    if (tempFile.existsSync()) tempFile.deleteSync();
  }
}

/// Extract the first [FunctionDeclaration] from a resolved unit.
FunctionDeclaration _firstFn(ResolvedUnitResult result) {
  return result.unit.declarations.whereType<FunctionDeclaration>().first;
}

/// Collect widget names from a `@RegisterForSdui([...])` annotation in a
/// resolved source string.
Future<Set<String>> _registeredWidgetNames(String source) async {
  final result = await _resolveSource(source);
  final libReader = LibraryReader(result.libraryElement);
  const checker =
      TypeChecker.typeNamed(RegisterForSdui, inPackage: 'desk_sdui_annotation');
  final collected = CollectedTypes();
  for (final annotated in libReader.annotatedWith(checker)) {
    final el = annotated.element;
    if (el is! ClassElement) continue;
    final dartObj = annotated.annotation.objectValue;
    final partial = collectTypesFromAnnotation(el, dartObj);
    collected.unionWith(partial);
  }
  return collected.widgets.map((e) => e.name).whereType<String>().toSet();
}

// ---------------------------------------------------------------------------
// Helpers that mirror the diagnostic logic in RegistryBuilder.build()
// ---------------------------------------------------------------------------

/// Compute missing widget names: `referenced \ registered`.
Set<String> _missingWidgets({
  required Set<String> referenced,
  required Set<String> registered,
}) {
  return referenced.difference(registered);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Diagnostic logic: missing-widget detection
  // -------------------------------------------------------------------------

  group('registration diagnostic — missing widget detection', () {
    test(
      '@Screen referencing Stack with no @RegisterForSdui → Stack reported as missing',
      () async {
        // Screen source: references Stack but no @RegisterForSdui covers it.
        const screenSource = '''
import 'package:flutter/material.dart';

Widget buildTest() => Stack(children: [Text('hi')]);
''';
        const catalogSource = '''
import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

// No Stack in this list
@RegisterForSdui([SizedBox])
class _Cov {}
''';

        final screenResult = await _resolveSource(screenSource);
        final fnDecl = _firstFn(screenResult);
        final referencedWidgetNames = collectTypes(fnDecl)
            .widgets
            .map((e) => e.name)
            .whereType<String>()
            .toSet();

        final registered = await _registeredWidgetNames(catalogSource);
        final missing = _missingWidgets(
          referenced: referencedWidgetNames,
          registered: registered,
        );

        expect(
          missing,
          contains('Stack'),
          reason: 'Stack is referenced but not registered → must appear in missing set',
        );
      },
    );

    test(
      '@Screen referencing Stack with @RegisterForSdui([Stack]) → no missing widgets',
      () async {
        const screenSource = '''
import 'package:flutter/material.dart';

Widget buildTest() => Stack(children: [Text('hi')]);
''';
        const catalogSource = '''
import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

@RegisterForSdui([Stack, Text])
class _Cov {}
''';

        final screenResult = await _resolveSource(screenSource);
        final fnDecl = _firstFn(screenResult);
        final referencedWidgetNames = collectTypes(fnDecl)
            .widgets
            .map((e) => e.name)
            .whereType<String>()
            .toSet();

        final registered = await _registeredWidgetNames(catalogSource);
        final missing = _missingWidgets(
          referenced: referencedWidgetNames,
          registered: registered,
        );

        expect(
          missing,
          isEmpty,
          reason: 'Stack and Text are registered → no missing widgets',
        );
      },
    );

    test(
      '@RegisterForSdui with top-level const reference is resolved correctly',
      () async {
        // The key Task-1 verification: const references compose for free
        // because collectTypesFromAnnotation uses DartObject.toListValue().
        // The spread `[...kCommon]` resolves to the same flat DartObject list
        // as an inline literal; we test the const-reference chain here.
        const catalogSource = '''
import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

const _top = <Type>[Column, Row];

@RegisterForSdui(_top)
class _Cov {}
''';

        final registered = await _registeredWidgetNames(catalogSource);

        expect(
          registered,
          containsAll(['Column', 'Row']),
          reason: 'const reference _top must resolve to its element list',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // emitRegistryForTest: no impact from diagnostic-only change
  // -------------------------------------------------------------------------

  group('RegistryBuilder — emitRegistryForTest unchanged', () {
    test('no @RegisterForSdui → no registerSduiCatalog emitted', () {
      final output = RegistryBuilder().emitRegistryForTest(
        screens: [],
        packageName: 'desk_sdui_demo',
      );
      expect(output, isNot(contains('registerSduiCatalog')));
    });

    test('screen with @RegisterForSdui([Stack]) → Stack registered', () async {
      const catalogSource = '''
import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

@RegisterForSdui([Stack])
class _Cov {}
''';

      final result = await _resolveSource(catalogSource);
      final libReader = LibraryReader(result.libraryElement);
      const checker =
          TypeChecker.typeNamed(RegisterForSdui, inPackage: 'desk_sdui_annotation');
      final catalogTypes = CollectedTypes();
      for (final annotated in libReader.annotatedWith(checker)) {
        final el = annotated.element;
        if (el is! ClassElement) continue;
        final dartObj = annotated.annotation.objectValue;
        catalogTypes.unionWith(collectTypesFromAnnotation(el, dartObj));
      }

      final output = RegistryBuilder().emitRegistryForTest(
        screens: [],
        packageName: 'desk_sdui_demo',
        catalogTypes: catalogTypes,
      );

      expect(output, contains("rt.registerWidget('Stack'"));
    });
  });
}
