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
    final registrationFn = '''
void register${capitalizedName}Dependencies(Runtime rt) {
$registrations
}
''';
    final formattedRegFn = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion).format(registrationFn);

    // Strip the `part of` header that DartFormatter may have added (it won't —
    // the registration snippet has no part directive), then concatenate.
    // bindingCode already ends with a newline from its own format() call.
    return '$bindingCode\n$formattedRegFn';
  }
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
