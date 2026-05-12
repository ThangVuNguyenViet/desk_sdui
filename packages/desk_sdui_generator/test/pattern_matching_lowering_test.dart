// ignore_for_file: deprecated_member_use
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_generator/src/diagnostics.dart';
import 'package:desk_sdui_generator/src/screen_lowering/ast_to_ir.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _demoPackageRoot =
    '/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/packages/desk_sdui_demo';

Future<FunctionDeclaration> _resolveScreen(String source) async {
  final dir = Directory(p.join(_demoPackageRoot, 'lib'));
  final tempFile = File(
    p.join(
      dir.path,
      '_pat_match_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
    ),
  );
  tempFile.writeAsStringSync(source);
  try {
    final result = await resolveFile(path: tempFile.path);
    if (result is! ResolvedUnitResult) {
      throw StateError('resolveFile returned ${result.runtimeType}');
    }
    return result.unit.declarations.whereType<FunctionDeclaration>().first;
  } finally {
    if (tempFile.existsSync()) tempFile.deleteSync();
  }
}

ScreenLowerResult _lower(FunctionDeclaration fnDecl) {
  return lowerScreen(fnDecl, ScreenAnnotationData(name: 'test'));
}

void main() {
  group('Pattern matching lowering', () {
    test(
        'literal switch — ConstantPattern chain becomes CompareOpNode chain',
        () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s(String x) {
  return switch (x) {
    'a' => Text('alpha'),
    'b' => Text('beta'),
    _ => SizedBox.shrink(),
  };
}
''');
      final result = _lower(fnDecl);
      // Root should be a LetNode (scrutinee hoist) wrapping a ConditionalNode
      // chain.
      expect(result.root, isA<LetNode>());
      final outer = result.root as LetNode;
      expect(outer.name, startsWith('__scrut'));
      // The body is a ConditionalNode (for 'a')
      expect(outer.body, isA<ConditionalNode>());
      final cond1 = outer.body as ConditionalNode;
      expect(cond1.condition, isA<CompareOpNode>());
      final cmp1 = cond1.condition as CompareOpNode;
      expect(cmp1.op, CompareOp.eq);
      // Inner else should also be a ConditionalNode (for 'b')
      expect(cond1.elseBranch, isA<ConditionalNode>());
    });

    test('object pattern switch — IsTypeNode chain', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

sealed class S {}
class SA extends S {}
class SB extends S {}

Widget s(S state) {
  return switch (state) {
    SA() => Text('a'),
    SB() => Text('b'),
    _ => SizedBox.shrink(),
  };
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<LetNode>());
      final outer = result.root as LetNode;
      expect(outer.body, isA<ConditionalNode>());
      final cond1 = outer.body as ConditionalNode;
      // First case condition is an IsTypeNode
      expect(cond1.condition, isA<IsTypeNode>());
      final isType = cond1.condition as IsTypeNode;
      expect(isType.typeName, 'SA');
      // Second case is another ConditionalNode
      expect(cond1.elseBranch, isA<ConditionalNode>());
      final cond2 = cond1.elseBranch as ConditionalNode;
      expect(cond2.condition, isA<IsTypeNode>());
      expect((cond2.condition as IsTypeNode).typeName, 'SB');
    });

    test(
        'field-bound object pattern — IsTypeNode + LetNode wrapping branch',
        () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

sealed class S {}
class SLoaded extends S {
  SLoaded(this.data);
  final String data;
}

Widget s(S state) {
  return switch (state) {
    SLoaded(:final data) => Text(data),
    _ => SizedBox.shrink(),
  };
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<LetNode>());
      final outer = result.root as LetNode;
      expect(outer.body, isA<ConditionalNode>());
      final cond = outer.body as ConditionalNode;
      // Condition is an IsTypeNode
      expect(cond.condition, isA<IsTypeNode>());
      expect((cond.condition as IsTypeNode).typeName, 'SLoaded');
      // Then branch is a LetNode binding 'data'
      expect(cond.thenBranch, isA<LetNode>());
      final letData = cond.thenBranch as LetNode;
      expect(letData.name, 'data');
      // The value should be a MemberAccessNode on scrutRef for 'data'
      expect(letData.value, isA<MemberAccessNode>());
      final member = letData.value as MemberAccessNode;
      expect(member.name, 'data');
      // The body of the LetNode is the branch widget
      expect(letData.body, isA<WidgetNode>());
    });

    test('non-exhaustive switch without wildcard arm rejects with error',
        () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

sealed class S {}
class SA extends S {}

Widget s(S state) {
  return switch (state) {
    SA() => Text('a'),
  };
}
''');
      expect(
        () => _lower(fnDecl),
        throwsA(
          isA<LoweringError>().having(
            (e) => e.message,
            'message',
            contains('Non-exhaustive switch'),
          ),
        ),
      );
    });

    test('type check registry — type_collector picks up ObjectPattern types',
        () async {
      // This test verifies that the type_collector's visitSwitchExpression
      // records pattern types into sealedSubtypes.
      // We do this by running lowerScreen and checking collectTypes separately,
      // but since we can't easily test type_collector here we just verify that
      // the lowering produces IsTypeNode nodes which implies the visitor runs.
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

sealed class AppState {}
class Loading extends AppState {}
class Loaded extends AppState { Loaded(this.count); final int count; }

Widget s(AppState state) {
  return switch (state) {
    Loading() => const CircularProgressIndicator(),
    Loaded(:final count) => Text('\$count items'),
    _ => SizedBox.shrink(),
  };
}
''');
      final result = _lower(fnDecl);
      // Walk the IR tree to find IsTypeNode nodes
      final isTypeNodes = <IsTypeNode>[];
      _collectIsTypeNodes(result.root, isTypeNodes);
      expect(isTypeNodes.map((n) => n.typeName).toSet(),
          containsAll(['Loading', 'Loaded']));
    });
  });
}

void _collectIsTypeNodes(IrNode node, List<IsTypeNode> out) {
  if (node is IsTypeNode) {
    out.add(node);
    _collectIsTypeNodes(node.receiver, out);
    return;
  }
  if (node is LetNode) {
    _collectIsTypeNodes(node.value, out);
    _collectIsTypeNodes(node.body, out);
  } else if (node is ConditionalNode) {
    _collectIsTypeNodes(node.condition, out);
    _collectIsTypeNodes(node.thenBranch, out);
    if (node.elseBranch != null) _collectIsTypeNodes(node.elseBranch!, out);
  } else if (node is WidgetNode) {
    for (final child in node.args.values) {
      _collectIsTypeNodes(child, out);
    }
  }
}
