import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'error_info.dart';

const String noFunctionDefinitionCode = 'sdui_no_function_definition';
const String noFunctionDefinitionMessage = 'Nested function definitions are not allowed in @Screen functions';

class NoFunctionDefinitionVisitor extends RecursiveAstVisitor<void> {
  final List<AnalysisErrorInfo> errors;
  NoFunctionDefinitionVisitor(this.errors);

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    errors.add(AnalysisErrorInfo(
      node.offset,
      node.length,
      noFunctionDefinitionCode,
      noFunctionDefinitionMessage,
    ));
    super.visitFunctionDeclaration(node);
  }
}
