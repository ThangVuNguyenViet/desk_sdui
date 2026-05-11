/// Tests for [collectTypesFromAnnotation] and the [RegistryBuilder] catalog
/// path that handles `@Register([T1, T2, ...])` annotations.
///
/// We use the same resolved-AST fixture pattern as other tests in this package:
/// a temporary Dart file is written into desk_sdui_demo/lib (which has a valid
/// Flutter + package_config context), resolved with `resolveFile`, and then
/// the relevant code paths are exercised directly without running build_runner.
// ignore_for_file: deprecated_member_use
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
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

/// Resolves to `<repo>/packages/desk_sdui_demo` relative to the package root
/// (which is `Directory.current` when running `dart test` in this package).
/// Follows the checkout / worktree automatically.
final String _demoPackageRoot = p.normalize(
  p.join(Directory.current.path, '..', 'desk_sdui_demo'),
);

/// Resolve a Dart source string in the desk_sdui_demo context and return the
/// [ResolvedUnitResult].
Future<ResolvedUnitResult> _resolveSource(String source) async {
  final dir = Directory(p.join(_demoPackageRoot, 'lib'));
  final tempFile = File(
    p.join(
      dir.path,
      '_reg4sdui_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // collectTypesFromAnnotation
  // -------------------------------------------------------------------------

  group('collectTypesFromAnnotation', () {
    test(
      '@Register([PageView]) → PageView in widgets set',
      () async {
        // We need the annotation value as a DartObject, so we resolve a file
        // that contains the annotation and extract it via the analyzer's
        // TypeChecker.
        const source = '''
import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

@Register([PageView])
class _Cov {}
''';

        final result = await _resolveSource(source);
        final libReader = LibraryReader(result.libraryElement);
        final checker = TypeChecker.typeNamed(Register, inPackage: 'desk_sdui_annotation');

        final annotatedList = libReader.annotatedWith(checker).toList();
        expect(annotatedList, hasLength(1), reason: '_Cov must be found');

        final annotated = annotatedList.first;
        final el = annotated.element;
        expect(el, isA<ClassElement>());

        final dartObj = annotated.annotation.objectValue;
        final collected = collectTypesFromAnnotation(el as ClassElement, dartObj);

        expect(
          collected.widgets.map((e) => e.name),
          contains('PageView'),
          reason: 'PageView is a Widget subtype → must appear in widgets',
        );
        expect(
          collected.valueTypes.map((e) => e.name),
          isNot(contains('PageView')),
          reason: 'PageView must not also appear in valueTypes',
        );
      },
    );

    test(
      '@Register([EdgeInsets]) → EdgeInsets in valueTypes set',
      () async {
        const source = '''
import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

@Register([EdgeInsets])
class _Cov {}
''';

        final result = await _resolveSource(source);
        final libReader = LibraryReader(result.libraryElement);
        final checker = TypeChecker.typeNamed(Register, inPackage: 'desk_sdui_annotation');

        final annotated = libReader.annotatedWith(checker).first;
        final el = annotated.element as ClassElement;
        final dartObj = annotated.annotation.objectValue;
        final collected = collectTypesFromAnnotation(el, dartObj);

        expect(
          collected.valueTypes.map((e) => e.name),
          contains('EdgeInsets'),
          reason: 'EdgeInsets is not a Widget → must appear in valueTypes',
        );
        expect(
          collected.widgets.map((e) => e.name),
          isNot(contains('EdgeInsets')),
        );
      },
    );

    test(
      '@Register([PageView, SizedBox]) → both in widgets set',
      () async {
        const source = '''
import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

@Register([PageView, SizedBox])
class _Cov {}
''';

        final result = await _resolveSource(source);
        final libReader = LibraryReader(result.libraryElement);
        final checker = TypeChecker.typeNamed(Register, inPackage: 'desk_sdui_annotation');

        final annotated = libReader.annotatedWith(checker).first;
        final el = annotated.element as ClassElement;
        final dartObj = annotated.annotation.objectValue;
        final collected = collectTypesFromAnnotation(el, dartObj);

        expect(
          collected.widgets.map((e) => e.name),
          containsAll(['PageView', 'SizedBox']),
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // RegistryBuilder emitRegistryForTest with catalogTypes
  // -------------------------------------------------------------------------

  group('RegistryBuilder — catalog registration', () {
    test(
      '@Register([PageView]) → generated output contains rt.registerWidget(\'PageView\')',
      () async {
        const source = '''
import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

@Register([PageView])
class _Cov {}
''';

        final result = await _resolveSource(source);
        final libReader = LibraryReader(result.libraryElement);
        final checker = TypeChecker.typeNamed(Register, inPackage: 'desk_sdui_annotation');

        final annotated = libReader.annotatedWith(checker).first;
        final el = annotated.element as ClassElement;
        final dartObj = annotated.annotation.objectValue;
        final catalogTypes = collectTypesFromAnnotation(el, dartObj);

        final builder = RegistryBuilder();
        final output = builder.emitRegistryForTest(
          screens: [],
          packageName: 'desk_sdui_demo',
          catalogTypes: catalogTypes,
        );

        expect(
          output,
          contains("rt.registerWidget('PageView'"),
          reason: 'PageView must be registered via catalog block',
        );
        expect(
          output,
          contains('registerSduiCatalog(rt)'),
          reason: 'registerSduiCatalog must be called from registerAllScreens',
        );
        expect(
          output,
          contains('void registerSduiCatalog(Runtime rt)'),
          reason: 'registerSduiCatalog function must be emitted',
        );
      },
    );

    test(
      'no @Register → registerSduiCatalog not emitted',
      () {
        final builder = RegistryBuilder();
        final output = builder.emitRegistryForTest(
          screens: [],
          packageName: 'desk_sdui_demo',
        );

        expect(
          output,
          isNot(contains('registerSduiCatalog')),
          reason:
              'No catalog annotation → no registerSduiCatalog in output',
        );
      },
    );

    test(
      'catalog + screen → both screen registrations and catalog block present',
      () async {
        const source = '''
import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

@Register([SizedBox])
class _Cov {}
''';

        final result = await _resolveSource(source);
        final libReader = LibraryReader(result.libraryElement);
        final checker = TypeChecker.typeNamed(Register, inPackage: 'desk_sdui_annotation');

        final annotated = libReader.annotatedWith(checker).first;
        final el = annotated.element as ClassElement;
        final dartObj = annotated.annotation.objectValue;
        final catalogTypes = collectTypesFromAnnotation(el, dartObj);

        final builder = RegistryBuilder();
        final output = builder.emitRegistryForTest(
          screens: [
            ScreenInfoForTest(
              name: 'chef',
              bindingSymbol: 'chefBinding',
              registrationFn: 'registerChefDependencies',
              sourceUri: Uri.parse(
                  'package:desk_sdui_demo/screens/chef.sdui.g.dart'),
            ),
          ],
          packageName: 'desk_sdui_demo',
          catalogTypes: catalogTypes,
        );

        expect(output, contains('rt.registerScreen(chefBinding)'));
        expect(output, contains('registerChefDependencies(rt)'));
        expect(output, contains("rt.registerWidget('SizedBox'"));
        expect(output, contains('registerSduiCatalog(rt)'));
      },
    );
  });

  // -------------------------------------------------------------------------
  // Library-level @Register
  // -------------------------------------------------------------------------

  group('library-level @Register', () {
    test(
      'library-level annotation only — types are picked up',
      () async {
        const source = '''
@Register([PageView])
library;

import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
''';

        final result = await _resolveSource(source);
        final lib = result.libraryElement;
        final checker = TypeChecker.typeNamed(Register, inPackage: 'desk_sdui_annotation');

        final collected = CollectedTypes();
        for (final meta in lib.metadata.annotations) {
          final obj = meta.computeConstantValue();
          if (obj == null) continue;
          if (!checker.isExactlyType(obj.type!)) continue;
          final partial = collectTypesFromAnnotation(lib, obj);
          collected.unionWith(partial);
        }

        expect(
          collected.widgets.map((e) => e.name),
          contains('PageView'),
          reason: 'PageView must be found from library-level annotation',
        );
      },
    );

    test(
      'library-level + class-level coexist — union is registered',
      () async {
        const source = '''
@Register([PageView])
library;

import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

@Register([SizedBox])
class _Catalog {}
''';

        final result = await _resolveSource(source);
        final lib = result.libraryElement;
        final libReader = LibraryReader(lib);
        final checker = TypeChecker.typeNamed(Register, inPackage: 'desk_sdui_annotation');

        final collected = CollectedTypes();

        for (final annotated in libReader.annotatedWith(checker)) {
          final el = annotated.element;
          if (el is! ClassElement) continue;
          final annotation = annotated.annotation.objectValue;
          final partial = collectTypesFromAnnotation(el, annotation);
          collected.unionWith(partial);
        }

        for (final meta in lib.metadata.annotations) {
          final obj = meta.computeConstantValue();
          if (obj == null) continue;
          if (!checker.isExactlyType(obj.type!)) continue;
          final partial = collectTypesFromAnnotation(lib, obj);
          collected.unionWith(partial);
        }

        expect(
          collected.widgets.map((e) => e.name),
          containsAll(['PageView', 'SizedBox']),
          reason: 'Both library-level and class-level types must be present',
        );
      },
    );

    test(
      'collectTypesFromAnnotation accepts Element (library)',
      () async {
        const source = '''
@Register([EdgeInsets])
library;

import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
''';

        final result = await _resolveSource(source);
        final lib = result.libraryElement;
        final checker = TypeChecker.typeNamed(Register, inPackage: 'desk_sdui_annotation');

        CollectedTypes? collected;
        for (final meta in lib.metadata.annotations) {
          final obj = meta.computeConstantValue();
          if (obj == null) continue;
          if (!checker.isExactlyType(obj.type!)) continue;
          collected = collectTypesFromAnnotation(lib, obj);
          break;
        }

        expect(collected, isNotNull);
        expect(
          collected!.valueTypes.map((e) => e.name),
          contains('EdgeInsets'),
          reason: 'EdgeInsets must be found as a value type',
        );
      },
    );
  });
}
