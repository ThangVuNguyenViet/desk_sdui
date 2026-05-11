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

class ScreenGenerator extends GeneratorForAnnotation<Screen> {
  @override
  Future<String> generateForAnnotatedElement(
    dynamic element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final ann = ScreenAnnotationData(
      name: annotation.read('name').stringValue,
    );

    final unit = await buildStep.resolver.compilationUnitFor(buildStep.inputId);

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
    if (body is! ExpressionFunctionBody) {
      throw InvalidGenerationSourceError(
        '@Screen function must be `=>`-bodied',
      );
    }

    var result = lowerScreen(fnDecl, ann);
    var ir = constFold(result.root);
    ir = reactiveHoist(ir);
    ir = inferKeys(ir);

    final tree = IrTree(name: ann.name, version: 1, root: ir);
    final jsonBytes = emitJson(tree);
    await buildStep.writeAsBytes(
      buildStep.inputId.changeExtension('.sdui.json'),
      jsonBytes,
    );

    final bindingCode = emitDart(result.copyWith(root: ir), partOfUri: buildStep.inputId.uri.toString());

    // Collect external type references from the *resolved* AST so that element
    // identity (ClassElement, MethodElement, etc.) is available to the visitor.
    // The fnDecl obtained above via compilationUnitFor is unresolved; we resolve
    // the library via the element's session to get the proper declaration.
    FunctionDeclaration? resolvedFnDecl;
    if (element is FunctionElement) {
      final session = element.session;
      if (session != null) {
        final resolvedLibResult = await session.getResolvedLibraryByElement(
          element.library,
        );
        if (resolvedLibResult is ResolvedLibraryResult) {
          final declResult = resolvedLibResult.getElementDeclaration(element);
          resolvedFnDecl = declResult?.node as FunctionDeclaration?;
        }
      }
    }

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

    // The registration function references many Flutter types (DragStartBehavior,
    // HitTestBehavior, TapMoveDetails, LongPressDownDetails, ViewPadding,
    // ColorSpace, Matrix4, etc.).  Rather than tracking individual library URIs
    // (which surface as internal `src/` paths via the analyzer element model),
    // we emit a fixed set of public barrel imports that collectively cover every
    // type that any Flutter widget constructor or value-type constructor may
    // reference.
    //
    // Part files cannot carry import directives, so the registration function
    // lives in a separate standalone file (<screen>.sdui_reg.g.dart).
    // vector_math exports a `Colors` symbol that conflicts with Flutter's
    // `Colors`. Hide it to avoid the ambiguity while still getting `Matrix4`.
    const importBlock = '''
import 'dart:ui';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;''';

    final ignoreDirective = '// ignore_for_file: '
        'cast_nullable_to_non_nullable, '
        'cascade_invocations, '
        'prefer_const_constructors, '
        'lines_longer_than_80_chars, '
        'unnecessary_const, '
        'unused_import, '
        'directives_ordering, '
        'always_use_package_imports';

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

    // Write registration function to a separate (non-part) file so it can
    // carry its own import directives (part files cannot).
    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.sdui_reg.g.dart'),
      formattedRegFile,
    );

    // The part file (chef.sdui.g.dart) only holds the ScreenBinding + a
    // forward declaration of the registration function so that callers that
    // import the part-of library still see the symbol.
    // The function body lives in the sibling .sdui_reg.g.dart file; we expose
    // it here as a re-export via the `show` directive in desk_sdui_setup.g.dart.
    return bindingCode;
  }
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
