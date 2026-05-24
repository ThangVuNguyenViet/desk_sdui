import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

void main() async {
  final source = '''
class Counter {
  int count = 0;
}

void test(Counter c) {
  final x = c.count * 2;
}
''';
  final tempFile = File('/tmp/test_parse.dart');
  tempFile.writeAsStringSync(source);
  final result = await resolveFile(path: tempFile.path);
  final unit = (result as ResolvedUnitResult).unit;

  void visit(AstNode node, int depth) {
    final indent = '  ' * depth;
    if (node is PrefixedIdentifier) {
      print('${indent}PrefixedIdentifier: ${node.toSource()}');
      print('${indent}  prefix staticType: ${node.prefix.staticType}');
    }
    if (node is PropertyAccess) {
      print('${indent}PropertyAccess: ${node.toSource()}');
      print('${indent}  target staticType: ${node.target?.staticType}');
    }
    for (final child in node.childEntities) {
      if (child is AstNode) {
        visit(child, depth + 1);
      }
    }
  }

  visit(unit, 0);
}