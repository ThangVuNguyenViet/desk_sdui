import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';
import 'cell.dart';
import 'payload_class.dart';
import 'ref_resolver.dart';
import 'runtime.dart';

// ---------------------------------------------------------------------------
// RuntimeContext — per-resolve payload function table
// ---------------------------------------------------------------------------

/// Per-resolve context passed alongside the env. Carries the payload function
/// table for the current screen (file-local, never global).
class RuntimeContext {
  const RuntimeContext({this.payloadFunctions = const {}});
  final Map<String, PayloadFunctionNode> payloadFunctions;

  static const empty = RuntimeContext();
}

// ---------------------------------------------------------------------------
// Entry points
// ---------------------------------------------------------------------------

/// Public entry point. Converts [input] to the internal cell-backed env and
/// delegates to [evalExpressionWithEnv].
Object? evalExpression(
  IrNode node,
  Map<String, Object?> input,
  Runtime runtime, {
  RuntimeContext ctx = RuntimeContext.empty,
}) {
  return evalExpressionWithEnv(node, toEnv(input), runtime, ctx: ctx);
}

/// Eval-only entry point that handles [ScreenWithFunctionsNode] by building
/// the payload function table before resolving the screen body.
///
/// **Not used by widget rendering.** Widget-position screen resolution flows
/// through `resolveNode` in `resolve.dart`, which has its own
/// `ScreenWithFunctionsNode` case and threads [RuntimeContext] through the
/// resolver helpers. This function exists for value-only entry points
/// (currently: payload-function eval tests) that need to drive
/// [evalExpressionWithEnv] against a screen IR whose root is a
/// [ScreenWithFunctionsNode].
Object? resolveScreen(
  IrNode node,
  Map<String, Object?> input,
  Runtime runtime,
) {
  final env = toEnv(input);
  if (node is ScreenWithFunctionsNode) {
    // Register payload classes (in declaration order; dependencies are enforced
    // by the lowerer).
    for (final cls in node.classes) {
      final payloadClasses_map = payloadClasses;
      final payloadCls = PayloadClass(
        name: cls.name,
        supertype: cls.supertypeName != null
            ? (payloadClasses_map[cls.supertypeName] ??
                (throw StateError(
                  'PayloadClass "${cls.name}" references unknown supertype '
                  '"${cls.supertypeName}"; make sure it is declared before ${cls.name}.'
                )))
            : null,
        mixins: cls.mixinNames
            .map((name) =>
                payloadClasses_map[name] ??
                (throw StateError(
                  'PayloadClass "${cls.name}" references unknown mixin '
                  '"$name"; make sure it is declared before ${cls.name}.'
                )))
            .toList(),
        methods: const {},
        fieldInitializers: const {},
        ctors: const {},
      );
      registerPayloadClass(payloadCls);
    }

    final ctx = RuntimeContext(
      payloadFunctions: {for (final fn in node.functions) fn.name: fn},
    );
    return evalExpressionWithEnv(node.screenBody, env, runtime, ctx: ctx);
  }
  return evalExpressionWithEnv(node, env, runtime);
}

/// Internal evaluator. [env] is a mutable cell-backed environment; only
/// this function and trusted internal callers (resolve.dart action sequence
/// runner) should call this directly.
Object? evalExpressionWithEnv(
  IrNode node,
  Map<String, Cell> env,
  Runtime runtime, {
  RuntimeContext ctx = RuntimeContext.empty,
}) {
  switch (node) {
    case LiteralNode(:final value):
      return value;
    case ConstNode(:final value):
      return value;
    case RefNode(:final path):
      // Fast path: single-segment reads (the overwhelming common case for
      // local variables `RefNode([name])`) hit the cell directly without
      // allocating an unwrapped value map.
      if (path.length == 1) {
        final cell = env[path[0]];
        if (cell != null) return cell.value;
      }
      // Multi-segment paths (e.g. `data.headline`) or names not in env (e.g.
      // `Colors.blue` resolving through the runtime constant registry) need
      // the full unwrapped map.
      return resolveFlutterRef(path, _unwrapEnv(env), runtime);

    case CompareOpNode(:final op, :final left, :final right):
      final l = evalExpressionWithEnv(left, env, runtime, ctx: ctx);
      final r = evalExpressionWithEnv(right, env, runtime, ctx: ctx);
      return switch (op) {
        CompareOp.eq => l == r,
        CompareOp.neq => l != r,
        CompareOp.lt => (l! as num) < (r! as num),
        CompareOp.lte => (l! as num) <= (r! as num),
        CompareOp.gt => (l! as num) > (r! as num),
        CompareOp.gte => (l! as num) >= (r! as num),
      };

    case ArithOpNode(:final op, :final left, :final right):
      final l = evalExpressionWithEnv(left, env, runtime, ctx: ctx)! as num;
      final r = evalExpressionWithEnv(right, env, runtime, ctx: ctx)! as num;
      return switch (op) {
        ArithOp.add => l + r,
        ArithOp.sub => l - r,
        ArithOp.mul => l * r,
        ArithOp.div => l / r,
        ArithOp.mod => l % r,
        ArithOp.intDiv => l ~/ r,
      };

    case LogicOpNode(:final op, :final left, :final right):
      final l = evalExpressionWithEnv(left, env, runtime, ctx: ctx)! as bool;
      return switch (op) {
        LogicOp.and =>
          l &&
              (evalExpressionWithEnv(right, env, runtime, ctx: ctx)! as bool),
        LogicOp.or =>
          l ||
              (evalExpressionWithEnv(right, env, runtime, ctx: ctx)! as bool),
      };

    case NotOpNode(:final operand):
      return !(evalExpressionWithEnv(operand, env, runtime, ctx: ctx)! as bool);

    case CoalesceOpNode(:final left, :final right):
      final l = evalExpressionWithEnv(left, env, runtime, ctx: ctx);
      return l ?? evalExpressionWithEnv(right, env, runtime, ctx: ctx);

    case GetterNode(:final receiver, :final name):
      final r = evalExpressionWithEnv(receiver, env, runtime, ctx: ctx);
      final handler = runtime.resolveGetter(name);
      if (handler != null) return handler(r);
      throw StateError(
        'No getter registered for "$name" (receiver: ${r.runtimeType})',
      );

    case SetterCallNode(:final target, :final setterKey, :final value):
      final receiver = evalExpressionWithEnv(target, env, runtime, ctx: ctx);
      final v = evalExpressionWithEnv(value, env, runtime, ctx: ctx);
      runtime.invokeSetter(setterKey, receiver, v);
      return v; // Dart's assignment returns the RHS

    case LetNode(:final name, :final value, :final body):
      final v = evalExpressionWithEnv(value, env, runtime, ctx: ctx);
      return evalExpressionWithEnv(
          body, {...env, name: Cell(v)}, runtime,
          ctx: ctx);

    case AssignNode(:final name, :final value):
      final cell = env[name];
      if (cell == null) {
        throw StateError(
          'AssignNode: no binding for "$name" (lowerer bug — should have rejected)',
        );
      }
      final v = evalExpressionWithEnv(value, env, runtime, ctx: ctx);
      cell.value = v;
      return v;

    case SequenceNode(:final steps, :final returnExpr):
      for (final step in steps) {
        evalExpressionWithEnv(step, env, runtime, ctx: ctx);
        // Side effect: step is a method call on the receiver. Return value ignored.
      }
      return evalExpressionWithEnv(returnExpr, env, runtime, ctx: ctx);

    case MethodCallNode(:final receiver, :final name, :final args):
      if (receiver == null) {
        if (!runtime.hasFunction(name)) {
          throw StateError('Function "$name" not registered.');
        }
        final resolvedArgs = <String, Object?>{};
        for (var i = 0; i < args.length; i++) {
          resolvedArgs['arg$i'] =
              evalExpressionWithEnv(args[i], env, runtime, ctx: ctx);
        }
        return runtime.invokeFunction(name, resolvedArgs);
      }
      final resolvedReceiver =
          evalExpressionWithEnv(receiver, env, runtime, ctx: ctx);
      final resolvedArgs = <String, Object?>{};
      for (var i = 0; i < args.length; i++) {
        resolvedArgs['arg$i'] =
            evalExpressionWithEnv(args[i], env, runtime, ctx: ctx);
      }
      // Try qualified name first (e.g. "CounterActions.save"), then unqualified.
      final qualifiedName = '${resolvedReceiver?.runtimeType}.$name';
      final handler = runtime.resolveMethodHandler(qualifiedName)
          ?? runtime.resolveMethodHandler(name);
      if (handler == null) {
        throw StateError('Method "$name" not registered in runtime.');
      }
      return handler(resolvedReceiver, resolvedArgs);

    case LambdaNode(:final params, :final body, :final isAsync):
      // Lambdas capture the current env (Map<String, Cell>). Because cells are
      // mutable objects, lambdas see live values of mutable bindings at call time.
      final capturedEnv = env;
      final capturedCtx = ctx;
      final isBlockBody = body is BlockNode;
      if (!isAsync) {
        Object? invokeSync(Map<String, Cell> e) {
          if (isBlockBody) {
            executeStatement(body, e, runtime, ctx: capturedCtx);
            return null;
          }
          return evalExpressionWithEnv(body, e, runtime, ctx: capturedCtx);
        }

        if (params.isEmpty) {
          return () => invokeSync(capturedEnv);
        }
        if (params.length == 1) {
          return (Object? a0) =>
              invokeSync({...capturedEnv, params[0]: Cell(a0)});
        }
        if (params.length == 2) {
          return (Object? a0, Object? a1) => invokeSync({
                ...capturedEnv,
                params[0]: Cell(a0),
                params[1]: Cell(a1),
              });
        }
        // >2 params: variadic fallback via List.
        return (List<Object?> args) {
          var lambdaEnv = capturedEnv;
          for (var i = 0; i < params.length; i++) {
            lambdaEnv = {...lambdaEnv, params[i]: Cell(args[i])};
          }
          return invokeSync(lambdaEnv);
        };
      }
      // Async path: closures return Future<Object?>. Only valid in action
      // context; the lowerer already rejected production outside
      // ActionSequenceNode bodies.
      if (params.isEmpty) {
        return () async =>
            evalExpressionWithEnv(body, capturedEnv, runtime, ctx: capturedCtx);
      }
      if (params.length == 1) {
        return (Object? a0) async => evalExpressionWithEnv(
              body,
              {...capturedEnv, params[0]: Cell(a0)},
              runtime,
              ctx: capturedCtx,
            );
      }
      if (params.length == 2) {
        return (Object? a0, Object? a1) async => evalExpressionWithEnv(
              body,
              {...capturedEnv, params[0]: Cell(a0), params[1]: Cell(a1)},
              runtime,
              ctx: capturedCtx,
            );
      }
      throw StateError('LambdaNode: only 0-2 params supported for async');

    case MemberAccessNode(:final target, :final name):
      final t = evalExpressionWithEnv(target, env, runtime, ctx: ctx);
      if (t is Map) return t[name];
      throw StateError('MemberAccess on non-map ${t.runtimeType}');

    case IndexAccessNode(:final target, :final key):
      final t = evalExpressionWithEnv(target, env, runtime, ctx: ctx);
      final k = evalExpressionWithEnv(key, env, runtime, ctx: ctx);
      if (t is List) return t[k! as int];
      if (t is Map) return t[k];
      // Handle MaterialColor indexing (e.g., Colors.grey[300])
      if (t is MaterialColor && k is int) {
        return t[k];
      }
      throw StateError('IndexAccess on ${t.runtimeType}');

    case LengthOfNode(:final target):
      final t = evalExpressionWithEnv(target, env, runtime, ctx: ctx);
      if (t is String) return t.length;
      if (t is List) return t.length;
      if (t is Map) return t.length;
      throw StateError('LengthOf on ${t.runtimeType}');

    case IsNullCheckNode(:final operand):
      return evalExpressionWithEnv(operand, env, runtime, ctx: ctx) == null;

    case IsTypeNode(:final receiver, :final typeName):
      final r = evalExpressionWithEnv(receiver, env, runtime, ctx: ctx);
      if (r is PayloadInstance) {
        for (final cls in r.type.methodLookupOrder) {
          if (cls.name == typeName) return true;
        }
        return false;
      }
      return runtime.checkType(typeName, r);

    case AsTypeNode(:final operand, :final typeName, :final nullable):
      final v = evalExpressionWithEnv(operand, env, runtime, ctx: ctx);
      if (v == null) {
        if (nullable) return null;
        throw TypeError();
      }
      if (v is PayloadInstance) {
        for (final cls in v.type.methodLookupOrder) {
          if (cls.name == typeName) return v;
        }
        throw TypeError();
      }
      if (runtime.checkType(typeName, v)) return v;
      throw TypeError();

    case RuntimeTypeRefNode(:final operand):
      final v = evalExpressionWithEnv(operand, env, runtime, ctx: ctx);
      if (v is PayloadInstance) {
        return PayloadTypeValue(v.type);
      }
      if (v == null) return 'Null';
      return v.runtimeType.toString();

    case StringInterpNode(:final parts):
      final buf = StringBuffer();
      for (final p in parts) {
        if (p is String) {
          buf.write(p);
        } else if (p is IrNode) {
          buf.write(
              evalExpressionWithEnv(p, env, runtime, ctx: ctx) ?? '');
        }
      }
      return buf.toString();

    case PayloadFunctionCallNode(:final name, :final args):
      final fn = ctx.payloadFunctions[name];
      if (fn == null) {
        throw StateError(
          'PayloadFunctionCallNode: no function "$name" in scope '
          '(lowerer bug — allowlist walk should have rejected this call).',
        );
      }
      // Evaluate args in caller's env.
      final argValues = args
          .map((a) => evalExpressionWithEnv(a, env, runtime, ctx: ctx))
          .toList();
      // Build callee env: only params are visible (no closure capture from
      // caller's locals — payload functions are top-level, not nested closures).
      final calleeEnv = <String, Cell>{};
      for (var i = 0; i < fn.params.length; i++) {
        calleeEnv[fn.params[i]] = Cell(argValues[i]);
      }
      // Execute body. Block bodies use executeStatement + unwrap FlowReturn.
      // Expression bodies evaluate directly.
      if (fn.body is BlockNode) {
        final flow = executeStatement(fn.body, calleeEnv, runtime, ctx: ctx);
        if (flow is FlowReturn) return flow.value;
        return null; // body completed without explicit return
      }
      return evalExpressionWithEnv(fn.body, calleeEnv, runtime, ctx: ctx);

    case PayloadInstanceCreationNode(:final className, :final ctorName, :final args):
      final cls = payloadClasses[className];
      if (cls == null) {
        throw StateError('Unknown payload class "$className"');
      }
      if (cls.isMixin) {
        throw StateError('Cannot instantiate mixin "$className"');
      }

      // Look up the constructor (use ctorName or unnamed).
      final ctor = cls.ctors[ctorName];
      if (ctor == null) {
        throw StateError(
          'PayloadInstanceCreationNode: constructor "${ctorName.isEmpty ? "(unnamed)" : ctorName}" '
          'not found in class "$className".',
        );
      }

      // Allocate field cells from mixin fieldInitializers (left-to-right)
      // followed by the class's own fieldInitializers.
      final fields = <String, Cell>{};
      for (final mixin in cls.mixins) {
        for (final entry in mixin.fieldInitializers.entries) {
          final value = evalExpressionWithEnv(entry.value, env, runtime, ctx: ctx);
          fields[entry.key] = Cell(value);
        }
      }
      for (final entry in cls.fieldInitializers.entries) {
        final fieldName = entry.key;
        final initializer = entry.value;
        final value = evalExpressionWithEnv(initializer, env, runtime, ctx: ctx);
        fields[fieldName] = Cell(value);
      }

      // Create the payload instance.
      final instance = PayloadInstance(type: cls, fields: fields);

      // Evaluate args in caller's env.
      final argValues = <String, Object?>{};
      for (final entry in args.entries) {
        argValues[entry.key] =
            evalExpressionWithEnv(entry.value, env, runtime, ctx: ctx);
      }

      // Bind args to params and apply field inits (this.x = value).
      final ctorEnv = <String, Cell>{};
      for (var i = 0; i < ctor.params.length; i++) {
        ctorEnv[ctor.params[i]] = Cell(argValues[ctor.params[i]] ?? argValues['arg$i']);
      }
      // Bind 'this' to the in-progress instance.
      ctorEnv['this'] = Cell(instance);

      // Execute field inits.
      for (final entry in ctor.fieldInits.entries) {
        final value = evalExpressionWithEnv(entry.value, ctorEnv, runtime, ctx: ctx);
        final cell = fields[entry.key];
        if (cell != null) {
          cell.value = value;
        } else {
          fields[entry.key] = Cell(value);
        }
      }

      // Execute ctor body if present.
      if (ctor.body != null) {
        final body = ctor.body!;
        if (body is BlockNode) {
          executeStatement(body, ctorEnv, runtime, ctx: ctx);
        } else {
          evalExpressionWithEnv(body, ctorEnv, runtime, ctx: ctx);
        }
      }

      return instance;

    case PayloadMethodCallNode(:final receiver, :final methodName, :final args):
      final receiverValue = evalExpressionWithEnv(receiver, env, runtime, ctx: ctx);
      PayloadFunctionNode? fn;
      String? receiverTypeName;

      if (receiverValue is PayloadInstance) {
        final inst = receiverValue;
        receiverTypeName = inst.type.name;
        for (final cls in inst.type.methodLookupOrder) {
          if (cls.methods.containsKey(methodName)) {
            fn = cls.methods[methodName];
            break;
          }
        }
      }

      // Try extension methods if no payload-class method found.
      if (fn == null && receiverTypeName != null) {
        fn = resolveExtensionMethod(receiverTypeName, methodName);
      }

      if (fn == null) {
        throw NoSuchMethodError.withInvocation(
          receiverValue,
          Invocation.method(Symbol(methodName), []),
        );
      }
      final inst = receiverValue as PayloadInstance;
      // Evaluate args in caller env.
      final argValues = <String, Object?>{};
      for (final entry in args.entries) {
        argValues[entry.key] = evalExpressionWithEnv(entry.value, env, runtime, ctx: ctx);
      }
      // Build callee env: this + params bound.
      final calleeEnv = <String, Cell>{
        "this": Cell(inst),
      };
      for (var i = 0; i < fn.params.length; i++) {
        final paramName = fn.params[i];
        calleeEnv[paramName] = Cell(argValues[paramName] ?? argValues["arg\$i"]);
      }
      // Execute body.
      final body = fn.body;
      if (body is BlockNode) {
        final flow = executeStatement(body, calleeEnv, runtime, ctx: ctx);
        return flow is FlowReturn ? flow.value : null;
      }
      return evalExpressionWithEnv(body, calleeEnv, runtime, ctx: ctx);

    case ThisFieldRefNode(:final fieldName):
      final inst = env["this"]?.value as PayloadInstance;
      return inst.fields[fieldName]?.value;

    case ThisRefNode():
      return env["this"]?.value;

    case PayloadFieldRefNode(:final receiver, :final fieldName):
      final inst = evalExpressionWithEnv(receiver, env, runtime, ctx: ctx) as PayloadInstance;
      final cell = inst.fields[fieldName];
      if (cell == null) {
        throw StateError("No field \$fieldName on \${inst.type.name}");
      }
      return cell.value;

    case PayloadFieldAssignNode(:final receiver, :final fieldName, :final value):
      final inst = evalExpressionWithEnv(receiver, env, runtime, ctx: ctx) as PayloadInstance;
      final cell = inst.fields[fieldName];
      if (cell == null) {
        throw StateError("No field \$fieldName on \${inst.type.name}");
      }
      final v = evalExpressionWithEnv(value, env, runtime, ctx: ctx);
      cell.value = v;
      return v;

    case PayloadFunctionValueNode(:final functionName, :final lambda, :final methodTearoffReceiver, :final methodTearoffName, :final capturedEnvKeys):
      // Capture env (only the keys we know are referenced).
      final captured = <String, Cell>{for (final k in capturedEnvKeys) k: env[k]!};
      if (functionName != null) {
        final fn = ctx.payloadFunctions[functionName]!;
        return _makeFunction(fn, captured, runtime, ctx);
      }
      if (lambda != null) {
        return _makeLambdaFunction(lambda, captured, runtime, ctx);
      }
      if (methodTearoffReceiver != null && methodTearoffName != null) {
        final inst = evalExpressionWithEnv(methodTearoffReceiver, env, runtime, ctx: ctx) as PayloadInstance;
        return _makeTearoff(inst, methodTearoffName, runtime, ctx);
      }
      throw StateError('empty PayloadFunctionValueNode');

    case ConditionalNode(:final condition, :final thenBranch, :final elseBranch):
      final cond = evalExpressionWithEnv(condition, env, runtime, ctx: ctx);
      if (cond == true) {
        return evalExpressionWithEnv(thenBranch, env, runtime, ctx: ctx);
      }
      if (elseBranch != null) {
        return evalExpressionWithEnv(elseBranch, env, runtime, ctx: ctx);
      }
      return null;

    // Widget / layout nodes — not valid at expression position.
    case WidgetNode():
    case BuiltinWidgetNode():
    case ListNode():
    case MapNode():
    case RecordNode():
    case ForNode():
    case SpreadNode():
    case EventNode():
    case ValueCtorNode():
    case ActionSequenceNode():
    case ActionStepNode():
    case TryStepNode():
    // Statement nodes — must go through executeStatement.
    case BlockNode():
    case IfStatementNode():
    case BreakNode():
    case ContinueNode():
    case ReturnNode():
    case LetStatementNode():
    case WhileNode():
    case DoNode():
    case ImperativeForNode():
    // Screen-structure nodes — not valid at expression position.
    case IrStatefulNode():
    case IrStatefulFieldNode():
    case PayloadClassNode():
    case PayloadMixinNode():
    case PayloadExtensionNode():
    case PayloadFieldDeclNode():
    case PayloadCtorNode():
    case PayloadFieldInitNode():
    case PayloadFunctionNode():
    case ScreenWithFunctionsNode():
      throw StateError(
        'evalExpressionWithEnv: node ${node.runtimeType} is not valid at '
        'expression position; use executeStatement or resolveNode instead.',
      );
  }
}

/// Creates a callable Dart Function from a [PayloadFunctionNode].
Function _makeFunction(PayloadFunctionNode fn, Map<String, Cell> captured, Runtime rt, RuntimeContext ctx) {
  Object? invoke(Map<String, Cell> callEnv) {
    final merged = <String, Cell>{...captured, ...callEnv};
    final body = fn.body;
    if (body is BlockNode) {
      final flow = executeStatement(body, merged, rt, ctx: ctx);
      return flow is FlowReturn ? flow.value : null;
    }
    return evalExpressionWithEnv(body, merged, rt, ctx: ctx);
  }

  if (fn.params.length == 0) {
    return () => invoke({});
  }
  if (fn.params.length == 1) {
    return (Object? a0) => invoke({fn.params[0]: Cell(a0)});
  }
  if (fn.params.length == 2) {
    return (Object? a0, Object? a1) => invoke({
      fn.params[0]: Cell(a0),
      fn.params[1]: Cell(a1),
    });
  }
  throw StateError('Payload Function values support 0-2 params');
}

/// Creates a callable Dart Function from a [LambdaNode].
Function _makeLambdaFunction(LambdaNode lambda, Map<String, Cell> captured, Runtime rt, RuntimeContext ctx) {
  Object? invoke(Map<String, Cell> callEnv) {
    final merged = <String, Cell>{...captured, ...callEnv};
    final body = lambda.body;
    if (body is BlockNode) {
      final flow = executeStatement(body, merged, rt, ctx: ctx);
      return flow is FlowReturn ? flow.value : null;
    }
    return evalExpressionWithEnv(body, merged, rt, ctx: ctx);
  }

  if (lambda.params.length == 0) {
    return () => invoke({});
  }
  if (lambda.params.length == 1) {
    return (Object? a0) => invoke({lambda.params[0]: Cell(a0)});
  }
  if (lambda.params.length == 2) {
    return (Object? a0, Object? a1) => invoke({
      lambda.params[0]: Cell(a0),
      lambda.params[1]: Cell(a1),
    });
  }
  throw StateError('Payload lambda values support 0-2 params');
}

/// Creates a callable Dart Function from a method tear-off.
Function _makeTearoff(PayloadInstance inst, String methodName, Runtime rt, RuntimeContext ctx) {
  PayloadFunctionNode? fn;
  for (final cls in inst.type.methodLookupOrder) {
    if (cls.methods.containsKey(methodName)) {
      fn = cls.methods[methodName];
      break;
    }
  }
  if (fn == null) {
    throw NoSuchMethodError.withInvocation(
      inst,
      Invocation.method(Symbol(methodName), []),
    );
  }
  return _makeFunction(fn, {'this': Cell(inst)}, rt, ctx);
}

/// Unwraps a `Map<String, Cell>` env to `Map<String, Object?>` for callers
/// that need the raw value map (e.g., `resolveFlutterRef`).
Map<String, Object?> _unwrapEnv(Map<String, Cell> env) {
  return {for (final e in env.entries) e.key: e.value.value};
}

// ---------------------------------------------------------------------------
// Statement-form resolver + ControlFlow signals
// ---------------------------------------------------------------------------

/// Control-flow signal returned by [executeStatement].
sealed class ControlFlow {
  const ControlFlow();
}

/// Normal (fall-through) execution: the statement completed without an
/// early-exit control-flow signal.
final class FlowNormal extends ControlFlow {
  const FlowNormal();
  static const instance = FlowNormal();
}

/// `break;` — abort the enclosing loop iteration.
final class FlowBreak extends ControlFlow {
  const FlowBreak();
  static const instance = FlowBreak();
}

/// `continue;` — skip to the next enclosing loop iteration.
final class FlowContinue extends ControlFlow {
  const FlowContinue();
  static const instance = FlowContinue();
}

/// `return [value];` — return from the enclosing function.
final class FlowReturn extends ControlFlow {
  const FlowReturn(this.value);
  final Object? value;
}

/// Executes a statement node, returning a [ControlFlow] signal.
///
/// [node] must be a [StatementNode] (or an expression-as-statement, handled
/// by the `default:` arm). [env] is the mutable cell-backed environment.
///
/// For [BlockNode]: a shallow copy of [env] is used as the block's scope, so
/// bindings declared inside the block do not leak out, but mutations to
/// already-existing cells ARE visible to the outer scope (shared cell refs).
ControlFlow executeStatement(
  IrNode node,
  Map<String, Cell> env,
  Runtime runtime, {
  RuntimeContext ctx = RuntimeContext.empty,
}) {
  switch (node) {
    case BlockNode(:final statements):
      // Shallow-copy of env: new binding names are scoped to this block; cell
      // values of outer bindings are shared by reference (mutations visible).
      final scoped = Map<String, Cell>.of(env);
      for (final s in statements) {
        final flow = executeStatement(s, scoped, runtime, ctx: ctx);
        if (flow is! FlowNormal) return flow;
      }
      return FlowNormal.instance;

    case IfStatementNode(:final cond, :final then, :final else_):
      final c = evalExpressionWithEnv(cond, env, runtime, ctx: ctx);
      if (c == true) return executeStatement(then, env, runtime, ctx: ctx);
      if (else_ != null) return executeStatement(else_, env, runtime, ctx: ctx);
      return FlowNormal.instance;

    case BreakNode():
      return FlowBreak.instance;

    case ContinueNode():
      return FlowContinue.instance;

    case ReturnNode(:final value):
      return FlowReturn(
        value == null
            ? null
            : evalExpressionWithEnv(value, env, runtime, ctx: ctx),
      );

    case LetStatementNode(:final name, :final value):
      final v = evalExpressionWithEnv(value, env, runtime, ctx: ctx);
      env[name] = Cell(v);
      return FlowNormal.instance;

    case WhileNode(:final condition, :final body):
      while (evalExpressionWithEnv(condition, env, runtime, ctx: ctx) == true) {
        final flow = executeStatement(body, env, runtime, ctx: ctx);
        if (flow is FlowBreak) break;
        if (flow is FlowContinue) continue;
        if (flow is FlowReturn) return flow; // propagate
      }
      return FlowNormal.instance;

    case DoNode(:final body, :final condition):
      do {
        final flow = executeStatement(body, env, runtime, ctx: ctx);
        if (flow is FlowBreak) break;
        if (flow is FlowContinue) continue;
        if (flow is FlowReturn) return flow;
      } while (
          evalExpressionWithEnv(condition, env, runtime, ctx: ctx) == true);
      return FlowNormal.instance;

    case ImperativeForNode(
        :final init,
        :final condition,
        :final update,
        :final body
      ):
      // Fresh scope for the loop variable, per Dart semantics.
      final scoped = Map<String, Cell>.of(env);
      if (init != null) {
        // For a BlockNode init (multiple declarators), the let-bindings must
        // land in the loop's `scoped` map itself (not in BlockNode's own
        // clone scope). Execute each inner statement directly in `scoped`.
        if (init is BlockNode) {
          for (final s in init.statements) {
            final flow = executeStatement(s, scoped, runtime, ctx: ctx);
            if (flow is! FlowNormal) return flow;
          }
        } else {
          final flow = executeStatement(init, scoped, runtime, ctx: ctx);
          if (flow is! FlowNormal) return flow;
        }
      }
      loop:
      while (condition == null ||
          evalExpressionWithEnv(condition, scoped, runtime, ctx: ctx) == true) {
        final flow = executeStatement(body, scoped, runtime, ctx: ctx);
        if (flow is FlowBreak) break loop;
        if (flow is FlowReturn) return flow;
        // FlowContinue and FlowNormal both fall through to update.
        // Use executeStatement so a BlockNode update (multiple updaters like
        // `i = i + 1, j = j + 2`) dispatches correctly. A single-expression
        // update falls through executeStatement's default arm to
        // evalExpressionWithEnv.
        if (update != null) {
          executeStatement(update, scoped, runtime, ctx: ctx);
        }
      }
      return FlowNormal.instance;

    default:
      // Expression-as-statement: evaluate and discard the value.
      evalExpressionWithEnv(node, env, runtime, ctx: ctx);
      return FlowNormal.instance;
  }
}
