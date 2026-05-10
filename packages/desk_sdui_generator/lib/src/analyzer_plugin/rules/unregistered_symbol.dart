import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'error_info.dart';

const String unregisteredSymbolCode = 'sdui_unregistered_symbol';
const String unregisteredSymbolMessage = 'Use only registered widgets in @Screen functions';

class UnregisteredSymbolVisitor extends RecursiveAstVisitor<void> {
  final List<AnalysisErrorInfo> errors;
  UnregisteredSymbolVisitor(this.errors);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName.type.name2.lexeme;
    if (!_isBuiltin(name)) {
      errors.add(AnalysisErrorInfo(
        node.offset,
        node.length,
        unregisteredSymbolCode,
        unregisteredSymbolMessage,
      ));
    }
    super.visitInstanceCreationExpression(node);
  }

  bool _isBuiltin(String name) {
    const builtins = {
      'Text', 'Column', 'Row', 'Stack', 'Container', 'Padding', 'Center',
      'SizedBox', 'Expanded', 'Flexible', 'Spacer', 'Align', 'Positioned',
      'ListView', 'GridView', 'SingleChildScrollView', 'Wrap', 'Divider',
      'Icon', 'Image', 'Placeholder', 'Opacity', 'Transform', 'FittedBox',
      'ConstrainedBox', 'DecoratedBox', 'ClipRect', 'ClipRRect', 'ClipOval',
    };
    return builtins.contains(name);
  }
}
