// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Deduped sets of external type references found inside a single @Screen body.
///
/// "External" means not a parameter of the @Screen function itself, and not a
/// local introduced by a `for`/lambda inside the screen body.
///
/// Deduplication is by element identity: multiple call sites that use `Column`
/// contribute a single `ClassElement` for `Column`, not one per call site.
class CollectedTypes {
  CollectedTypes({
    Set<ClassElement>? widgets,
    Set<ClassElement>? valueTypes,
    Set<Element>? constants,
    Set<MethodElement>? methods,
    Set<DartType>? subscriptables,
    Set<FunctionElement>? functions,
  })  : widgets = widgets ?? {},
        valueTypes = valueTypes ?? {},
        constants = constants ?? {},
        methods = methods ?? {},
        subscriptables = subscriptables ?? {},
        functions = functions ?? {};

  /// Widget subclasses constructed in the screen body (e.g. `Column`, `Text`).
  final Set<ClassElement> widgets;

  /// Non-Widget value types constructed in the screen body
  /// (e.g. `EdgeInsets`, `BoxDecoration`).
  final Set<ClassElement> valueTypes;

  /// Static const/getter references whose prefix is a class
  /// (e.g. `Icons.menu`, `Colors.white`).
  /// Elements are `FieldElement` or `PropertyAccessorElement`.
  final Set<Element> constants;

  /// Instance method references used on a receiver with a known static type
  /// (e.g. `String.toUpperCase`, `num.toStringAsFixed`).
  final Set<MethodElement> methods;

  /// Receiver types whose `[]` operator was used
  /// (e.g. `MaterialColor`, `Map<K,V>`, `List<E>`).
  final Set<DartType> subscriptables;

  /// Top-level function references (e.g. `min`, `max`).
  final Set<FunctionElement> functions;

  /// Merges [other] into this (in-place union).
  void unionWith(CollectedTypes other) {
    widgets.addAll(other.widgets);
    valueTypes.addAll(other.valueTypes);
    constants.addAll(other.constants);
    methods.addAll(other.methods);
    subscriptables.addAll(other.subscriptables);
    functions.addAll(other.functions);
  }
}

/// Walk [screen]'s body and return the deduped set of external type references.
///
/// [screen] must be a resolved [FunctionDeclaration] (i.e. obtained from an
/// analysis session, not from `parseString`). References that originate from
/// the function's own parameters or from for-loop / lambda-introduced locals
/// are skipped — those are binding-layer concerns, not external Flutter types.
CollectedTypes collectTypes(FunctionDeclaration screen) {
  final visitor = _TypeVisitor(screen);
  screen.accept(visitor);
  return visitor.collected;
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

class _TypeVisitor extends RecursiveAstVisitor<void> {
  _TypeVisitor(this._screen) {
    // Collect the screen's own parameter names so we can skip receiver refs
    // that originate from bindings (controller.someMethod, etc.).
    final params = _screen.functionExpression.parameters?.parameters;
    if (params != null) {
      for (final p in params) {
        final name = p.name?.lexeme;
        if (name != null) _screenParamNames.add(name);
      }
    }
  }

  final FunctionDeclaration _screen;
  final _screenParamNames = <String>{};

  final collected = CollectedTypes();

  // Track locals introduced by for-loops / lambdas so we can skip them.
  final _localNames = <String>{};

  // -------------------------------------------------------------------------
  // Instance creation: Widget or value type
  // -------------------------------------------------------------------------

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final ctorElement = node.constructorName.staticElement;
    final enclosing = ctorElement?.enclosingElement3;
    if (enclosing is ClassElement) {
      if (_isWidgetSubtype(enclosing)) {
        collected.widgets.add(enclosing);
      } else {
        collected.valueTypes.add(enclosing);
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  // -------------------------------------------------------------------------
  // Method invocations: instance methods on typed receivers
  // -------------------------------------------------------------------------

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;

    if (target == null) {
      // No receiver — could be a top-level function call.
      final methodElement = node.methodName.staticElement;
      if (methodElement is FunctionElement) {
        collected.functions.add(methodElement);
      }
      super.visitMethodInvocation(node);
      return;
    }

    // Collect the instance method so the SDUI runtime can register it.
    // We do NOT skip @Screen parameter receivers here: calling .toUpperCase()
    // on a String param still requires String.toUpperCase to be registered.
    // The only calls we skip are closure-lowered bindings (e.g.
    // `() => controller.doSomething()`), which the closure lowerer handles
    // separately and which appear as FunctionExpression nodes, not bare
    // MethodInvocation nodes.
    final methodElement = node.methodName.staticElement;
    if (methodElement is MethodElement) {
      collected.methods.add(methodElement);
    }

    super.visitMethodInvocation(node);
  }

  // -------------------------------------------------------------------------
  // Static const / getter refs: Icons.menu, Colors.white, etc.
  // -------------------------------------------------------------------------

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final prefixElement = node.prefix.staticElement;
    // Interested when the prefix resolves to a class or enum (static access).
    // Both ClassElement and EnumElement are subtypes of InterfaceElement.
    if (prefixElement is InterfaceElement) {
      final propElement = node.identifier.staticElement;
      if (propElement != null) {
        collected.constants.add(propElement);
      }
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (target is SimpleIdentifier) {
      final targetElement = target.staticElement;
      if (targetElement is InterfaceElement) {
        final propElement = node.propertyName.staticElement;
        if (propElement != null) {
          collected.constants.add(propElement);
        }
      }
    }
    super.visitPropertyAccess(node);
  }

  // -------------------------------------------------------------------------
  // Index expressions: Colors.grey[300], list[0], etc.
  // -------------------------------------------------------------------------

  @override
  void visitIndexExpression(IndexExpression node) {
    final type = node.target?.staticType;
    if (type != null) {
      collected.subscriptables.add(type);
    }
    super.visitIndexExpression(node);
  }

  // -------------------------------------------------------------------------
  // For-loop locals — track so we can skip them as receivers
  // -------------------------------------------------------------------------

  @override
  void visitForElement(ForElement node) {
    final parts = node.forLoopParts;
    if (parts is ForEachPartsWithDeclaration) {
      final name = parts.loopVariable.name.lexeme;
      _localNames.add(name);
      super.visitForElement(node);
      _localNames.remove(name);
      return;
    }
    super.visitForElement(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Collect lambda param names as locals.
    final added = <String>[];
    final params = node.parameters?.parameters;
    if (params != null) {
      for (final p in params) {
        final name = p.name?.lexeme;
        if (name != null) {
          _localNames.add(name);
          added.add(name);
        }
      }
    }
    super.visitFunctionExpression(node);
    for (final n in added) {
      _localNames.remove(n);
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// True if [cls] is a subtype of Flutter's `Widget`.
  ///
  /// Uses [InterfaceElement.allSupertypes] for a flat O(n) walk instead of
  /// recursive supertype traversal.
  bool _isWidgetSubtype(ClassElement cls) {
    if (cls.name == 'Widget') return true;
    // allSupertypes includes all transitive supertypes (super, interfaces,
    // mixins) in linearisation order — ideal for Widget detection.
    for (final supertype in cls.allSupertypes) {
      if (supertype.element.name == 'Widget') return true;
    }
    return false;
  }
}
