import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

import 'ast_to_ir.dart';
import 'const_fold_pass.dart';
import 'reactive_hoist_pass.dart';
import 'key_infer_pass.dart';
import 'ir_emitter_dart.dart';
import 'ir_emitter_json.dart';

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

    return emitDart(result.copyWith(root: ir), partOfUri: buildStep.inputId.uri.toString());
  }
}
