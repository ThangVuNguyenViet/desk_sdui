import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'error_info.dart';

const String unsupportedLoopCode = 'sdui_unsupported_loop';
const String unsupportedLoopMessage = 'while/do/counter-for loops are not supported in @Screen — use for-in collection elements';

class UnsupportedLoopVisitor extends RecursiveAstVisitor<void> {
  final List<AnalysisErrorInfo> errors;
  UnsupportedLoopVisitor(this.errors);

  @override
  void visitWhileStatement(WhileStatement node) {
    errors.add(AnalysisErrorInfo(
      node.offset,
      node.length,
      unsupportedLoopCode,
      unsupportedLoopMessage,
    ));
    super.visitWhileStatement(node);
  }

  @override
  void visitDoStatement(DoStatement node) {
    errors.add(AnalysisErrorInfo(
      node.offset,
      node.length,
      unsupportedLoopCode,
      unsupportedLoopMessage,
    ));
    super.visitDoStatement(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    final parts = node.forLoopParts;
    if (parts is ForPartsWithExpression || parts is ForPartsWithDeclarations) {
      errors.add(AnalysisErrorInfo(
        node.offset,
        node.length,
        unsupportedLoopCode,
        unsupportedLoopMessage,
      ));
    }
    super.visitForStatement(node);
  }
}
