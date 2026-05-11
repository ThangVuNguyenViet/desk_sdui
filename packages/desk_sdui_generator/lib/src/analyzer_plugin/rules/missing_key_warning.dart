import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'error_info.dart';

const String missingKeyCode = 'sdui_missing_key_warning';
const String missingKeyMessage = 'ForNode body should have a key for efficient list rendering';

class MissingKeyWarningVisitor extends RecursiveAstVisitor<void> {
  final List<AnalysisErrorInfo> warnings;
  MissingKeyWarningVisitor(this.warnings);

  @override
  void visitForElement(ForElement node) {
    final body = node.body;
    final isWidgetCall = body is InstanceCreationExpression ||
        (body is MethodInvocation &&
            body.target == null &&
            body.methodName.name.isNotEmpty &&
            body.methodName.name[0] == body.methodName.name[0].toUpperCase());
    if (isWidgetCall) {
      final args = body is InstanceCreationExpression
          ? body.argumentList.arguments
          : (body as MethodInvocation).argumentList.arguments;
      final hasKey = args.any(
        (a) => a is NamedArgument && a.name.lexeme == 'key',
      );
      if (!hasKey) {
        warnings.add(AnalysisErrorInfo(
          node.offset,
          node.length,
          missingKeyCode,
          missingKeyMessage,
        ));
      }
    }
    super.visitForElement(node);
  }
}
