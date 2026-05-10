import 'package:analyzer/dart/ast/ast.dart';

class LoweringError implements Exception {
  LoweringError(this.message, this.node);
  final String message;
  final AstNode node;
  @override
  String toString() => 'LoweringError @ ${node.offset}: $message';
}
