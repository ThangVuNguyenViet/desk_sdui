import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

void main() {
  test('check nested property access staticType', () async {
    final source = r'''
import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

@Screen('test')
Widget testScreen(BuildContext context) {
  final theme = Theme.of(context);
  final style = theme.textTheme.headlineLarge;
  return Text('hi', style: style);
}
''';

    final tempFile = File('/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/packages/desk_sdui_demo/lib/_test_theme.dart');
    tempFile.writeAsStringSync(source);
    try {
      final result = await resolveFile(path: tempFile.path);
      expect(result, isA<ResolvedUnitResult>());
      final unit = (result as ResolvedUnitResult).unit;

      for (final decl in unit.declarations) {
        if (decl is FunctionDeclaration) {
          final body = decl.functionExpression.body;
          if (body is BlockFunctionBody) {
            for (final stmt in body.block.statements) {
              if (stmt is VariableDeclarationStatement) {
                for (final v in stmt.variables.variables) {
                  final init = v.initializer;
                  if (init is PropertyAccess) {
                    _printPropertyAccess(init, 0);
                  }
                }
              }
            }
          }
        }
      }
    } finally {
      if (tempFile.existsSync()) tempFile.deleteSync();
    }
  });
}

void _printPropertyAccess(PropertyAccess node, int depth) {
  final indent = '  ' * depth;
  print('${indent}PropertyAccess: ${node.toSource()}');
  print('${indent}  target staticType: ${node.target?.staticType}');
  print('${indent}  propertyName: ${node.propertyName.name}');
  if (node.target is PropertyAccess) {
    _printPropertyAccess(node.target as PropertyAccess, depth + 1);
  } else if (node.target is SimpleIdentifier) {
    final target = node.target as SimpleIdentifier;
    print('${indent}  target element: ${target.element}');
    print('${indent}  target element type: ${target.element?.runtimeType}');
  }
}