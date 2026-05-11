// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:source_gen/source_gen.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

import 'ast_to_ir.dart';
import 'const_fold_pass.dart';
import 'reactive_hoist_pass.dart';
import 'key_infer_pass.dart';
import 'ir_emitter_dart.dart';
import 'ir_emitter_json.dart';
import '../type_collector.dart';
import '../registration_emitter.dart';
import '../analyzer_plugin/rules/no_side_effects_in_screen.dart';
import '../analyzer_plugin/rules/error_info.dart';

/// The outputs produced by lowering a single @Screen-annotated function.
class ScreenLoweringOutputs {
  ScreenLoweringOutputs({
    required this.jsonBytes,
    required this.dartBindingCode,
    required this.registrationCode,
    required this.referencedWidgetNames,
  });

  final List<int> jsonBytes;
  final String dartBindingCode;
  final String registrationCode;

  /// Widget type names referenced in the screen body (simple class names).
  final Set<String> referencedWidgetNames;
}

/// Pure lowering pass for a single @Screen-annotated element.
///
/// Does not interact with [BuildStep]; callers are responsible for I/O.
ScreenLoweringOutputs lowerScreenElement({
  required Element element,
  required ConstantReader annotation,
  required CompilationUnit unit,
  required ResolvedLibraryResult? resolvedLibResult,
  required String partOfUri,
}) {
  final ann = ScreenAnnotationData(
    name: annotation.read('name').stringValue,
  );

  final funcName = element.name as String;
  FunctionDeclaration? fnDecl;

  for (final decl in unit.directives.whereType<PartDirective>().isEmpty
      ? unit.declarations
      : unit.declarations) {
    if (decl is FunctionDeclaration && decl.name.lexeme == funcName) {
      fnDecl = decl;
      break;
    }
  }

  if (fnDecl == null) {
    throw InvalidGenerationSourceError(
      'Could not find function declaration for $funcName',
    );
  }

  final body = fnDecl.functionExpression.body;
  if (body is ExpressionFunctionBody) {
    // expression-bodied — fine
  } else if (body is BlockFunctionBody) {
    final statements = body.block.statements;
    if (statements.length != 1 || statements.single is! ReturnStatement) {
      throw InvalidGenerationSourceError(
        '@Screen body must be a single return statement or expression body; '
        'got ${body.runtimeType}',
      );
    }
  } else {
    throw InvalidGenerationSourceError(
      '@Screen body must be a single return statement or expression body; '
      'got ${body.runtimeType}',
    );
  }

  // Resolve the library first so the lowerer has access to static types
  // (needed to split RefNode paths at core-type boundaries).
  FunctionDeclaration? resolvedFnDecl;
  if (element is TopLevelFunctionElement && resolvedLibResult != null) {
    final declResult = resolvedLibResult.getFragmentDeclaration(element.firstFragment);
    resolvedFnDecl = declResult?.node as FunctionDeclaration?;
  }

  final lowerFnDecl = resolvedFnDecl ?? fnDecl;
  var result = lowerScreen(lowerFnDecl, ann);
  var ir = constFold(result.root);
  ir = reactiveHoist(ir);
  ir = inferKeys(ir);

  final tree = IrTree(name: ann.name, version: 1, root: ir);
  final jsonBytes = emitJson(tree);

  final bindingCode = emitDart(result.copyWith(root: ir), partOfUri: partOfUri);

  // Enforce Apple §3.3.2 posture: no references to dart:io, dart:isolate,
  // dart:ffi, or dart:mirrors inside a @Screen body.
  if (resolvedFnDecl != null) {
    final sideEffectErrors = <AnalysisErrorInfo>[];
    resolvedFnDecl.accept(NoSideEffectsIdentifierVisitor(sideEffectErrors));
    if (sideEffectErrors.isNotEmpty) {
      final first = sideEffectErrors.first;
      throw InvalidGenerationSourceError(first.message);
    }
  }

  final collected = collectTypes(resolvedFnDecl ?? fnDecl);
  final registrations = RegistrationEmitter().emitAll(collected);
  final capitalizedName = _capitalize(ann.name);

  // Build import block: fixed Flutter/desk_sdui imports plus any extra
  // packages discovered by the type collector (e.g. package:cue/cue.dart).
  final extraImports = <String>{};
  for (final uri in collected.extraLibraryUris) {
    if (uri.startsWith('package:')) {
      final pkg = uri.substring('package:'.length).split('/').first;
      if (pkg != 'desk_sdui' && pkg != 'flutter' && pkg != 'vector_math') {
        extraImports.add('package:$pkg/$pkg.dart');
      }
    }
  }

  final importLines = [
    "import 'dart:ui';",
    for (final imp in extraImports.toList()..sort()) "import '$imp';",
    "import 'package:desk_sdui/desk_sdui.dart';",
    "import 'package:flutter/gestures.dart';",
    "import 'package:flutter/material.dart';",
    "import 'package:flutter/rendering.dart';",
    "import 'package:vector_math/vector_math_64.dart' hide Colors;",
  ];
  final importBlock = importLines.join('\n');

  final ignoreDirective = '// ignore_for_file: '
      'cast_nullable_to_non_nullable, '
      'cascade_invocations, '
      'prefer_const_constructors, '
      'lines_longer_than_80_chars, '
      'unnecessary_const, '
      'unused_import, '
      'directives_ordering, '
      'always_use_package_imports, '
      'instantiate_abstract_class';

  final registrationFile = '''
// GENERATED CODE — DO NOT MODIFY BY HAND
$ignoreDirective
$importBlock

void register${capitalizedName}Dependencies(Runtime rt) {
$registrations
}
''';
  final formattedRegFile = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  ).format(registrationFile);

  return ScreenLoweringOutputs(
    jsonBytes: jsonBytes,
    dartBindingCode: bindingCode,
    registrationCode: formattedRegFile,
    referencedWidgetNames: result.widgetRefs,
  );
}

class ScreenGenerator extends GeneratorForAnnotation<Screen> {
  @override
  Future<String> generateForAnnotatedElement(
    dynamic element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final el = element as Element;
    final unit = await buildStep.resolver.compilationUnitFor(buildStep.inputId);

    // Resolve the library first so the lowerer has access to static types
    ResolvedLibraryResult? resolvedLibResult;
    if (el is TopLevelFunctionElement) {
      final session = el.session;
      if (session != null) {
        final result = await session.getResolvedLibraryByElement(el.library);
        if (result is ResolvedLibraryResult) {
          resolvedLibResult = result;
        }
      }
    }

    final outputs = lowerScreenElement(
      element: el,
      annotation: annotation,
      unit: unit,
      resolvedLibResult: resolvedLibResult,
      partOfUri: buildStep.inputId.uri.toString(),
    );

    await buildStep.writeAsBytes(
      buildStep.inputId.changeExtension('.sdui.json'),
      outputs.jsonBytes,
    );

    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.sdui_reg.g.dart'),
      outputs.registrationCode,
    );

    return outputs.dartBindingCode;
  }
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
