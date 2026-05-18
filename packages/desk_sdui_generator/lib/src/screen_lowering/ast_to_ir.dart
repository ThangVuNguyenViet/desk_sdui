import 'package:analyzer/dart/ast/ast.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import '../allowlist/verifier.dart';
import '../diagnostics.dart';
import 'widget_lowerer.dart';
import 'expression_lowerer.dart';

// ---------------------------------------------------------------------------
// Payload function name registry (module-level, reset per screen lowering)
// ---------------------------------------------------------------------------

/// Set of payload function names visible in the current screen file.
/// Populated by [lowerScreenWithPayloadFunctions] before lowering the screen
/// body; reset to empty after. Consulted by [lowerExpressionOrWidget] and the
/// expression lowerer's free-call interception to emit [PayloadFunctionCallNode]
/// instead of a registered-method dispatch.
final Set<String> _payloadFnNames = {};

/// Set of payload class names visible in the current screen file.
final Set<String> _payloadClassNames = {};

/// Returns true if [name] is a payload function declared in the current file.
bool isPayloadFn(String name) => _payloadFnNames.contains(name);

/// Returns true if [name] is a payload class declared in the current file.
bool isPayloadClass(String name) => _payloadClassNames.contains(name);

// ---------------------------------------------------------------------------
// Payload class context (module-level, set when lowering method bodies)
// ---------------------------------------------------------------------------

/// Field names of the payload class whose method body is currently being
/// lowered. Empty when not inside a payload method.
final Set<String> _currentPayloadClassFields = {};

/// Method names of the payload class whose method body is currently being
/// lowered. Empty when not inside a payload method.
final Set<String> _currentPayloadClassMethods = {};

/// Returns true if [name] is a field on the payload class currently being
/// lowered.
bool isPayloadClassField(String name) => _currentPayloadClassFields.contains(name);

/// Returns true if [name] is a method on the payload class currently being
/// lowered.
bool isPayloadClassMethod(String name) => _currentPayloadClassMethods.contains(name);

class ScreenLowerResult {
  ScreenLowerResult({
    required this.name,
    required this.root,
    required this.params,
    required this.reactiveParams,
    required this.methodRefs,
    required this.widgetRefs,
    required this.fnRefs,
  });

  final String name;
  final IrNode root;
  final List<({String name, String type})> params;
  final List<String> reactiveParams;

  /// Method references indexed by input name.
  /// e.g. `{'vm': ['increment', 'decrement']}`
  final Map<String, List<String>> methodRefs;
  final Set<String> widgetRefs;
  final Set<String> fnRefs;

  ScreenLowerResult copyWith({IrNode? root}) {
    return ScreenLowerResult(
      name: name,
      root: root ?? this.root,
      params: params,
      reactiveParams: reactiveParams,
      methodRefs: methodRefs,
      widgetRefs: widgetRefs,
      fnRefs: fnRefs,
    );
  }
}

class ScreenAnnotationData {
  ScreenAnnotationData({required this.name});
  final String name;
}

ScreenLowerResult lowerScreen(FunctionDeclaration fn, ScreenAnnotationData ann) {
  final body = fn.functionExpression.body;
  final IrNode rootIr;
  if (body is ExpressionFunctionBody) {
    rootIr = _lowerExpression(body.expression);
  } else if (body is BlockFunctionBody) {
    rootIr = _lowerBlockBody(body, fn, ann);
  } else {
    throw LoweringError(
      '@Screen body must be a single return statement or expression body; '
      'got ${body.runtimeType}',
      fn,
    );
  }

  final params = <({String name, String type})>[];
  for (final p in fn.functionExpression.parameters!.parameters) {
    final paramName = p.name!.lexeme;
    final paramType = 'dynamic';
    params.add((name: paramName, type: paramType));
  }

  final reactiveParams = <String>[];
  final widgetRefs = <String>{};
  final methodRefs = <String, List<String>>{};
  final fnRefs = <String>{};

  _collectRefs(rootIr, widgetRefs, methodRefs, fnRefs);

  return ScreenLowerResult(
    name: ann.name,
    root: rootIr,
    params: params,
    reactiveParams: reactiveParams,
    methodRefs: methodRefs,
    widgetRefs: widgetRefs,
    fnRefs: fnRefs,
  );
}

/// Lowers a @Screen alongside any payload-private top-level functions declared
/// in [unit]. Non-@Screen top-level function declarations are collected as
/// [PayloadFunctionNode]s; call sites in the screen body (and in other payload
/// functions) are lowered to [PayloadFunctionCallNode]s. If no payload
/// functions are present the result is identical to calling [lowerScreen].
ScreenLowerResult lowerScreenWithPayloadFunctions(
  CompilationUnit unit,
  FunctionDeclaration screenFn,
  ScreenAnnotationData ann,
) {
  // Step 1: collect payload function, class, and mixin names (pre-pass so
  // call sites can be resolved before we lower the bodies).
  _payloadFnNames.clear();
  _payloadClassNames.clear();
  final Set<String> _payloadMixinNames = {};
  for (final decl in unit.declarations) {
    if (decl is FunctionDeclaration && decl.name.lexeme != screenFn.name.lexeme) {
      _payloadFnNames.add(decl.name.lexeme);
    }
    if (decl is ClassDeclaration) {
      _payloadClassNames.add(_classDeclName(decl));
    }
    if (decl is MixinDeclaration) {
      _payloadMixinNames.add(_mixinDeclName(decl));
    }
  }

  try {
    // Step 2: lower the screen body (payload fn/class call sites are
    // intercepted by isPayloadFn / isPayloadClass checks).
    final screenResult = lowerScreen(screenFn, ann);

    final hasPayloadFns = _payloadFnNames.isNotEmpty;
    final hasPayloadClasses = _payloadClassNames.isNotEmpty;
    final hasPayloadMixins = _payloadMixinNames.isNotEmpty;

    if (!hasPayloadFns && !hasPayloadClasses && !hasPayloadMixins) {
      return screenResult;
    }

    // Step 3: lower each payload function body.
    final payloadFns = <PayloadFunctionNode>[];
    final declByName = <String, FunctionDeclaration>{};
    for (final decl in unit.declarations) {
      if (decl is FunctionDeclaration &&
          decl.name.lexeme != screenFn.name.lexeme) {
        declByName[decl.name.lexeme] = decl;
        payloadFns.add(_lowerPayloadFunctionDecl(decl));
      }
    }

    // Step 4: lower each payload class declaration.
    final payloadClasses = <PayloadClassNode>[];
    for (final decl in unit.declarations) {
      if (decl is ClassDeclaration) {
        payloadClasses.add(_lowerPayloadClassDecl(decl));
      }
    }

    // Step 4b: lower each payload mixin declaration.
    final payloadMixins = <PayloadMixinNode>[];
    for (final decl in unit.declarations) {
      if (decl is MixinDeclaration) {
        payloadMixins.add(_lowerPayloadMixinDecl(decl));
      }
    }

    // Step 4c: lower each payload extension declaration.
    final payloadExtensions = <PayloadExtensionNode>[];
    for (final decl in unit.declarations) {
      if (decl is ExtensionDeclaration) {
        payloadExtensions.add(_lowerPayloadExtensionDecl(decl));
      }
    }

    // Step 5 (allowlist invariant): walk each payload function body and
    // confirm every leaf call is either (a) another payload function in the
    // same file, OR (b) a registered global.
    for (final fn in payloadFns) {
      _walkAllowlist(
        fn.body,
        payloadFnName: fn.name,
        decl: declByName[fn.name]!,
      );
    }

    // Step 5b (extended allowlist verifier): run the comprehensive verifier
    // over all payload function and method bodies.
    final registry = RegistryIndex(
      payloadFunctionNames: _payloadFnNames,
      payloadClassNames: _payloadClassNames,
      payloadMixinNames: _payloadMixinNames,
    );
    for (final fn in payloadFns) {
      final violations = verifyAllowlist(
        fn.body,
        registry,
        payloadFnName: fn.name,
        decl: declByName[fn.name],
      );
      if (violations.isNotEmpty) {
        throw LoweringError(
          'Allowlist violations in payload function "${fn.name}":\n'
          '${violations.map((v) => '  - ${v.message}').join('\n')}',
          declByName[fn.name]!,
        );
      }
    }

    // Step 6: wrap the screen body.
    final wrapped = ScreenWithFunctionsNode(
      functions: payloadFns,
      classes: payloadClasses,
      mixins: payloadMixins,
      extensions: payloadExtensions,
      screenBody: screenResult.root,
    );
    return screenResult.copyWith(root: wrapped);
  } finally {
    _payloadFnNames.clear();
    _payloadClassNames.clear();
  }
}

/// Lowers a top-level function declaration to a [PayloadFunctionNode].
/// Rejects async functions and unsupported body shapes.
PayloadFunctionNode _lowerPayloadFunctionDecl(FunctionDeclaration decl) {
  final fn = decl.functionExpression;

  // Reject async.
  if (fn.body.isAsynchronous) {
    throw LoweringError(
      'Payload functions must be synchronous. '
      'Declare "${decl.name.lexeme}" without `async`; '
      'use an action handler for async work.',
      decl,
    );
  }

  // Collect params.
  final params = fn.parameters?.parameters
          .map((p) => p.name!.lexeme)
          .toList() ??
      const <String>[];

  // Lower body.
  final body = fn.body;
  final IrNode lowered;
  if (body is ExpressionFunctionBody) {
    lowered = lowerExpressionOrWidget(body.expression);
  } else if (body is BlockFunctionBody) {
    // Collect var bindings in the function block for scope tracking.
    final bindings = <String, BindingKind>{};
    for (final p in params) {
      bindings[p] = BindingKind.finalBinding; // params are read-only
    }
    for (final stmt in body.block.statements) {
      if (stmt is VariableDeclarationStatement) {
        for (final v in stmt.variables.variables) {
          bindings[v.name.lexeme] = stmt.variables.isFinal
              ? BindingKind.finalBinding
              : BindingKind.varBinding;
        }
      }
    }
    pushScope(bindings);
    try {
      lowered = BlockNode(
        statements: body.block.statements.map(lowerStatement).toList(),
      );
    } finally {
      popScope();
    }
  } else {
    throw LoweringError(
      'Payload functions must have an expression or block body. '
      'Got: ${body.runtimeType}',
      decl,
    );
  }

  return PayloadFunctionNode(
    name: decl.name.lexeme,
    params: params,
    body: lowered,
  );
}

/// Lowers a [ClassDeclaration] to a [PayloadClassNode].
PayloadClassNode _lowerPayloadClassDecl(ClassDeclaration decl) {
  final className = _classDeclName(decl);

  // Reject unsupported modifiers.
  if (decl.abstractKeyword != null) {
    throw LoweringError(
      'Payload classes cannot be abstract.',
      decl,
    );
  }
  if (decl.sealedKeyword != null) {
    throw LoweringError(
      'Payload classes cannot be sealed.',
      decl,
    );
  }

  // Resolve supertype.
  String? supertypeName;
  final extendsClause = decl.extendsClause;
  if (extendsClause != null) {
    final name = extendsClause.superclass.name.lexeme;
    if (name != 'Object') {
      supertypeName = name;
    }
  }

  // Resolve mixins.
  final mixinNames = <String>[];
  final withClause = decl.withClause;
  if (withClause != null) {
    for (final mixin in withClause.mixinTypes) {
      mixinNames.add(mixin.name.lexeme);
    }
  }

  // Collect fields.
  final fields = <PayloadFieldDeclNode>[];
  final ctors = <PayloadCtorNode>[];
  final methods = <PayloadFunctionNode>[];

  for (final member in decl.body.members) {
    if (member is FieldDeclaration) {
      if (member.isStatic) {
        throw LoweringError(
          'Static fields are not supported in payload classes.',
          member,
        );
      }
      for (final varDecl in member.fields.variables) {
        final initializer = varDecl.initializer;
        fields.add(PayloadFieldDeclNode(
          name: varDecl.name.lexeme,
          initializer: initializer != null ? lowerExpression(initializer) : null,
          isFinal: member.fields.isFinal,
        ));
      }
    } else if (member is ConstructorDeclaration) {
      if (member.factoryKeyword != null) {
        throw LoweringError(
          'Factory constructors are not supported in payload classes.',
          member,
        );
      }
      if (member.constKeyword != null) {
        throw LoweringError(
          'Const constructors are not supported in payload classes.',
          member,
        );
      }
      final params = <String>[];
      final fieldInits = <PayloadFieldInitNode>[];
      for (final param in member.parameters.parameters) {
        if (param is FieldFormalParameter) {
          final pName = param.name.lexeme;
          params.add(pName);
          fieldInits.add(PayloadFieldInitNode(
            fieldName: pName,
            value: RefNode([pName]),
          ));
        } else if (param is RegularFormalParameter) {
          params.add(param.name!.lexeme);
        }
      }
      final body = member.body;
      IrNode? ctorBody;
      if (body is ExpressionFunctionBody) {
        ctorBody = lowerExpression(body.expression);
      } else if (body is BlockFunctionBody) {
        ctorBody = BlockNode(
          statements: body.block.statements.map(lowerStatement).toList(),
        );
      }
      ctors.add(PayloadCtorNode(
        name: member.name?.lexeme ?? '',
        params: params,
        fieldInits: fieldInits,
        body: ctorBody,
      ));
    } else if (member is MethodDeclaration) {
      if (member.isStatic) {
        throw LoweringError(
          'Static methods are not supported in payload classes.',
          member,
        );
      }
      final params = <String>[];
      for (final param in member.parameters?.parameters ?? <FormalParameter>[]) {
        params.add(param.name!.lexeme);
      }
      final body = member.body;
      IrNode? loweredBody;
      if (body is ExpressionFunctionBody) {
        loweredBody = lowerExpression(body.expression);
      } else if (body is BlockFunctionBody) {
        loweredBody = BlockNode(
          statements: body.block.statements.map(lowerStatement).toList(),
        );
      }
      methods.add(PayloadFunctionNode(
        name: member.name.lexeme,
        params: params,
        body: loweredBody!,
      ));
    }
  }

  return PayloadClassNode(
    name: className,
    supertypeName: supertypeName,
    mixinNames: mixinNames,
    fields: fields,
    ctors: ctors,
    methods: methods,
  );
}

/// Lowers a [MixinDeclaration] to a [PayloadMixinNode].
PayloadMixinNode _lowerPayloadMixinDecl(MixinDeclaration decl) {
  final mixinName = _mixinDeclName(decl);

  // Resolve on-types.
  final onTypes = <String>[];
  final onClause = decl.onClause;
  if (onClause != null) {
    for (final type in onClause.superclassConstraints) {
      onTypes.add(type.name.lexeme);
    }
  }

  // Collect fields and methods.
  final fields = <PayloadFieldDeclNode>[];
  final methods = <PayloadFunctionNode>[];

  for (final member in decl.body.members) {
    if (member is FieldDeclaration) {
      if (member.isStatic) {
        throw LoweringError(
          'Static fields are not supported in payload mixins.',
          member,
        );
      }
      for (final varDecl in member.fields.variables) {
        final initializer = varDecl.initializer;
        fields.add(PayloadFieldDeclNode(
          name: varDecl.name.lexeme,
          initializer: initializer != null ? lowerExpression(initializer) : null,
          isFinal: member.fields.isFinal,
        ));
      }
    } else if (member is MethodDeclaration) {
      if (member.isStatic) {
        throw LoweringError(
          'Static methods are not supported in payload mixins.',
          member,
        );
      }
      final params = <String>[];
      for (final param in member.parameters?.parameters ?? <FormalParameter>[]) {
        params.add(param.name!.lexeme);
      }
      final body = member.body;
      IrNode? loweredBody;
      if (body is ExpressionFunctionBody) {
        loweredBody = lowerExpression(body.expression);
      } else if (body is BlockFunctionBody) {
        loweredBody = BlockNode(
          statements: body.block.statements.map(lowerStatement).toList(),
        );
      }
      methods.add(PayloadFunctionNode(
        name: member.name.lexeme,
        params: params,
        body: loweredBody!,
      ));
    }
  }

  return PayloadMixinNode(
    name: mixinName,
    onTypes: onTypes,
    fields: fields,
    methods: methods,
  );
}

/// Extracts the mixin name from a [MixinDeclaration].
String _mixinDeclName(MixinDeclaration decl) {
  return decl.name.lexeme;
}

/// Lowers an [ExtensionDeclaration] to a [PayloadExtensionNode].
PayloadExtensionNode _lowerPayloadExtensionDecl(ExtensionDeclaration decl) {
  final name = decl.name?.lexeme ?? '_extension';
  final onClause = decl.onClause;
  final targetTypeName = onClause != null
      ? (onClause.extendedType is NamedType
          ? (onClause.extendedType as NamedType).name.lexeme
          : 'dynamic')
      : 'dynamic';

  final methods = <PayloadFunctionNode>[];
  for (final member in decl.body.members) {
    if (member is MethodDeclaration) {
      if (member.isStatic) {
        throw LoweringError(
          'Static methods are not supported in payload extensions.',
          member,
        );
      }
      final params = <String>[];
      for (final param in member.parameters?.parameters ?? <FormalParameter>[]) {
        params.add(param.name!.lexeme);
      }
      final body = member.body;
      IrNode? loweredBody;
      if (body is ExpressionFunctionBody) {
        loweredBody = lowerExpression(body.expression);
      } else if (body is BlockFunctionBody) {
        loweredBody = BlockNode(
          statements: body.block.statements.map(lowerStatement).toList(),
        );
      }
      methods.add(PayloadFunctionNode(
        name: member.name.lexeme,
        params: params,
        body: loweredBody!,
      ));
    }
  }

  return PayloadExtensionNode(
    name: name,
    targetTypeName: targetTypeName,
    methods: methods,
  );
}

// ---------------------------------------------------------------------------
// Allowlist invariant walk for payload function bodies
// ---------------------------------------------------------------------------

/// Walks [body] recursively and rejects any leaf call that is not allowed
/// inside a payload function. The plan defines the allowlist as:
///
/// - Another payload function declared in the same file (represented in IR
///   as a [PayloadFunctionCallNode]), OR
/// - A registered global — a registered method/widget/value-ctor/static
///   function. In IR these surface as [MethodCallNode] (with a non-null
///   receiver for instance methods, or null receiver for static methods like
///   `Theme.of(context)`), [ValueCtorNode], or [WidgetNode]/[BuiltinWidgetNode].
///
/// A bare [MethodCallNode] with `receiver == null` whose name is lowercase
/// is the structural marker of an unregistered free-function call that
/// somehow leaked past the lowerer's free-call interceptors — emit the
/// plan's documented diagnostic.
void _walkAllowlist(
  IrNode node, {
  required String payloadFnName,
  required AstNode decl,
}) {
  switch (node) {
    case MethodCallNode():
      if (node.receiver == null) {
        final name = node.name;
        // Static methods qualify their class (e.g. `Theme.of`, `MediaQuery.sizeOf`)
        // — name contains a `.` and the class segment is uppercase. Those are
        // registered globals and allowed.
        final isQualifiedStatic = name.contains('.') &&
            name.isNotEmpty &&
            name[0] == name[0].toUpperCase();
        final isPlainLowercase = !name.contains('.') &&
            name.isNotEmpty &&
            name[0] == name[0].toLowerCase();
        if (isPlainLowercase && !_payloadFnNames.contains(name)) {
          throw LoweringError(
            'Payload function "$payloadFnName" calls "$name" which is '
            'neither a registered global nor another payload function in '
            'this file. Payload functions can only compose already-registered '
            'behavior.',
            decl,
          );
        }
        // Either a qualified static call (Theme.of) or a registered free
        // function — both allowed.
        // Sanity: if neither plain-lowercase nor qualified-static, fall through.
        if (!isQualifiedStatic && !isPlainLowercase) {
          // Unrecognized shape — be conservative and reject.
          throw LoweringError(
            'Payload function "$payloadFnName" calls "$name" which is '
            'neither a registered global nor another payload function in '
            'this file. Payload functions can only compose already-registered '
            'behavior.',
            decl,
          );
        }
      }
      // Recurse into args/receiver.
      if (node.receiver != null) {
        _walkAllowlist(node.receiver!,
            payloadFnName: payloadFnName, decl: decl);
      }
      for (final arg in node.args) {
        _walkAllowlist(arg, payloadFnName: payloadFnName, decl: decl);
      }

    case PayloadFunctionCallNode():
      // Always allowed (resolved against _payloadFnNames at lowering time).
      for (final arg in node.args) {
        _walkAllowlist(arg, payloadFnName: payloadFnName, decl: decl);
      }

    case WidgetNode():
      for (final child in node.args.values) {
        _walkAllowlist(child, payloadFnName: payloadFnName, decl: decl);
      }
      if (node.key != null) {
        _walkAllowlist(node.key!, payloadFnName: payloadFnName, decl: decl);
      }
    case BuiltinWidgetNode():
      for (final child in node.args.values) {
        _walkAllowlist(child, payloadFnName: payloadFnName, decl: decl);
      }
      if (node.key != null) {
        _walkAllowlist(node.key!, payloadFnName: payloadFnName, decl: decl);
      }
    case ValueCtorNode():
      for (final arg in node.args) {
        _walkAllowlist(arg, payloadFnName: payloadFnName, decl: decl);
      }
    case ListNode():
      for (final c in node.children) {
        _walkAllowlist(c, payloadFnName: payloadFnName, decl: decl);
      }
    case MapNode():
      for (final e in node.entries.entries) {
        _walkAllowlist(e.key, payloadFnName: payloadFnName, decl: decl);
        _walkAllowlist(e.value, payloadFnName: payloadFnName, decl: decl);
      }
    case RecordNode():
      for (final c in node.positional) {
        _walkAllowlist(c, payloadFnName: payloadFnName, decl: decl);
      }
      for (final c in node.named.values) {
        _walkAllowlist(c, payloadFnName: payloadFnName, decl: decl);
      }
    case ConditionalNode():
      _walkAllowlist(node.condition,
          payloadFnName: payloadFnName, decl: decl);
      _walkAllowlist(node.thenBranch,
          payloadFnName: payloadFnName, decl: decl);
      if (node.elseBranch != null) {
        _walkAllowlist(node.elseBranch!,
            payloadFnName: payloadFnName, decl: decl);
      }
    case ForNode():
      _walkAllowlist(node.source, payloadFnName: payloadFnName, decl: decl);
      _walkAllowlist(node.body, payloadFnName: payloadFnName, decl: decl);
    case SpreadNode():
      _walkAllowlist(node.source, payloadFnName: payloadFnName, decl: decl);
    case CompareOpNode(:final left, :final right):
      _walkAllowlist(left, payloadFnName: payloadFnName, decl: decl);
      _walkAllowlist(right, payloadFnName: payloadFnName, decl: decl);
    case ArithOpNode(:final left, :final right):
      _walkAllowlist(left, payloadFnName: payloadFnName, decl: decl);
      _walkAllowlist(right, payloadFnName: payloadFnName, decl: decl);
    case LogicOpNode(:final left, :final right):
      _walkAllowlist(left, payloadFnName: payloadFnName, decl: decl);
      _walkAllowlist(right, payloadFnName: payloadFnName, decl: decl);
    case CoalesceOpNode(:final left, :final right):
      _walkAllowlist(left, payloadFnName: payloadFnName, decl: decl);
      _walkAllowlist(right, payloadFnName: payloadFnName, decl: decl);
    case NotOpNode():
      _walkAllowlist(node.operand,
          payloadFnName: payloadFnName, decl: decl);
    case GetterNode():
      _walkAllowlist(node.receiver,
          payloadFnName: payloadFnName, decl: decl);
    case SetterCallNode():
      _walkAllowlist(node.target,
          payloadFnName: payloadFnName, decl: decl);
      _walkAllowlist(node.value,
          payloadFnName: payloadFnName, decl: decl);
    case LetNode():
      _walkAllowlist(node.value, payloadFnName: payloadFnName, decl: decl);
      _walkAllowlist(node.body, payloadFnName: payloadFnName, decl: decl);
    case AssignNode():
      _walkAllowlist(node.value, payloadFnName: payloadFnName, decl: decl);
    case SequenceNode():
      for (final s in node.steps) {
        _walkAllowlist(s, payloadFnName: payloadFnName, decl: decl);
      }
      _walkAllowlist(node.returnExpr,
          payloadFnName: payloadFnName, decl: decl);
    case LambdaNode():
      _walkAllowlist(node.body, payloadFnName: payloadFnName, decl: decl);
    case MemberAccessNode():
      _walkAllowlist(node.target,
          payloadFnName: payloadFnName, decl: decl);
    case IndexAccessNode():
      _walkAllowlist(node.target,
          payloadFnName: payloadFnName, decl: decl);
      _walkAllowlist(node.key, payloadFnName: payloadFnName, decl: decl);
    case LengthOfNode():
      _walkAllowlist(node.target,
          payloadFnName: payloadFnName, decl: decl);
    case IsNullCheckNode():
      _walkAllowlist(node.operand,
          payloadFnName: payloadFnName, decl: decl);
    case IsTypeNode():
      _walkAllowlist(node.receiver,
          payloadFnName: payloadFnName, decl: decl);
    case AsTypeNode():
      _walkAllowlist(node.operand, payloadFnName: payloadFnName, decl: decl);
    case RuntimeTypeRefNode():
      _walkAllowlist(node.operand, payloadFnName: payloadFnName, decl: decl);
    case PayloadMethodCallNode():
      _walkAllowlist(node.receiver, payloadFnName: payloadFnName, decl: decl);
      for (final arg in node.args.values) {
        _walkAllowlist(arg, payloadFnName: payloadFnName, decl: decl);
      }
    case PayloadFieldRefNode():
      _walkAllowlist(node.receiver, payloadFnName: payloadFnName, decl: decl);
    case PayloadFieldAssignNode():
      _walkAllowlist(node.receiver, payloadFnName: payloadFnName, decl: decl);
      _walkAllowlist(node.value, payloadFnName: payloadFnName, decl: decl);
    case ThisFieldRefNode():
    case ThisRefNode():
      break;
    case StringInterpNode():
      for (final p in node.parts) {
        if (p is IrNode) {
          _walkAllowlist(p, payloadFnName: payloadFnName, decl: decl);
        }
      }
    case BlockNode():
      for (final s in node.statements) {
        _walkAllowlist(s, payloadFnName: payloadFnName, decl: decl);
      }
    case IfStatementNode():
      _walkAllowlist(node.cond, payloadFnName: payloadFnName, decl: decl);
      _walkAllowlist(node.then, payloadFnName: payloadFnName, decl: decl);
      if (node.else_ != null) {
        _walkAllowlist(node.else_!,
            payloadFnName: payloadFnName, decl: decl);
      }
    case ReturnNode():
      if (node.value != null) {
        _walkAllowlist(node.value!,
            payloadFnName: payloadFnName, decl: decl);
      }
    case LetStatementNode():
      _walkAllowlist(node.value, payloadFnName: payloadFnName, decl: decl);
    case WhileNode():
      _walkAllowlist(node.condition,
          payloadFnName: payloadFnName, decl: decl);
      _walkAllowlist(node.body, payloadFnName: payloadFnName, decl: decl);
    case DoNode():
      _walkAllowlist(node.body, payloadFnName: payloadFnName, decl: decl);
      _walkAllowlist(node.condition,
          payloadFnName: payloadFnName, decl: decl);
    case ImperativeForNode():
      if (node.init != null) {
        _walkAllowlist(node.init!,
            payloadFnName: payloadFnName, decl: decl);
      }
      if (node.condition != null) {
        _walkAllowlist(node.condition!,
            payloadFnName: payloadFnName, decl: decl);
      }
      if (node.update != null) {
        _walkAllowlist(node.update!,
            payloadFnName: payloadFnName, decl: decl);
      }
      _walkAllowlist(node.body, payloadFnName: payloadFnName, decl: decl);
    case IrStatefulNode():
      for (final f in node.fields) {
        _walkAllowlist(f.initializer,
            payloadFnName: payloadFnName, decl: decl);
      }
      _walkAllowlist(node.body, payloadFnName: payloadFnName, decl: decl);
    case IrStatefulFieldNode():
      _walkAllowlist(node.initializer,
          payloadFnName: payloadFnName, decl: decl);
    case PayloadFunctionNode():
    case ScreenWithFunctionsNode():
      // Nested payload-function declarations / screens are not produced by
      // the lowerer inside a function body; nothing to do.
      break;
    case PayloadClassNode():
      // Payload class declarations are not produced inside function bodies.
      break;
    case PayloadMixinNode():
      // Payload mixin declarations are not produced inside function bodies.
      break;
    case PayloadExtensionNode():
      // Payload extension declarations are not produced inside function bodies.
      break;
    case PayloadFunctionValueNode():
      // Payload function values are not produced inside function bodies.
      break;
    case PayloadInstanceCreationNode():
      // Constructor call site: walk args for nested call validation.
      for (final arg in node.args.values) {
        _walkAllowlist(arg, payloadFnName: payloadFnName, decl: decl);
      }
    case PayloadFieldDeclNode():
      // Field declarations are metadata; handled at class level.
      if (node.initializer != null) {
        _walkAllowlist(node.initializer!, payloadFnName: payloadFnName, decl: decl);
      }
    case PayloadCtorNode():
      // Constructor parameters and body.
      for (final fieldInit in node.fieldInits) {
        _walkAllowlist(fieldInit, payloadFnName: payloadFnName, decl: decl);
      }
      if (node.body != null) {
        _walkAllowlist(node.body!, payloadFnName: payloadFnName, decl: decl);
      }
    case PayloadFieldInitNode():
      _walkAllowlist(node.value, payloadFnName: payloadFnName, decl: decl);
    case EventNode():
    case ActionSequenceNode():
    case ActionStepNode():
    case TryStepNode():
      // Action-form nodes are not produced inside payload-function bodies
      // (sync only). Skip without descent.
      break;
    case LiteralNode():
    case ConstNode():
    case RefNode():
    case BreakNode():
    case ContinueNode():
      // Leaves with no calls.
      break;
  }
}

IrNode _lowerExpression(Expression expr) => lowerExpressionOrWidget(expr);

/// Dispatches an [Expression] to either the widget lowerer (for widget
/// constructors and capitalized factory invocations) or the regular
/// expression lowerer. Exposed so that lowerers in other files (e.g. the
/// switch-expression lowerer in `expression_lowerer.dart`) can lower bodies
/// that may contain widgets.
IrNode lowerExpressionOrWidget(Expression expr) {
  if (expr is InstanceCreationExpression) {
    return lowerWidgetInstance(expr);
  } else if (expr is MethodInvocation && expr.target == null) {
    final name = expr.methodName.name;
    // Payload function call takes priority over widget/registered dispatch.
    if (_payloadFnNames.contains(name)) {
      return PayloadFunctionCallNode(
        name: name,
        args: expr.argumentList.arguments
            .map((a) => lowerExpressionOrWidget(a.argumentExpression))
            .toList(),
      );
    }
    if (name.isNotEmpty && name[0] == name[0].toUpperCase()) {
      return lowerWidgetInvocation(expr);
    } else {
      return lowerExpression(expr);
    }
  } else {
    return lowerExpression(expr);
  }
}

IrNode _lowerBlockBody(
    BlockFunctionBody body, FunctionDeclaration fn, ScreenAnnotationData ann) {
  final stmts = body.block.statements;
  if (stmts.isEmpty) {
    throw LoweringError(
      '@Screen body must end with a return statement.',
      fn,
    );
  }

  // Detect whether this is a "simple" body (old path: (VarDecl)* ExprStmt*
  // ReturnStmt) or a "block" body that requires the new BlockNode path. The
  // new path is taken whenever any statement is NOT a VarDecl / ExprStmt /
  // ReturnStmt (e.g. IfStatement, nested Block, BreakStatement, etc.).
  final hasComplexStatement = stmts.any(
    (s) =>
        s is! VariableDeclarationStatement &&
        s is! ExpressionStatement &&
        s is! ReturnStatement,
  );

  if (hasComplexStatement) {
    // New block-body path: lower all statements to a BlockNode.
    return _lowerGeneralBlock(stmts);
  }

  // Legacy simple path: (VarDecl)* ExpressionStatement* ReturnStatement.
  // Kept for backward compatibility with existing screens. New screens
  // that only have var decls + assignments + return will still use this path.
  final returnStmt = stmts.last;
  if (returnStmt is! ReturnStatement || returnStmt.expression == null) {
    throw LoweringError(
      '@Screen body must end with a return statement.',
      fn,
    );
  }

  // Feature 11 (IrStatefulNode): a *leading run* of `var`-decl statements
  // lowers to cross-build State<> fields, not LetNodes. The first non-`var`
  // statement (a `final` decl, ExpressionStatement, etc.) ends the field run.
  // After that, the remaining locals + the return lower normally to a LetNode
  // chain, then we wrap the result in an IrStatefulNode if any fields were
  // collected.
  final statefulFields = <IrStatefulFieldNode>[];
  var i = 0;
  while (i < stmts.length - 1) {
    final s = stmts[i];
    if (s is! VariableDeclarationStatement) break;
    if (s.variables.isFinal) break;
    if (s.variables.variables.length != 1) break;
    final v = s.variables.variables.single;
    if (v.initializer == null) break;
    final name = v.name.lexeme;
    if (name.startsWith('__')) {
      throw LoweringError(
        'Local name "$name" is reserved: names beginning with "__" are '
        'used internally by the lowerer. Pick a different name.',
        v,
      );
    }
    statefulFields.add(IrStatefulFieldNode(
      name: name,
      initializer: lowerExpression(v.initializer!),
      isFinal: false,
    ));
    i++;
  }

  // First pass — collect binding kinds for every declared local. The stateful
  // fields are seeded as varBindings so AssignNode is allowed against them.
  final bindings = <String, BindingKind>{};
  for (final f in statefulFields) {
    bindings[f.name] = BindingKind.varBinding;
  }
  for (final stmt in stmts.skip(i).take(stmts.length - 1 - i)) {
    if (stmt is VariableDeclarationStatement) {
      final decl = stmt.variables;
      for (final v in decl.variables) {
        final name = v.name.lexeme;
        if (name.startsWith('__')) {
          throw LoweringError(
            'Local name "$name" is reserved: names beginning with "__" are '
            'used internally by the lowerer. Pick a different name.',
            v,
          );
        }
        bindings[name] =
            decl.isFinal ? BindingKind.finalBinding : BindingKind.varBinding;
      }
    }
  }

  pushScope(bindings);
  try {
    IrNode acc = _lowerExpression(returnStmt.expression!);
    // Iterate the *trailing* statements (after the stateful-fields run) in
    // reverse, wrapping each as LetNode / __stmt__-LetNode.
    final trailing = stmts.skip(i).take(stmts.length - 1 - i).toList();
    for (final stmt in trailing.reversed) {
      if (stmt is VariableDeclarationStatement) {
        final decl = stmt.variables;
        if (decl.variables.length != 1) {
          throw LoweringError(
            '@Screen locals: declare one variable per statement.',
            fn,
          );
        }
        final v = decl.variables.single;
        if (v.initializer == null) {
          throw LoweringError(
            '@Screen locals must have an initializer.',
            fn,
          );
        }
        acc = LetNode(
          name: v.name.lexeme,
          value: lowerExpression(v.initializer!),
          body: acc,
        );
        continue;
      }
      if (stmt is ExpressionStatement) {
        final lowered = lowerExpression(stmt.expression);
        acc = LetNode(name: '__stmt__', value: lowered, body: acc);
        continue;
      }
      throw LoweringError(
        '@Screen body: only local declarations and assignment statements '
        'are supported before the return. Got ${stmt.runtimeType}.',
        fn,
      );
    }
    if (statefulFields.isNotEmpty) {
      // ID is the screen name. The lowerer currently emits at most one
      // IrStatefulNode per screen (the screen-body root); the screen name is
      // unique within the host app and stable across builds, which is exactly
      // what `ValueKey` needs to make Flutter assign State<> by IR identity
      // rather than sibling position.
      return IrStatefulNode(
        id: ann.name,
        fields: statefulFields,
        body: acc,
      );
    }
    return acc;
  } finally {
    popScope();
  }
}

/// Lowers a general block statement list (containing if/else, nested blocks,
/// etc.) to a [BlockNode]. All variable declarations in the block are
/// collected first (for scope tracking) then each statement is lowered.
IrNode _lowerGeneralBlock(List<Statement> stmts) {
  // Collect top-level variable declarations in this block for scope tracking.
  final bindings = <String, BindingKind>{};
  for (final stmt in stmts) {
    if (stmt is VariableDeclarationStatement) {
      final decl = stmt.variables;
      for (final v in decl.variables) {
        final name = v.name.lexeme;
        if (name.startsWith('__')) {
          throw LoweringError(
            'Local name "$name" is reserved: names beginning with "__" are '
            'used internally by the lowerer. Pick a different name.',
            v,
          );
        }
        bindings[name] =
            decl.isFinal ? BindingKind.finalBinding : BindingKind.varBinding;
      }
    }
  }

  pushScope(bindings);
  try {
    final lowered = stmts.map(lowerStatement).toList();
    return BlockNode(statements: lowered);
  } finally {
    popScope();
  }
}

/// Lowers a single [Statement] to an [IrNode].
IrNode lowerStatement(Statement stmt) {
  if (stmt is ReturnStatement) {
    return ReturnNode(
      value: stmt.expression == null ? null : _lowerExpression(stmt.expression!),
    );
  }
  if (stmt is BreakStatement) {
    if (stmt.label != null) {
      throw LoweringError('Labeled break is not supported.', stmt);
    }
    return const BreakNode();
  }
  if (stmt is ContinueStatement) {
    if (stmt.label != null) {
      throw LoweringError('Labeled continue is not supported.', stmt);
    }
    return const ContinueNode();
  }
  if (stmt is IfStatement) {
    return IfStatementNode(
      cond: _lowerExpression(stmt.expression),
      then: lowerStatement(stmt.thenStatement),
      else_: stmt.elseStatement == null
          ? null
          : lowerStatement(stmt.elseStatement!),
    );
  }
  if (stmt is Block) {
    return _lowerGeneralBlock(stmt.statements);
  }
  if (stmt is VariableDeclarationStatement) {
    return _lowerVarDeclStatement(stmt);
  }
  if (stmt is ExpressionStatement) {
    return _lowerExpression(stmt.expression);
  }
  // Note: labeled loops arrive as LabeledStatement { statement: WhileStatement }
  // and are rejected below by the LabeledStatement case — no .label field
  // exists on WhileStatement / DoStatement / ForStatement in the analyzer AST.
  if (stmt is WhileStatement) {
    return WhileNode(
      condition: _lowerExpression(stmt.condition),
      body: lowerStatement(stmt.body),
    );
  }
  if (stmt is DoStatement) {
    return DoNode(
      body: lowerStatement(stmt.body),
      condition: _lowerExpression(stmt.condition),
    );
  }
  if (stmt is ForStatement) {
    final parts = stmt.forLoopParts;
    if (parts is ForPartsWithDeclarations) {
      // Collect the loop-variable bindings so the update/body can resolve them.
      final loopBindings = <String, BindingKind>{};
      for (final v in parts.variables.variables) {
        loopBindings[v.name.lexeme] = parts.variables.isFinal
            ? BindingKind.finalBinding
            : BindingKind.varBinding;
      }
      pushScope(loopBindings);
      try {
        return ImperativeForNode(
          init: _lowerForInit(parts.variables, stmt),
          condition: parts.condition == null
              ? null
              : _lowerExpression(parts.condition!),
          update: _lowerForUpdate(parts.updaters),
          body: lowerStatement(stmt.body),
        );
      } finally {
        popScope();
      }
    }
    if (parts is ForPartsWithExpression) {
      return ImperativeForNode(
        init: parts.initialization == null
            ? null
            : _lowerExpression(parts.initialization!),
        condition: parts.condition == null
            ? null
            : _lowerExpression(parts.condition!),
        update: _lowerForUpdate(parts.updaters),
        body: lowerStatement(stmt.body),
      );
    }
    // ForEachParts (for-in): collection-for. Delegate to existing path by
    // wrapping in a helper that understands the for-in structure.
    return _lowerCollectionForStatement(stmt);
  }
  if (stmt is LabeledStatement) {
    final labelName = stmt.labels.isNotEmpty
        ? stmt.labels.first.name.lexeme
        : '<unknown>';
    throw LoweringError(
      'Labeled statements are not supported in @Screen bodies. '
      'Remove the label "$labelName".',
      stmt,
    );
  }
  throw LoweringError(
    'Unsupported statement: ${stmt.runtimeType}',
    stmt,
  );
}

/// Lowers a `VariableDeclarationList` from a C-style for-init clause to
/// a [LetStatementNode] (single decl) or [BlockNode] of [LetStatementNode]s
/// (multiple decls, rare).
IrNode _lowerForInit(
    VariableDeclarationList decl, AstNode context) {
  if (decl.variables.length == 1) {
    final v = decl.variables.single;
    if (v.initializer == null) {
      throw LoweringError(
        'For-loop init variable must have an initializer.',
        context,
      );
    }
    return LetStatementNode(
      name: v.name.lexeme,
      value: lowerExpression(v.initializer!),
      isFinal: decl.isFinal,
    );
  }
  // Multiple declarators in the same for-init (rare but valid Dart).
  final stmts = <IrNode>[];
  for (final v in decl.variables) {
    if (v.initializer == null) {
      throw LoweringError(
        'For-loop init variable must have an initializer.',
        context,
      );
    }
    stmts.add(LetStatementNode(
      name: v.name.lexeme,
      value: lowerExpression(v.initializer!),
      isFinal: decl.isFinal,
    ));
  }
  return BlockNode(statements: stmts);
}

/// Lowers a list of for-update expressions. A single updater is lowered
/// directly; multiple are wrapped in a [BlockNode] of expression-statements.
IrNode? _lowerForUpdate(NodeList<Expression> updaters) {
  if (updaters.isEmpty) return null;
  if (updaters.length == 1) return lowerExpression(updaters.single);
  return BlockNode(
    statements: updaters.map<IrNode>(lowerExpression).toList(),
  );
}

/// Lowers a `for (x in xs) body` statement (ForEachParts) to a [ForNode].
/// This handles the statement-form of collection-for (not the expression form
/// used inside list literals).
IrNode _lowerCollectionForStatement(ForStatement stmt) {
  final parts = stmt.forLoopParts;
  final body = lowerStatement(stmt.body);
  if (parts is ForEachPartsWithDeclaration) {
    return ForNode(
      variable: parts.loopVariable.name.lexeme,
      source: _lowerExpression(parts.iterable),
      body: body,
    );
  }
  if (parts is ForEachPartsWithPattern) {
    // Destructured `for (final (i, x) in xs.indexed)` — uses the destructured
    // ForNode constructor.
    // Collect bound names from the record pattern.
    final pattern = parts.pattern;
    final variables = <String>[];
    if (pattern is RecordPattern) {
      for (final field in pattern.fields) {
        final p = field.pattern;
        if (p is DeclaredVariablePattern) {
          variables.add(p.name.lexeme);
        }
      }
    }
    if (variables.isNotEmpty) {
      return ForNode.destructured(
        variables: variables,
        source: _lowerExpression(parts.iterable),
        body: body,
      );
    }
  }
  throw LoweringError(
    'Unsupported for-in loop pattern: ${parts.runtimeType}',
    stmt,
  );
}

/// Lowers a [VariableDeclarationStatement] to a [LetStatementNode].
IrNode _lowerVarDeclStatement(VariableDeclarationStatement stmt) {
  final decl = stmt.variables;
  if (decl.variables.length != 1) {
    throw LoweringError(
      '@Screen locals: declare one variable per statement.',
      stmt,
    );
  }
  final v = decl.variables.single;
  if (v.initializer == null) {
    throw LoweringError(
      '@Screen locals must have an initializer.',
      stmt,
    );
  }
  return LetStatementNode(
    name: v.name.lexeme,
    value: lowerExpression(v.initializer!),
    isFinal: decl.isFinal,
  );
}

void _collectRefs(
  IrNode node,
  Set<String> widgetRefs,
  Map<String, List<String>> methodRefs,
  Set<String> fnRefs,
) {
  switch (node) {
    case WidgetNode():
      widgetRefs.add(node.name);
      for (final child in node.args.values) {
        _collectRefs(child, widgetRefs, methodRefs, fnRefs);
      }
      if (node.key != null) {
        _collectRefs(node.key!, widgetRefs, methodRefs, fnRefs);
      }
    case BuiltinWidgetNode():
      for (final child in node.args.values) {
        _collectRefs(child, widgetRefs, methodRefs, fnRefs);
      }
      if (node.key != null) {
        _collectRefs(node.key!, widgetRefs, methodRefs, fnRefs);
      }
    case ListNode():
      for (final child in node.children) {
        _collectRefs(child, widgetRefs, methodRefs, fnRefs);
      }
    case MapNode():
      for (final entry in node.entries.entries) {
        _collectRefs(entry.key, widgetRefs, methodRefs, fnRefs);
        _collectRefs(entry.value, widgetRefs, methodRefs, fnRefs);
      }
    case RecordNode():
      for (final child in node.positional) {
        _collectRefs(child, widgetRefs, methodRefs, fnRefs);
      }
      for (final child in node.named.values) {
        _collectRefs(child, widgetRefs, methodRefs, fnRefs);
      }
    case ConditionalNode():
      _collectRefs(node.condition, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.thenBranch, widgetRefs, methodRefs, fnRefs);
      if (node.elseBranch != null) {
        _collectRefs(node.elseBranch!, widgetRefs, methodRefs, fnRefs);
      }
    case ForNode():
      _collectRefs(node.source, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.body, widgetRefs, methodRefs, fnRefs);
    case SpreadNode():
      _collectRefs(node.source, widgetRefs, methodRefs, fnRefs);
    case EventNode():
      if (node.target.length >= 2) {
        final inputName = node.target.first;
        final methodName = node.target.last;
        methodRefs.putIfAbsent(inputName, () => []);
        if (!methodRefs[inputName]!.contains(methodName)) {
          methodRefs[inputName]!.add(methodName);
        }
      }
      for (final arg in node.args.values) {
        _collectRefs(arg, widgetRefs, methodRefs, fnRefs);
      }
    case CompareOpNode():
      _collectRefs(node.left, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.right, widgetRefs, methodRefs, fnRefs);
    case ArithOpNode():
      _collectRefs(node.left, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.right, widgetRefs, methodRefs, fnRefs);
    case LogicOpNode():
      _collectRefs(node.left, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.right, widgetRefs, methodRefs, fnRefs);
    case NotOpNode():
      _collectRefs(node.operand, widgetRefs, methodRefs, fnRefs);
    case CoalesceOpNode():
      _collectRefs(node.left, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.right, widgetRefs, methodRefs, fnRefs);
    case GetterNode():
      _collectRefs(node.receiver, widgetRefs, methodRefs, fnRefs);
    case SetterCallNode():
      _collectRefs(node.target, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.value, widgetRefs, methodRefs, fnRefs);
    case LetNode():
      _collectRefs(node.value, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.body, widgetRefs, methodRefs, fnRefs);
    case AssignNode():
      _collectRefs(node.value, widgetRefs, methodRefs, fnRefs);
    case LambdaNode():
      _collectRefs(node.body, widgetRefs, methodRefs, fnRefs);
    case MemberAccessNode():
      _collectRefs(node.target, widgetRefs, methodRefs, fnRefs);
    case IndexAccessNode():
      _collectRefs(node.target, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.key, widgetRefs, methodRefs, fnRefs);
    case LengthOfNode():
      _collectRefs(node.target, widgetRefs, methodRefs, fnRefs);
    case IsNullCheckNode():
      _collectRefs(node.operand, widgetRefs, methodRefs, fnRefs);
    case IsTypeNode():
      _collectRefs(node.receiver, widgetRefs, methodRefs, fnRefs);
    case AsTypeNode():
      _collectRefs(node.operand, widgetRefs, methodRefs, fnRefs);
    case RuntimeTypeRefNode():
      _collectRefs(node.operand, widgetRefs, methodRefs, fnRefs);
    case StringInterpNode():
      for (final part in node.parts) {
        if (part is IrNode) {
          _collectRefs(part, widgetRefs, methodRefs, fnRefs);
        }
      }
    case MethodCallNode():
      if (node.receiver != null) {
        _collectRefs(node.receiver!, widgetRefs, methodRefs, fnRefs);
      }
      for (final arg in node.args) {
        _collectRefs(arg, widgetRefs, methodRefs, fnRefs);
      }
    case ValueCtorNode():
      for (final arg in node.args) {
        _collectRefs(arg, widgetRefs, methodRefs, fnRefs);
      }
    case SequenceNode():
      for (final step in node.steps) {
        _collectRefs(step, widgetRefs, methodRefs, fnRefs);
      }
      _collectRefs(node.returnExpr, widgetRefs, methodRefs, fnRefs);
    case LiteralNode():
    case ConstNode():
    case RefNode():
      break;
    case ActionSequenceNode():
      for (final step in node.steps) {
        _collectRefs(step, widgetRefs, methodRefs, fnRefs);
      }
    case ActionStepNode():
      _collectRefs(node.call, widgetRefs, methodRefs, fnRefs);
    case TryStepNode():
      for (final s in node.trySteps) {
        _collectRefs(s.call, widgetRefs, methodRefs, fnRefs);
      }
      for (final s in node.catchSteps) {
        _collectRefs(s.call, widgetRefs, methodRefs, fnRefs);
      }
    case BlockNode():
      for (final s in node.statements) {
        _collectRefs(s, widgetRefs, methodRefs, fnRefs);
      }
    case IfStatementNode():
      _collectRefs(node.cond, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.then, widgetRefs, methodRefs, fnRefs);
      if (node.else_ != null) {
        _collectRefs(node.else_!, widgetRefs, methodRefs, fnRefs);
      }
    case BreakNode():
    case ContinueNode():
      break;
    case ReturnNode():
      if (node.value != null) {
        _collectRefs(node.value!, widgetRefs, methodRefs, fnRefs);
      }
    case LetStatementNode():
      _collectRefs(node.value, widgetRefs, methodRefs, fnRefs);
    case WhileNode():
      _collectRefs(node.condition, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.body, widgetRefs, methodRefs, fnRefs);
    case DoNode():
      _collectRefs(node.body, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.condition, widgetRefs, methodRefs, fnRefs);
    case ImperativeForNode():
      if (node.init != null) {
        _collectRefs(node.init!, widgetRefs, methodRefs, fnRefs);
      }
      if (node.condition != null) {
        _collectRefs(node.condition!, widgetRefs, methodRefs, fnRefs);
      }
      if (node.update != null) {
        _collectRefs(node.update!, widgetRefs, methodRefs, fnRefs);
      }
      _collectRefs(node.body, widgetRefs, methodRefs, fnRefs);
    case IrStatefulNode():
      for (final field in node.fields) {
        _collectRefs(field.initializer, widgetRefs, methodRefs, fnRefs);
      }
      _collectRefs(node.body, widgetRefs, methodRefs, fnRefs);
    case IrStatefulFieldNode():
      _collectRefs(node.initializer, widgetRefs, methodRefs, fnRefs);
    case PayloadFunctionNode():
      _collectRefs(node.body, widgetRefs, methodRefs, fnRefs);
    case PayloadFunctionCallNode():
      for (final arg in node.args) {
        _collectRefs(arg, widgetRefs, methodRefs, fnRefs);
      }
    case ScreenWithFunctionsNode():
      for (final fn in node.functions) {
        _collectRefs(fn.body, widgetRefs, methodRefs, fnRefs);
      }
      _collectRefs(node.screenBody, widgetRefs, methodRefs, fnRefs);
    case PayloadClassNode():
      // Payload classes are metadata; no widget/method/fn refs to collect.
      break;
    case PayloadMixinNode():
      // Payload mixins are metadata; no widget/method/fn refs to collect.
      break;
    case PayloadExtensionNode():
      // Payload extensions are metadata; no widget/method/fn refs to collect.
      break;
    case PayloadFunctionValueNode():
      // Payload function values are metadata; no widget/method/fn refs to collect.
      break;
    case PayloadInstanceCreationNode():
      // Constructor args may reference widgets/methods.
      for (final arg in node.args.values) {
        _collectRefs(arg, widgetRefs, methodRefs, fnRefs);
      }
    case PayloadFieldDeclNode():
      // Field declarations may have initializers that reference widgets/methods.
      if (node.initializer != null) {
        _collectRefs(node.initializer!, widgetRefs, methodRefs, fnRefs);
      }
    case PayloadCtorNode():
      // Constructor body may reference widgets/methods.
      for (final fieldInit in node.fieldInits) {
        _collectRefs(fieldInit, widgetRefs, methodRefs, fnRefs);
      }
      if (node.body != null) {
        _collectRefs(node.body!, widgetRefs, methodRefs, fnRefs);
      }
    case PayloadFieldInitNode():
      // Field initializer value.
      _collectRefs(node.value, widgetRefs, methodRefs, fnRefs);
    case PayloadMethodCallNode():
      _collectRefs(node.receiver, widgetRefs, methodRefs, fnRefs);
      for (final arg in node.args.values) {
        _collectRefs(arg, widgetRefs, methodRefs, fnRefs);
      }
    case PayloadFieldRefNode():
      _collectRefs(node.receiver, widgetRefs, methodRefs, fnRefs);
    case PayloadFieldAssignNode():
      _collectRefs(node.receiver, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.value, widgetRefs, methodRefs, fnRefs);
    case ThisFieldRefNode():
    case ThisRefNode():
      break;
  }
}

/// Extracts the class name from a [ClassDeclaration].
String _classDeclName(ClassDeclaration decl) {
  final namePart = decl.namePart;
  if (namePart is NameWithTypeParameters) {
    return namePart.typeName.lexeme;
  }
  return decl.namePart.toSource();
}
