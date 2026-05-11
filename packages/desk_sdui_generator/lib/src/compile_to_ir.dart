// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

import 'diagnostics.dart';
import 'screen_lowering/screen_generator.dart';
import 'type_collector.dart' show collectTypes, collectTypesFromAnnotation, CollectedTypes;

/// Result of compiling a screen source string to IR.
sealed class CompileResult {
  const CompileResult();
}

/// Successful compilation producing the IR tree as a JSON-compatible map.
class CompileSuccess extends CompileResult {
  const CompileSuccess({required this.ir});

  /// The IR tree: `{'name': String, 'version': int, 'root': Map}`.
  final Map<String, Object?> ir;
}

/// Compilation failed; [errors] describes what went wrong.
class CompileFailure extends CompileResult {
  const CompileFailure({required this.errors});

  final List<CompileError> errors;
}

/// A single structured error from the compiler.
class CompileError {
  const CompileError({required this.message, this.screenName});

  final String message;
  final String? screenName;

  @override
  String toString() => screenName != null ? '[$screenName] $message' : message;
}

/// Compiles [screenSource] (and optional [dataModelSource] / [catalogSource])
/// to the JSON IR representation used by the SDUI runtime.
///
/// The source strings should be valid Dart code. Common Flutter / annotation
/// imports are added automatically, so minimal snippets work:
///
/// ```dart
/// final result = await compileToIr(
///   screenSource: '@Screen("hello") Widget hello() => Text("hi");',
/// );
/// ```
///
/// Returns [CompileSuccess] with the IR map, or [CompileFailure] with
/// structured errors (analyzer diagnostics, lowering errors, or missing
/// widget registrations).
Future<CompileResult> compileToIr({
  required String screenSource,
  String? dataModelSource,
  String? catalogSource,
}) async {
  final packageConfigUri = await Isolate.packageConfig;
  if (packageConfigUri == null) {
    return const CompileFailure(
      errors: [CompileError(message: 'Could not determine package config')],
    );
  }

  final packageConfigPath = p.fromUri(packageConfigUri);
  final rootDir = p.dirname(p.dirname(packageConfigPath));

  return _compileToIr(
    screenSource: screenSource,
    dataModelSource: dataModelSource,
    catalogSource: catalogSource,
    rootDir: rootDir,
  );
}

/// Test-only entry point that lets callers specify the package root directly.
///
/// Use this when [compileToIr] is invoked from a package that does not itself
/// depend on Flutter (e.g. the generator's own unit tests). Pass the path to
/// a Flutter package that can resolve `package:flutter/material.dart`.
@visibleForTesting
Future<CompileResult> compileToIrForTest({
  required String screenSource,
  String? dataModelSource,
  String? catalogSource,
  required String packageRoot,
}) {
  return _compileToIr(
    screenSource: screenSource,
    dataModelSource: dataModelSource,
    catalogSource: catalogSource,
    rootDir: packageRoot,
  );
}

Future<CompileResult> _compileToIr({
  required String screenSource,
  String? dataModelSource,
  String? catalogSource,
  required String rootDir,
}) async {
  final physicalProvider = PhysicalResourceProvider.INSTANCE;
  final overlayProvider = OverlayResourceProvider(physicalProvider);

  final syntheticPath = p.join(rootDir, 'lib', '_synthetic_compile.dart');

  final buffer = StringBuffer();
  buffer.writeln('// ignore_for_file: duplicate_import');
  buffer.writeln("import 'package:flutter/material.dart';");
  buffer.writeln(
    "import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';",
  );
  buffer.writeln("import 'package:desk_sdui/desk_sdui.dart';");
  if (dataModelSource != null) buffer.writeln(dataModelSource);
  if (catalogSource != null) buffer.writeln(catalogSource);
  buffer.writeln(screenSource);

  overlayProvider.setOverlay(
    syntheticPath,
    content: buffer.toString(),
    modificationStamp: 1,
  );

  final collection = AnalysisContextCollection(
    includedPaths: [rootDir],
    resourceProvider: overlayProvider,
  );

  final context = collection.contexts.first;
  final resolvedUnit = await context.currentSession.getResolvedUnit(
    syntheticPath,
  );

  if (resolvedUnit is! ResolvedUnitResult) {
    return const CompileFailure(
      errors: [CompileError(message: 'Failed to resolve synthetic unit')],
    );
  }

  // Surface analyzer errors first.
  final analyzerErrors = resolvedUnit.errors
      .where((e) => e.diagnosticCode.errorSeverity == DiagnosticSeverity.ERROR)
      .toList();
  if (analyzerErrors.isNotEmpty) {
    return CompileFailure(
      errors: analyzerErrors
          .map(
            (e) => CompileError(
              message: '${e.message} (${e.source.fullName})',
            ),
          )
          .toList(),
    );
  }

  final unit = resolvedUnit.unit;
  final lib = resolvedUnit.libraryElement;

  final screenChecker = TypeChecker.typeNamed(
    Screen,
    inPackage: 'desk_sdui_annotation',
  );
  final catalogChecker = TypeChecker.typeNamed(
    Register,
    inPackage: 'desk_sdui_annotation',
  );
  final libReader = LibraryReader(lib);

  final annotatedElements = libReader.annotatedWith(screenChecker).toList();
  if (annotatedElements.isEmpty) {
    return const CompileFailure(
      errors: [CompileError(message: 'No @Screen annotation found in source')],
    );
  }

  final annotated = annotatedElements.first;
  final element = annotated.element;
  final annotation = annotated.annotation;

  // Resolve library for the element so static types are available.
  ResolvedLibraryResult? resolvedLibResult;
  if (element is TopLevelFunctionElement) {
    final session = element.session;
    if (session != null) {
      final result = await session.getResolvedLibraryByElement(element.library);
      if (result is ResolvedLibraryResult) {
        resolvedLibResult = result;
      }
    }
  }

  // Find function declaration in the unit.
  final funcName = element.name as String;
  FunctionDeclaration? fnDecl;
  for (final decl in unit.declarations) {
    if (decl is FunctionDeclaration && decl.name.lexeme == funcName) {
      fnDecl = decl;
      break;
    }
  }

  final screenName = annotation.read('name').stringValue;

  if (fnDecl == null) {
    return CompileFailure(
      errors: [
        CompileError(
          message: 'Could not find function declaration for $funcName',
          screenName: screenName,
        ),
      ],
    );
  }

  // Resolve the function declaration for accurate type collection.
  FunctionDeclaration? resolvedFnDecl;
  if (element is TopLevelFunctionElement && resolvedLibResult != null) {
    final declResult = resolvedLibResult.getFragmentDeclaration(element.firstFragment);
    resolvedFnDecl = declResult?.node as FunctionDeclaration?;
  }

  try {
    final outputs = lowerScreenElement(
      element: element,
      annotation: annotation,
      unit: unit,
      resolvedLibResult: resolvedLibResult,
      partOfUri: 'file://$syntheticPath',
    );

    // Decode the JSON bytes back to a map so the caller gets structured data.
    final irMap =
        jsonDecode(utf8.decode(outputs.jsonBytes)) as Map<String, Object?>;

    // Collect catalog types from @Register annotations in the synthetic file.
    final catalogTypes = CollectedTypes();
    for (final annotated in libReader.annotatedWith(catalogChecker)) {
      final el = annotated.element;
      if (el is! ClassElement) continue;
      final annotationValue = annotated.annotation.objectValue;
      final partial = collectTypesFromAnnotation(el, annotationValue);
      catalogTypes.unionWith(partial);
    }

    // Library-level @Register annotations.
    for (final meta in lib.metadata.annotations) {
      final obj = meta.computeConstantValue();
      if (obj == null) continue;
      if (!catalogChecker.isExactlyType(obj.type!)) continue;
      final partial = collectTypesFromAnnotation(lib, obj);
      catalogTypes.unionWith(partial);
    }

    final registeredWidgetNames = catalogTypes.widgets
        .map((e) => e.name)
        .whereType<String>()
        .toSet();

    // Use collectTypes (same as RegistryBuilder) to determine referenced
    // widgets, because lowerScreen's widgetRefs includes non-Widget
    // constructors like TextStyle that the diagnostic should ignore.
    final collected = collectTypes(resolvedFnDecl ?? fnDecl);
    final referencedWidgetNames = collected.widgets
        .map((e) => e.name)
        .whereType<String>()
        .toSet();

    final missing = referencedWidgetNames.difference(registeredWidgetNames);
    if (missing.isNotEmpty) {
      return CompileFailure(
        errors: missing
            .map(
              (m) => CompileError(
                message:
                    'Screen "$screenName" references unregistered widget(s): $m',
                screenName: screenName,
              ),
            )
            .toList(),
      );
    }

    return CompileSuccess(ir: irMap);
  } on InvalidGenerationSourceError catch (e) {
    return CompileFailure(
      errors: [CompileError(message: e.message, screenName: screenName)],
    );
  } on LoweringError catch (e) {
    return CompileFailure(
      errors: [CompileError(message: e.message, screenName: screenName)],
    );
  } catch (e) {
    return CompileFailure(
      errors: [CompileError(message: e.toString(), screenName: screenName)],
    );
  }
}
