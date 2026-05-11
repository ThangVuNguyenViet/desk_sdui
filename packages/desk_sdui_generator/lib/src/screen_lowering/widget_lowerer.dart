import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import '../diagnostics.dart';
import 'expression_lowerer.dart';
import 'closure_lowerer.dart';

const _constCtors = {
  'EdgeInsets.all',
  'EdgeInsets.symmetric',
  'EdgeInsets.only',
  'EdgeInsets.fromLTRB',
  'Color',
  'Color.fromARGB',
  'Color.fromRGBO',
  'BorderRadius.all',
  'BorderRadius.circular',
  'BorderRadius.only',
  'TextStyle',
  'Alignment',
  'Duration',
  'IconData',
};

const _positionalParams = {
  'Text': ['data', 'style', 'textAlign', 'textDirection', 'locale', 'softWrap', 'overflow', 'textScaler', 'maxLines', 'semanticsLabel', 'textWidthBasis', 'textHeightBehavior', 'selectionColor'],
  'Icon': ['icon', 'size', 'color', 'semanticLabel', 'textDirection'],
};

IrNode lowerWidgetInstance(InstanceCreationExpression expr, {Object? Function(InstanceCreationExpression)? constEvaluator}) {
  final ctorName = _ctorFullName(expr);

  if (constEvaluator != null && _isConstFoldable(ctorName)) {
    final value = constEvaluator(expr);
    if (value != null) {
      return ConstNode(value);
    }
  }

  // Use the fully-qualified constructor name so that value-type constructors
  // like `EdgeInsets.only` are registered and dispatched correctly.
  // For regular widgets (e.g. `Column`, `Padding`) ctorName is already the
  // simple class name; for named constructors and static factories the
  // qualifier is now preserved (e.g. `'EdgeInsets.only'`).
  final widgetName = ctorName;
  final args = <String, IrNode>{};
  IrNode? key;

  final positionalParams = _positionalParams[widgetName] ?? const <String>[];

  var positionalIndex = 0;
  for (final a in expr.argumentList.arguments) {
    if (a is NamedArgument) {
      final name = a.name.lexeme;
      final value =
          _lowerArg(a.argumentExpression, constEvaluator: constEvaluator, paramName: name);
      if (name == 'key') {
        key = value;
      } else {
        args[name] = value;
      }
    } else {
      final paramName = positionalIndex < positionalParams.length
          ? positionalParams[positionalIndex]
          : 'arg$positionalIndex';
      args[paramName] =
          _lowerArg(a.argumentExpression, constEvaluator: constEvaluator, paramName: paramName);
      positionalIndex++;
    }
  }

  return WidgetNode(name: widgetName, args: args, key: key);
}

IrNode lowerWidgetInvocation(MethodInvocation expr, {Object? Function(InstanceCreationExpression)? constEvaluator}) {
  final widgetName = expr.methodName.name;
  final args = <String, IrNode>{};
  IrNode? key;

  final positionalParams = _positionalParams[widgetName] ?? const <String>[];

  var positionalIndex = 0;
  for (final a in expr.argumentList.arguments) {
    if (a is NamedArgument) {
      final name = a.name.lexeme;
      final value =
          _lowerArg(a.argumentExpression, constEvaluator: constEvaluator, paramName: name);
      if (name == 'key') {
        key = value;
      } else {
        args[name] = value;
      }
    } else {
      final paramName = positionalIndex < positionalParams.length
          ? positionalParams[positionalIndex]
          : 'arg$positionalIndex';
      args[paramName] =
          _lowerArg(a.argumentExpression, constEvaluator: constEvaluator, paramName: paramName);
      positionalIndex++;
    }
  }

  return WidgetNode(name: widgetName, args: args, key: key);
}

IrNode lowerListElement(CollectionElement el) {
  if (el is IfElement) {
    return _lowerIfElement(el);
  }
  if (el is ForElement) {
    return _lowerForElement(el);
  }
  if (el is SpreadElement) {
    return SpreadNode(lowerExpression(el.expression));
  }
  if (el is Expression) {
    return _lowerArg(el);
  }
  throw LoweringError('unsupported collection element: ${el.runtimeType}', el);
}

IrNode _lowerArg(Expression a, {Object? Function(InstanceCreationExpression)? constEvaluator, String? paramName}) {
  if (a is FunctionExpression) {
    return lowerClosure(a);
  }
  if (a is InstanceCreationExpression) {
    return lowerWidgetInstance(a, constEvaluator: constEvaluator);
  }
  if (a is MethodInvocation && a.target == null) {
    final name = a.methodName.name;
    if (name.isNotEmpty && name[0] == name[0].toUpperCase()) {
      return lowerWidgetInvocation(a, constEvaluator: constEvaluator);
    }
    return lowerClosure(a);
  }
  // Handle method tear-offs in callback positions: `onPressed: vm.increment`
  if ((a is PrefixedIdentifier || a is PropertyAccess) &&
      paramName != null &&
      _isCallbackParam(paramName)) {
    return lowerClosure(a);
  }
  // Static method call with a parameter reference as receiver, e.g.
  // `Theme.of(context)`, `MediaQuery.sizeOf(context)`.
  // Lowered to MethodCallNode with receiver: null (flat callable) so the
  // runtime dispatches via the function path, not instance-method path.
  if (a is MethodInvocation &&
      a.target is SimpleIdentifier &&
      _isUppercase((a.target as SimpleIdentifier).name) &&
      a.argumentList.arguments.isNotEmpty &&
      a.argumentList.arguments.first is SimpleIdentifier) {
    final className = (a.target as SimpleIdentifier).name;
    final methodName = a.methodName.name;
    final allArgs = <IrNode>[];
    for (final arg in a.argumentList.arguments) {
      allArgs.add(_lowerArg(arg as Expression, constEvaluator: constEvaluator));
    }
    return MethodCallNode(
      receiver: null,
      name: '$className.$methodName',
      args: allArgs,
    );
  }
  // Qualified static-factory / named-constructor call without `const` keyword:
  // e.g. `BorderRadius.circular(26)`, `EdgeInsets.all(8)`.
  // The unresolved parser produces a MethodInvocation with a SimpleIdentifier
  // target (the class name). If the target starts with an uppercase letter it
  // is a type name, and we treat the whole call as a value-ctor invocation so
  // it dispatches to the correct `registerValueBuilder` entry at runtime.
  if (a is MethodInvocation &&
      a.target is SimpleIdentifier &&
      _isUppercase((a.target as SimpleIdentifier).name)) {
    final className = (a.target as SimpleIdentifier).name;
    final methodName = a.methodName.name;
    final qualifiedName = '$className.$methodName';
    final args = <String, IrNode>{};
    IrNode? key;
    for (final arg in a.argumentList.arguments) {
      if (arg is NamedArgument) {
        final argName = arg.name.lexeme;
        final value =
            _lowerArg(arg.argumentExpression, constEvaluator: constEvaluator);
        if (argName == 'key') {
          key = value;
        } else {
          args[argName] = value;
        }
      } else {
        final i = args.length;
        args['arg$i'] =
            _lowerArg(arg.argumentExpression, constEvaluator: constEvaluator);
      }
    }
    return WidgetNode(name: qualifiedName, args: args, key: key);
  }
  if (a is ListLiteral) {
    return ListNode(
      a.elements.map((e) {
        if (e is IfElement) return _lowerIfElement(e, constEvaluator: constEvaluator);
        if (e is ForElement) return _lowerForElement(e, constEvaluator: constEvaluator);
        if (e is SpreadElement) {
          return SpreadNode(lowerExpression(e.expression));
        }
        return _lowerArg(e as Expression, constEvaluator: constEvaluator);
      }).toList(),
    );
  }
  if (a is MethodInvocation) {
    return lowerClosure(a);
  }
  // PropertyAccess chains like `Theme.of(context).colorScheme.primary`
  // need recursive lowering through _lowerArg (not lowerExpression) so
  // that embedded MethodInvocations are handled correctly.
  if (a is PropertyAccess) {
    final target = _lowerArg(a.target!, constEvaluator: constEvaluator);
    final bucket = coreTypeBucket(a.target!.staticType);
    if (target is RefNode && bucket == null) {
      return RefNode([...target.path, a.propertyName.name]);
    }
    if (bucket != null) {
      return GetterNode(
        receiver: target,
        name: '$bucket.${a.propertyName.name}',
      );
    }
    return MemberAccessNode(target: target, name: a.propertyName.name);
  }
  if (a is PrefixedIdentifier) {
    if (a.identifier.name == 'length') {
      return LengthOfNode(_lowerArg(a.prefix, constEvaluator: constEvaluator));
    }
    final target = _lowerArg(a.prefix, constEvaluator: constEvaluator);
    final bucket = coreTypeBucket(a.prefix.staticType);
    if (target is RefNode && bucket == null) {
      return RefNode([...target.path, a.identifier.name]);
    }
    if (bucket != null) {
      return GetterNode(
        receiver: target,
        name: '$bucket.${a.identifier.name}',
      );
    }
    return MemberAccessNode(target: target, name: a.identifier.name);
  }
  if (a is IndexExpression) {
    return IndexAccessNode(
      target: _lowerArg(a.target!, constEvaluator: constEvaluator),
      key: _lowerArg(a.index, constEvaluator: constEvaluator),
    );
  }
  if (a is BinaryExpression) {
    return lowerExpression(a);
  }
  if (a is ConditionalExpression) {
    return lowerExpression(a);
  }
  if (a is PrefixExpression) {
    return lowerExpression(a);
  }
  if (a is StringInterpolation) {
    return lowerExpression(a);
  }
  if (a is IntegerLiteral ||
      a is DoubleLiteral ||
      a is BooleanLiteral ||
      a is NullLiteral ||
      a is SimpleStringLiteral) {
    return lowerExpression(a);
  }
  if (a is SimpleIdentifier) {
    return RefNode([a.name]);
  }
  // Dot-shorthand constructor invocation: `.all(8)`, `.only(top: 16)`
  // The analyzer resolves these to the declaring class's constructor.
  if (a is DotShorthandConstructorInvocation) {
    final owner = _enclosingTypeName(a.constructorName.element);
    if (owner == null) {
      throw LoweringError('dot-shorthand constructor on unresolved element', a);
    }
    final args = _lowerDotShorthandArgs(a.argumentList, constEvaluator);
    return WidgetNode(name: '$owner.${a.constructorName.name}', args: args);
  }
  // Dot-shorthand method/factory invocation: `.smooth()`, `.scale(1.5)`
  if (a is DotShorthandInvocation) {
    final owner = _enclosingTypeName(a.memberName.element);
    if (owner == null) {
      throw LoweringError('dot-shorthand invocation on unresolved element', a);
    }
    final args = _lowerDotShorthandArgs(a.argumentList, constEvaluator);
    return WidgetNode(name: '$owner.${a.memberName.name}', args: args);
  }
  // Dot-shorthand property access: `.zero`, `.infinity`
  if (a is DotShorthandPropertyAccess) {
    final owner = _enclosingTypeName(a.propertyName.element);
    if (owner == null) {
      throw LoweringError('dot-shorthand property on unresolved element', a);
    }
    return WidgetNode(name: '$owner.${a.propertyName.name}', args: const {});
  }
  return lowerExpression(a);
}

IrNode _lowerIfElement(IfElement el, {Object? Function(InstanceCreationExpression)? constEvaluator}) {
  final cond = lowerExpression(el.expression);
  final thenWidget = _lowerCollectionElement(el.thenElement, constEvaluator: constEvaluator);
  final otherwise = el.elseElement == null
      ? null
      : _lowerCollectionElement(el.elseElement!, constEvaluator: constEvaluator);
  return ConditionalNode(
    condition: cond,
    thenBranch: thenWidget,
    elseBranch: otherwise,
  );
}

IrNode _lowerCollectionElement(CollectionElement el, {Object? Function(InstanceCreationExpression)? constEvaluator}) {
  if (el is IfElement) return _lowerIfElement(el, constEvaluator: constEvaluator);
  if (el is ForElement) return _lowerForElement(el, constEvaluator: constEvaluator);
  if (el is SpreadElement) {
    final expr = el.expression;
    if (expr is ListLiteral) {
      if (expr.elements.isEmpty) {
        return SpreadNode(ListNode([]));
      }
      final lowered = expr.elements.map((e) => _lowerCollectionElement(e, constEvaluator: constEvaluator)).toList();
      return SpreadNode(ListNode(lowered));
    }
    return SpreadNode(lowerExpression(expr));
  }
  if (el is Expression) {
    return _lowerArg(el, constEvaluator: constEvaluator);
  }
  throw LoweringError('unsupported collection element: ${el.runtimeType}', el);
}

IrNode _lowerForElement(ForElement el, {Object? Function(InstanceCreationExpression)? constEvaluator}) {
  final parts = el.forLoopParts;
  if (parts is ForEachPartsWithDeclaration) {
    final loopVar = parts.loopVariable.name.lexeme;
    final source = lowerExpression(parts.iterable);
    final body = _lowerForBody(el.body, constEvaluator: constEvaluator);
    return ForNode(variable: loopVar, source: source, body: body);
  }
  if (parts is ForEachPartsWithPattern) {
    final names = _extractPatternNames(parts.pattern);
    final source = lowerExpression(parts.iterable);
    final body = _lowerForBody(el.body, constEvaluator: constEvaluator);
    return ForNode.destructured(variables: names, source: source, body: body);
  }
  throw LoweringError('counter-style for not supported', el);
}

IrNode _lowerForBody(CollectionElement body, {Object? Function(InstanceCreationExpression)? constEvaluator}) {
  if (body is SpreadElement) {
    final expr = body.expression;
    if (expr is ListLiteral && expr.elements.length == 1) {
      final single = expr.elements.first;
      if (single is Expression) {
        return _lowerArg(single, constEvaluator: constEvaluator);
      }
    }
    return SpreadNode(lowerExpression(expr));
  }
  if (body is Expression) {
    return _lowerArg(body, constEvaluator: constEvaluator);
  }
  throw LoweringError('unsupported for body: ${body.runtimeType}', body);
}

String _ctorFullName(InstanceCreationExpression expr) {
  final ctor = expr.constructorName;
  // Use toSource() on the NamedType so that qualified forms like
  // `EdgeInsets.only` (where the unresolved parser encodes the class as an
  // importPrefix and `only` as the type name) are reconstructed correctly.
  // For simple types like `Color` or `TextStyle`, toSource() is identical to
  // name2.lexeme, so this is backward-compatible.
  final type = ctor.type.toSource();
  final name = ctor.name?.name;
  return name != null && name != type ? '$type.$name' : type;
}

bool _isConstFoldable(String ctor) {
  for (final c in _constCtors) {
    if (ctor == c || ctor.startsWith('$c.')) return true;
  }
  return false;
}

bool _isUppercase(String s) => s.isNotEmpty && s[0] == s[0].toUpperCase();

/// Returns true if [paramName] looks like a Flutter callback parameter
/// (starts with 'on' followed by an uppercase letter, e.g. 'onPressed').
bool _isCallbackParam(String paramName) =>
    paramName.length > 2 &&
    paramName.startsWith('on') &&
    paramName[2] == paramName[2].toUpperCase();

List<String> _extractPatternNames(DartPattern pat) {
  final names = <String>[];
  if (pat is RecordPattern) {
    for (final field in pat.fields) {
      final p = field.pattern;
      if (p is DeclaredVariablePattern) {
        names.add(p.name.lexeme);
      }
    }
  }
  return names;
}

String? _enclosingTypeName(Element? element) {
  if (element == null) return null;
  final enclosing = element.enclosingElement;
  if (enclosing is InterfaceElement) return enclosing.name;
  return null;
}

Map<String, IrNode> _lowerDotShorthandArgs(
  ArgumentList argList,
  Object? Function(InstanceCreationExpression)? constEvaluator,
) {
  final args = <String, IrNode>{};
  for (final a in argList.arguments) {
    if (a is NamedArgument) {
      args[a.name.lexeme] = _lowerArg(a.argumentExpression, constEvaluator: constEvaluator);
    } else {
      args['arg${args.length}'] = _lowerArg(a as Expression, constEvaluator: constEvaluator);
    }
  }
  return args;
}
