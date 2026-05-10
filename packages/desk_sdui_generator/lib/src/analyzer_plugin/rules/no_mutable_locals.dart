import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'error_info.dart';

const String noMutableLocalsCode = 'sdui_no_mutable_locals';
const String noMutableLocalsMessage = 'Use `final` instead of `var` in @Screen functions';

class NoMutableLocalsVisitor extends RecursiveAstVisitor<void> {
  final List<AnalysisErrorInfo> errors;
  NoMutableLocalsVisitor(this.errors);

  @override
  void visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    if (node.variables.keyword?.lexeme == 'var') {
      errors.add(AnalysisErrorInfo(
        node.offset,
        node.length,
        noMutableLocalsCode,
        noMutableLocalsMessage,
      ));
    }
    super.visitVariableDeclarationStatement(node);
  }
}
