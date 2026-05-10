import 'package:analyzer/dart/ast/ast.dart';
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

  final widgetName = ctorName.split('.').first;
  final args = <String, IrNode>{};
  IrNode? key;

  final positionalParams = _positionalParams[widgetName] ?? const <String>[];

  var positionalIndex = 0;
  for (final a in expr.argumentList.arguments) {
    if (a is NamedExpression) {
      final name = a.name.label.name;
      final value = _lowerArg(a.expression, constEvaluator: constEvaluator);
      if (name == 'key') {
        key = value;
      } else {
        args[name] = value;
      }
    } else {
      final paramName = positionalIndex < positionalParams.length
          ? positionalParams[positionalIndex]
          : 'arg$positionalIndex';
      args[paramName] = _lowerArg(a, constEvaluator: constEvaluator);
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
    if (a is NamedExpression) {
      final name = a.name.label.name;
      final value = _lowerArg(a.expression, constEvaluator: constEvaluator);
      if (name == 'key') {
        key = value;
      } else {
        args[name] = value;
      }
    } else {
      final paramName = positionalIndex < positionalParams.length
          ? positionalParams[positionalIndex]
          : 'arg$positionalIndex';
      args[paramName] = _lowerArg(a, constEvaluator: constEvaluator);
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

IrNode _lowerArg(Expression a, {Object? Function(InstanceCreationExpression)? constEvaluator}) {
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
      final lowered = expr.elements.map((e) => _lowerCollectionElement(e as CollectionElement, constEvaluator: constEvaluator)).toList();
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
  final type = ctor.type.name2.lexeme;
  final name = ctor.name?.name;
  return name != null && name != type ? '$type.$name' : type;
}

bool _isConstFoldable(String ctor) {
  for (final c in _constCtors) {
    if (ctor == c || ctor.startsWith('$c.')) return true;
  }
  return false;
}

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
