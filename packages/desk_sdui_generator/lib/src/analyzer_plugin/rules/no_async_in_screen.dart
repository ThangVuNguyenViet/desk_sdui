import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'error_info.dart';

const String noAsyncInScreenCode = 'sdui_no_async_in_screen';
const String noAsyncInScreenMessage = 'await is not allowed inside @Screen functions';

class NoAsyncInScreenVisitor extends RecursiveAstVisitor<void> {
  final List<AnalysisErrorInfo> errors;
  NoAsyncInScreenVisitor(this.errors);

  @override
  void visitAwaitExpression(AwaitExpression node) {
    errors.add(AnalysisErrorInfo(
      node.offset,
      node.length,
      noAsyncInScreenCode,
      noAsyncInScreenMessage,
    ));
    super.visitAwaitExpression(node);
  }
}
