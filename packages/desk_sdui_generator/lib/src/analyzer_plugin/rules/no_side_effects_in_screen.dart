import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'error_info.dart';

const String noSideEffectsCode = 'sdui_no_side_effects_in_screen';

/// URIs whose use inside @Screen-annotated bodies is forbidden for
/// Apple App Store §3.3.2 compliance (dynamic code execution / file I/O).
const Set<String> _denylistUris = {
  'dart:io',
  'dart:isolate',
  'dart:ffi',
  'dart:mirrors',
};

String _noSideEffectsMessage(String identifier, String libraryUri) =>
    'sdui_no_side_effects_in_screen: identifier `$identifier` references '
    'library `$libraryUri`, which is not allowed inside @Screen functions.';

/// Visits import directives and reports any that pull in a denylist library.
///
/// Running at the import level means we can catch violations using only the
/// parsed (unresolved) AST — the same approach used by every other rule in
/// this package — without requiring a full analysis context.
class NoSideEffectsImportVisitor extends RecursiveAstVisitor<void> {
  final List<AnalysisErrorInfo> errors;
  NoSideEffectsImportVisitor(this.errors);

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue ?? '';
    if (_denylistUris.contains(uri)) {
      errors.add(AnalysisErrorInfo(
        node.offset,
        node.length,
        noSideEffectsCode,
        _noSideEffectsMessage(uri, uri),
      ));
    }
    super.visitImportDirective(node);
  }
}

/// Visits simple identifiers, prefixed identifiers, and method invocations
/// inside a function body and reports any whose resolved element belongs to
/// a denylist library.
///
/// Requires a *resolved* AST (obtained via the analyzer session, not
/// parseString).  Used by the build-time check in screen_generator.dart.
class NoSideEffectsIdentifierVisitor extends RecursiveAstVisitor<void> {
  final List<AnalysisErrorInfo> errors;
  NoSideEffectsIdentifierVisitor(this.errors);

  void _checkNode(AstNode node, String name) {
    final element = switch (node) {
      SimpleIdentifier n => n.staticElement,
      PrefixedIdentifier n => n.staticElement,
      _ => null,
    };
    if (element == null) return;
    // ignore_for_file: deprecated_member_use
    final uri = element.library?.source.uri.toString();
    if (uri == null) return;
    if (_denylistUris.contains(uri)) {
      errors.add(AnalysisErrorInfo(
        node.offset,
        node.length,
        noSideEffectsCode,
        _noSideEffectsMessage(name, uri),
      ));
    }
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _checkNode(node, node.name);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _checkNode(node, node.identifier.name);
    super.visitPrefixedIdentifier(node);
  }
}
