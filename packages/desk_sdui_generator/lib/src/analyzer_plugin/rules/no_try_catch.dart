import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'error_info.dart';

const String noTryCatchCode = 'sdui_no_try_catch';
const String noTryCatchMessage = 'try/catch is not allowed in @Screen functions';

class NoTryCatchVisitor extends RecursiveAstVisitor<void> {
  final List<AnalysisErrorInfo> errors;
  NoTryCatchVisitor(this.errors);

  @override
  void visitTryStatement(TryStatement node) {
    errors.add(AnalysisErrorInfo(
      node.offset,
      node.length,
      noTryCatchCode,
      noTryCatchMessage,
    ));
    super.visitTryStatement(node);
  }
}
