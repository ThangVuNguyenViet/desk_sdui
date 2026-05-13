// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import 'type_collector.dart';

/// Generates Dart source lines that register types with the SDUI [Runtime].
///
/// Each `emit*` method accepts an analyzer element (or a [DartType]) and
/// returns a single Dart statement string such as:
///
/// ```dart
/// rt.registerWidget('Column', (args) => Column(...));
/// ```
///
/// All registrations are generated from the **type's definition** (its full
/// constructor / method signature), never from a single call-site shape. This
/// guarantees that two files using the same type with different param subsets
/// produce bytewise-identical registration closures — safe last-writer-wins
/// idempotency.
class RegistrationEmitter {
  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Emit a `rt.registerWidget(...)` call for [widget]'s unnamed constructor.
  ///
  /// Covers ALL named/positional params defined by the ctor so that any
  /// payload subset works at runtime.
  String emitWidget(ClassElement widget) {
    final ctor = _unnamedCtor(widget);
    if (ctor == null) return '// No unnamed constructor for ${widget.name}';
    return _emitWidgetCtor(
      ctor,
      registrationName: widget.name!,
      callTarget: widget.name!,
    );
  }

  /// Emit a `rt.registerWidget(...)` line for a specific constructor [ctor].
  /// [registrationName] is the qualified name (e.g. 'Cue' or 'Cue.onMount').
  /// [callTarget] is the Dart expression used to invoke it
  /// (e.g. 'Cue' or 'Cue.onMount').
  String _emitWidgetCtor(
    ConstructorElement ctor, {
    required String registrationName,
    required String callTarget,
  }) {
    final params = ctor.formalParameters;
    final argsCode = _buildWidgetArgList(params);
    return "rt.registerWidget('$registrationName', "
        "(args) => $callTarget($argsCode));";
  }

  /// Emit a `rt.registerConstant(...)` call for a static field or accessor.
  ///
  /// The qualified name is `ClassName.memberName`.
  String emitConstant(Element constant) {
    final className = constant.enclosingElement?.name ?? '';
    final memberName = constant.name ?? '';
    final qualifiedName = '$className.$memberName';
    return "rt.registerConstant('$qualifiedName', $qualifiedName);";
  }

  /// Emit a `rt.registerMethod(...)` call for an instance method.
  ///
  /// [receiverType] is the static type on which the method is invoked — used
  /// for the cast expression and the qualified registration name.
  String emitMethod(MethodElement method, {required DartType receiverType}) {
    final receiverClassName = method.enclosingElement!.name;
    final qualifiedName = '$receiverClassName.${method.name}';
    final params = method.formalParameters;
    final callArgs = _buildCallArgList(params);

    if (method.isStatic) {
      return "rt.registerFunction('$qualifiedName', "
          "(args) => $receiverClassName.${method.name}($callArgs));";
    }

    final receiverTypeName = _typeDisplayName(receiverType);
    return "rt.registerMethod('$qualifiedName', "
        "(recv, args) => (recv as $receiverTypeName).${method.name}($callArgs));";
  }

  /// Emit a `rt.registerSubscript(...)` call for the `[]` operator on [type].
  String emitSubscript(DartType type) {
    final typeName = _typeDisplayName(type);
    // Simple element name (no type args) for the registration key.
    final elementName = _typeElementName(type) ?? typeName;

    // Determine the key type from the `[]` operator signature if available.
    String keyTypeName = 'Object?';
    if (type is InterfaceType) {
      final opElement = type.lookUpMethod('[]', type.element.library);
      if (opElement != null) {
        final params = opElement.formalParameters;
        if (params.isNotEmpty) {
          keyTypeName = _typeDisplayName(params.first.type);
        }
      }
    }

    return "rt.registerSubscript('$elementName.[]', "
        "(recv, key) => (recv as $typeName)[key as $keyTypeName]);";
  }

  /// Emit a `registerPayloadClass(...)` call for a payload class descriptor.
  ///
  /// Generates code that constructs a [PayloadClass] descriptor with all
  /// fields, constructors, and methods, then registers it via the global
  /// registerPayloadClass function.
  ///
  /// Payload classes are user-defined classes in @Screen bodies that can be
  /// instantiated at runtime via PayloadInstanceCreationNode.
  String emitPayloadClass(ClassElement cls) {
    final className = cls.name;

    // 1. Collect supertype reference (null for Object, otherwise qualified name).
    final supertypeRef = _emitSupertypeRef(cls);

    // 2. Collect mixins.
    final mixinsRef = _emitMixinsRef(cls);

    // 3. Collect field initializers (non-static fields initialized in their
    //    declaration or init expression). For now, we emit an empty map since
    //    field init expressions require lowering context not available here.
    //    Payload lowerer will populate fieldInitializers during class lowering.
    const fieldInitializersRef = '{}';

    // 4. Collect constructors.
    final ctorsRef = _emitCtorsRef(cls);

    // 5. Collect methods.
    final methodsRef = _emitMethodsRef(cls);

    // Emit the PayloadClass construction and registration.
    return "registerPayloadClass(\n"
        "  PayloadClass(\n"
        "    name: '$className',\n"
        "    supertype: $supertypeRef,\n"
        "    mixins: $mixinsRef,\n"
        "    fieldInitializers: $fieldInitializersRef,\n"
        "    ctors: $ctorsRef,\n"
        "    methods: $methodsRef,\n"
        "  ),\n"
        ");";
  }

  /// Emit the supertype reference for a payload class.
  ///
  /// Returns 'null' for Object, or a name reference for other payload classes.
  String _emitSupertypeRef(ClassElement cls) {
    final supertype = cls.supertype;
    if (supertype == null || supertype.isDartCoreObject) {
      return 'null';
    }
    // Payload classes can only extend other payload classes or Object.
    return "payloadClasses['${supertype.element.name}']";
  }

  /// Emit the mixins list for a payload class.
  String _emitMixinsRef(ClassElement cls) {
    if (cls.mixins.isEmpty) return '[]';
    final refs = cls.mixins
        .map((m) => "payloadClasses['${m.element.name}']!")
        .toList();
    return '[ ${refs.join(', ')} ]';
  }

  /// Emit the ctors map for a payload class.
  ///
  /// Maps constructor names ('' for unnamed) to PayloadCtor descriptors.
  /// Note: This is a placeholder; actual constructor bodies and field inits
  /// require lowering context and are populated during ast_to_ir lowering.
  String _emitCtorsRef(ClassElement cls) {
    // During codegen, we don't have access to lowered IR nodes (field inits,
    // body expressions). The lowerer in ast_to_ir will populate these when it
    // processes the PayloadClassNode. Here we emit an empty map as a placeholder.
    return '{}';
  }

  /// Emit the methods map for a payload class.
  ///
  /// Payload class methods are handled by the lowerer and require IR lowering
  /// context. Here we emit an empty map as a placeholder.
  String _emitMethodsRef(ClassElement cls) {
    // Methods require lowering context (expression -> IrNode conversion).
    // The lowerer populates this during ast_to_ir processing.
    return '{}';
  }

  /// Emit a `rt.registerValueBuilder(...)` call for a constructor element.
  ///
  /// Works for both unnamed (`EdgeInsets(...)`) and named (`EdgeInsets.all(...)`)
  /// constructors.
  ///
  /// If [typeArgOptions] is non-null and non-empty, emits a typeArgs-aware
  /// closure that switches on `args['__typeArgs__']?.firstOrNull` to construct
  /// the correctly typed instance (e.g. `<MyType>[]`). The [qualifiedName]
  /// must be a simple class name (not a named ctor) for the switch to apply.
  String emitValueBuilder(
    ConstructorElement ctor, {
    Set<String>? typeArgOptions,
  }) {
    final className = ctor.enclosingElement.name;
    final rawCtorName = ctor.name ?? '';
    // In analyzer 13, the unnamed constructor's name is 'new'; treat it as unnamed.
    final ctorName = rawCtorName == 'new' ? '' : rawCtorName;
    final qualifiedName = ctorName.isEmpty ? className : '$className.$ctorName';
    final callTarget = ctorName.isEmpty ? className : '$className.$ctorName';
    final params = ctor.formalParameters;
    final argsCode = _buildCallArgList(params);

    // Emit a typeArgs-aware closure only for the unnamed ctor (simple class
    // name) and when the caller provided a non-empty type-arg whitelist.
    if (ctorName.isEmpty &&
        typeArgOptions != null &&
        typeArgOptions.isNotEmpty) {
      return _emitGenericValueBuilder(
        qualifiedName,
        callTarget,
        params,
        typeArgOptions,
      );
    }

    return "rt.registerValueBuilder('$qualifiedName', (args) => $callTarget($argsCode));";
  }

  /// Emits a `rt.registerValueBuilder(...)` that switches on the
  /// `__typeArgs__` key to produce the correct typed instance.
  String _emitGenericValueBuilder(
    String? qualifiedName,
    String? callTarget,
    List<FormalParameterElement> params,
    Set<String> typeArgOptions,
  ) {
    final argsCode = _buildCallArgList(params);
    // Each case produces a typed constructor call. For collection-like ctors
    // with no params (e.g. `List()`) the call is `<T>[]`; for ctors with
    // params (e.g. `ValueNotifier(0)`) it's `<T>ValueNotifier(...)`. We
    // use the simple form here — callers with non-trivial generic ctors
    // register manually.
    final cases = typeArgOptions
        .map((t) => "    case '$t': return <$t>[];")
        .join('\n');
    return "rt.registerValueBuilder('$qualifiedName', (args) {\n"
        "  final typeArg = (args['__typeArgs__'] as List?)?.firstOrNull;\n"
        "  switch (typeArg) {\n"
        "$cases\n"
        "    case null: return $callTarget($argsCode);\n"
        "    default:\n"
        "      throw StateError('$qualifiedName<\\\$typeArg>: typeArg not registered. '\n"
        "          'Add the type to the @Screen body or register manually.');\n"
        "  }\n"
        "});";
  }

  /// Emit a `rt.registerFunction(...)` call for a top-level function.
  String emitFunction(TopLevelFunctionElement fn) {
    final params = fn.formalParameters;
    final argsCode = _buildCallArgList(params);
    return "rt.registerFunction('${fn.name}', (args) => ${fn.name}($argsCode));";
  }

  /// Emit a `rt.registerMethod(...)` call for a cascade setter (e.g.
  /// `..text = 'x'` on a `TextEditingController`).
  ///
  /// The registration name is `'ClassName.fieldName='` (Dart setter convention).
  /// The closure assigns `args['arg0']` to the named field on the cast receiver.
  String emitCascadeSetter(SetterElement setter) {
    // setter.displayName is 'text=' — strip the trailing '=' for field access.
    final enclosing = setter.enclosingElement;
    final className = (enclosing is InterfaceElement ? enclosing.name : null) ?? '';
    // displayName includes the trailing '=' for setters in analyzer 13.
    final displayName = setter.displayName;
    final fieldName = displayName.endsWith('=')
        ? displayName.substring(0, displayName.length - 1)
        : displayName;
    final registrationName = '$className.$fieldName=';
    final paramType = setter.formalParameters.isNotEmpty
        ? _typeDisplayName(setter.formalParameters.first.type)
        : 'Object?';
    return "rt.registerMethod('$registrationName', "
        "(recv, args) => (recv as $className).$fieldName = args['arg0'] as $paramType);";
  }

  /// Emit a `rt.registerSetter(...)` call for a non-final public instance field.
  ///
  /// The registration name is `'ClassName.fieldName'`. The closure mutates the
  /// field on the cast receiver. Used for payload-driven field assignment
  /// (e.g. `vm.count = 0` in a screen body).
  String emitFieldSetter(FieldElement field) {
    final enclosing = field.enclosingElement;
    final className =
        (enclosing is InterfaceElement ? enclosing.name : null) ?? '';
    final fieldName = field.name;
    final registrationName = '$className.$fieldName';
    final fieldType = _typeDisplayName(field.type);
    return "rt.registerSetter('$registrationName', (target, value) => "
        "(target as $className).$fieldName = value as $fieldType);";
  }

  /// Emit all public instance methods for a registered non-Widget class.
  ///
  /// Discovery rules:
  /// - Walk [cls].methods (analyzer element API).
  /// - Keep public methods (name doesn't start with '_').
  /// - Skip inherited Object members (toString, hashCode, ==, noSuchMethod, runtimeType).
  /// - Skip dispose if present (lifecycle, not callable).
  /// - Skip getters/setters (only methods).
  /// - Skip static methods (those are emitted as functions, not methods).
  ///
  /// Also emits `registerSetter` calls for non-final, public, non-late,
  /// non-static instance fields of the class.
  String emitMethodsForClass(ClassElement cls) {
    final lines = <String>[]
        ..add('// Methods for ${cls.name}')
        ..add('{');

    final skippedNames = {
      'toString',
      'hashCode',
      'noSuchMethod',
      'runtimeType',
      '==',
      'dispose',
      '-',
      '*',
      '/',
      '~/',
      '%',
      '[]',
      '[]=',
      'unary-',
      '+',
    };

    for (final method in cls.methods) {
      if (method.isStatic) continue;
      if (method.isPrivate) continue;
      final methodName = method.name;
      if (methodName == null) continue;
      if (skippedNames.contains(methodName)) continue;
      if (methodName.startsWith('_')) continue;

      final qualifiedName = '${cls.name}.$methodName';
      final params = method.formalParameters;
      final callArgs = _buildCallArgList(params);
      lines.add(
        "rt.registerMethod('$qualifiedName', "
        "(recv, args) => (recv as ${cls.name}).$methodName($callArgs));",
      );
    }

    // Emit setters for eligible fields.
    for (final field in cls.fields) {
      if (_isSetterEligible(field, cls)) {
        lines.add(emitFieldSetter(field));
      }
    }

    lines.add('}');
    return lines.join('\n');
  }

  /// Check if a field is eligible for setter registration.
  ///
  /// A field is eligible if:
  /// - It is public
  /// - It has an associated setter (i.e. it is settable — not getter-only,
  ///   not final, not const). This is the authoritative check for settability
  ///   in the analyzer element model and rejects:
  ///   * read-only getters whose synthetic field would otherwise leak through
  ///     (e.g. `EdgeInsetsGeometry.isNonNegative`, `Object.hashCode`)
  ///   * final fields (e.g. `Widget.key`)
  ///   * const fields
  /// - It is not late
  /// - It is not static
  /// - It is declared on this class (not merely inherited from a supertype
  ///   like `Widget` or `Object`).
  bool _isSetterEligible(FieldElement field, ClassElement owner) {
    if (!field.isPublic) return false;
    if (field.isStatic) return false;
    if (field.isLate) return false;
    if (field.isFinal) return false;
    // Reject getter-only synthetic fields and other non-settable properties.
    if (field.setter == null) return false;
    // Only emit setters for fields actually declared on `owner`, not those
    // inherited from a superclass (which would otherwise pull in `Widget.key`,
    // `Object.hashCode`, etc.).
    final enclosing = field.enclosingElement;
    if (enclosing is! InterfaceElement) return false;
    if (enclosing.name != owner.name) return false;
    return true;
  }

  /// Emit all registrations from a [CollectedTypes] set.
  ///
  /// Returns multi-line Dart code (one registration statement per line).
  String emitAll(CollectedTypes collected) {
    final lines = <String>[];

    for (final widget in collected.widgets) {
      // 1. Unnamed ctor (skip if widget is abstract with no unnamed factory).
      final unnamed = _unnamedCtor(widget);
      if (unnamed != null) {
        lines.add(_emitWidgetCtor(
          unnamed,
          registrationName: widget.name!,
          callTarget: widget.name!,
        ));
      } else if (!widget.isAbstract) {
        // Concrete widgets must have an unnamed ctor; emit the existing marker
        // comment for visibility.
        lines.add('// No unnamed constructor for ${widget.name}');
      }

      // 2. Public named factory ctors. Includes abstract widgets like `Cue`
      //    whose only instantiation paths are named factories.
      for (final ctor in widget.constructors) {
        final ctorName = ctor.name ?? '';
        if (ctorName.isEmpty || ctorName == 'new') continue; // handled above
        if (ctor.isPrivate) continue;
        final qualified = '${widget.name}.$ctorName';
        lines.add(_emitWidgetCtor(
          ctor,
          registrationName: qualified,
          callTarget: qualified,
        ));
      }
    }

    for (final valueType in collected.valueTypes) {
      // Skip the unnamed (default) builder for abstract classes — they can't
      // be directly instantiated.  Named factory constructors are still emitted
      // below so callers can use `CueMotion.smooth()`, `Act.scale()`, etc.
      if (!valueType.isAbstract) {
        final unnamed = _unnamedCtor(valueType);
        if (unnamed != null) {
          // Pass type-arg options discovered in the screen body (if any).
          final typeArgOptions =
              collected.genericCtorTypeArgs[valueType.name ?? ''];
          lines.add(emitValueBuilder(unnamed, typeArgOptions: typeArgOptions));
        }
      }
      for (final ctor in valueType.constructors) {
        final ctorName = ctor.name ?? '';
        // 'new' is analyzer 13's name for the unnamed ctor (handled above);
        // skip both the empty/'new' cases here so we only emit named ctors.
        if (ctorName.isNotEmpty && ctorName != 'new' && !ctor.isPrivate) {
          lines.add(emitValueBuilder(ctor));
        }
      }
    }

    for (final note in collected.notes) {
      lines.add(note);
    }

    for (final constant in collected.constants) {
      lines.add(emitConstant(constant));
    }

    for (final method in collected.methods) {
      final receiverType =
          (method.enclosingElement! as InterfaceElement).thisType;
      lines.add(emitMethod(method, receiverType: receiverType));
    }

    for (final subscriptable in collected.subscriptables) {
      lines.add(emitSubscript(subscriptable));
    }

    for (final fn in collected.functions) {
      lines.add(emitFunction(fn));
    }

    for (final setter in collected.cascadeSetters) {
      lines.add(emitCascadeSetter(setter));
    }

    return lines.join('\n');
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Find the unnamed constructor for [cls], or null if none.
  ConstructorElement? _unnamedCtor(ClassElement cls) {
    for (final ctor in cls.constructors) {
      // In analyzer 13, the unnamed constructor's name is 'new' (was '' in v7).
      final ctorName = ctor.name ?? '';
      if ((ctorName.isEmpty || ctorName == 'new') && !ctor.isPrivate) {
        return ctor;
      }
    }
    return null;
  }

  /// Build an argument list for **widget** closures where the args map is
  /// `Map<String, Object?>` named `args`.
  ///
  /// Named parameters:
  ///   - `children: List<Widget>` → special cast with fallback to `const []`
  ///   - required, no default → `args['name'] as TypeName`
  ///   - optional with default → `args['name'] as TypeName? ?? defaultValue`
  ///   - optional nullable, no default → `args['name'] as TypeName`
  ///
  /// Positional parameters are passed WITHOUT a `name:` label (since they are
  /// positional in the Dart call), but still read from the map using the
  /// declared parameter name as the key.
  String _buildWidgetArgList(List<FormalParameterElement> params) {
    if (params.isEmpty) return '';
    final parts = <String>[];
    for (final p in params) {
      final paramName = p.name;
      if (p.isNamed) {
        final typeStr = _typeDisplayName(p.type);
        final defaultCode = p.defaultValueCode;

        String valuePart;
        if (_isListOfWidget(p.type)) {
          valuePart =
              "(args['$paramName'] as List?)?.cast<Widget>() ?? const []";
        } else if (defaultCode != null) {
          // Strip the ? suffix when using defaultValue fallback to keep cast clean
          final baseTypeStr = _typeDisplayNameNoNull(p.type);
          valuePart = "args['$paramName'] as $baseTypeStr? ?? $defaultCode";
        } else {
          valuePart = "args['$paramName'] as $typeStr";
        }
        parts.add('$paramName: $valuePart');
      } else {
        // Positional: no label prefix — read from map by declared param name.
        final typeStr = _typeDisplayName(p.type);
        parts.add("args['$paramName'] as $typeStr");
      }
    }
    return parts.join(', ');
  }

  /// Build an argument list for **method / function / value-builder** closures
  /// where `args` is `Map<String, Object?>`.
  ///
  /// Named params use `args['name']` map access.
  /// Positional params use `args['arg0']`, `args['arg1']`, etc. — the resolver
  /// indexes positional IR nodes with the same `arg0`, `arg1` keys.
  String _buildCallArgList(List<FormalParameterElement> params) {
    if (params.isEmpty) return '';
    final parts = <String>[];
    var positionalIndex = 0;
    for (final p in params) {
      if (p.isNamed) {
        final paramName = p.name;
        final typeStr = _typeDisplayName(p.type);
        final defaultCode = p.defaultValueCode;
        String valuePart;
        if (defaultCode != null) {
          final baseTypeStr = _typeDisplayNameNoNull(p.type);
          valuePart = "args['$paramName'] as $baseTypeStr? ?? $defaultCode";
        } else {
          valuePart = "args['$paramName'] as $typeStr";
        }
        parts.add('$paramName: $valuePart');
      } else {
        final typeStr = _typeDisplayName(p.type);
        parts.add("args['arg$positionalIndex'] as $typeStr");
        positionalIndex++;
      }
    }
    return parts.join(', ');
  }

  /// Returns the Dart display string for [type] (includes nullability suffix).
  String _typeDisplayName(DartType type) {
    return type.getDisplayString();
  }

  /// Returns the display name with the trailing `?` stripped (if present).
  /// Used when we already add `?` for the cast before the `??` fallback.
  String _typeDisplayNameNoNull(DartType type) {
    if (type.nullabilitySuffix == NullabilitySuffix.question) {
      // Re-request without the `?` suffix so our cast pattern is `as Foo? ?? default`
      // rather than `as Foo?? ?? default`.
      final s = type.getDisplayString();
      if (s.endsWith('?')) return s.substring(0, s.length - 1);
    }
    return type.getDisplayString();
  }

  /// The simple element name of [type] (no type args, no nullability suffix).
  String? _typeElementName(DartType type) {
    if (type is InterfaceType) return type.element.name;
    return null;
  }

  /// True if [type] is `List<Widget>` or `List<Widget?>`.
  bool _isListOfWidget(DartType type) {
    if (type is! InterfaceType) return false;
    if (type.element.name != 'List') return false;
    if (type.typeArguments.isEmpty) return false;
    final arg = type.typeArguments.first;
    return _typeElementName(arg) == 'Widget';
  }
}
