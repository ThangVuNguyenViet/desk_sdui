import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'error_info.dart';

const String noSetStateCode = 'sdui_no_set_state';
const String noSetStateMessage = 'setState is not allowed in @Screen functions — use reactive state instead';

class NoSetStateVisitor extends RecursiveAstVisitor<void> {
  final List<AnalysisErrorInfo> errors;
  NoSetStateVisitor(this.errors);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      errors.add(AnalysisErrorInfo(
        node.offset,
        node.length,
        noSetStateCode,
        noSetStateMessage,
      ));
    }
    super.visitMethodInvocation(node);
  }
}
