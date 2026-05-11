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
    final params = ctor.parameters;
    final argsCode = _buildWidgetArgList(params);
    return "rt.registerWidget('${widget.name}', (args) => ${widget.name}($argsCode));";
  }

  /// Emit a `rt.registerConstant(...)` call for a static field or accessor.
  ///
  /// The qualified name is `ClassName.memberName`.
  String emitConstant(Element constant) {
    final className = constant.enclosingElement3?.name ?? '';
    final memberName = constant.name ?? '';
    final qualifiedName = '$className.$memberName';
    return "rt.registerConstant('$qualifiedName', $qualifiedName);";
  }

  /// Emit a `rt.registerMethod(...)` call for an instance method.
  ///
  /// [receiverType] is the static type on which the method is invoked — used
  /// for the cast expression and the qualified registration name.
  String emitMethod(MethodElement method, {required DartType receiverType}) {
    final receiverTypeName = _typeDisplayName(receiverType);
    final receiverClassName = method.enclosingElement3.name;
    final qualifiedName = '$receiverClassName.${method.name}';
    final params = method.parameters;
    final callArgs = _buildCallArgList(params);
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
      final opElement = type.lookUpMethod2('[]', type.element.library);
      if (opElement != null) {
        final params = opElement.parameters;
        if (params.isNotEmpty) {
          keyTypeName = _typeDisplayName(params.first.type);
        }
      }
    }

    return "rt.registerSubscript('$elementName.[]', "
        "(recv, key) => (recv as $typeName)[key as $keyTypeName]);";
  }

  /// Emit a `rt.registerValueBuilder(...)` call for a constructor element.
  ///
  /// Works for both unnamed (`EdgeInsets(...)`) and named (`EdgeInsets.all(...)`)
  /// constructors.
  String emitValueBuilder(ConstructorElement ctor) {
    final className = ctor.enclosingElement3.name;
    final ctorName = ctor.name;
    final qualifiedName = ctorName.isEmpty ? className : '$className.$ctorName';
    final callTarget = ctorName.isEmpty ? className : '$className.$ctorName';
    final params = ctor.parameters;
    final argsCode = _buildCallArgList(params);
    return "rt.registerValueBuilder('$qualifiedName', (args) => $callTarget($argsCode));";
  }

  /// Emit a `rt.registerFunction(...)` call for a top-level function.
  String emitFunction(FunctionElement fn) {
    final params = fn.parameters;
    final argsCode = _buildCallArgList(params);
    return "rt.registerFunction('${fn.name}', (args) => ${fn.name}($argsCode));";
  }

  /// Emit all registrations from a [CollectedTypes] set.
  ///
  /// Returns multi-line Dart code (one registration statement per line).
  String emitAll(CollectedTypes collected) {
    final lines = <String>[];

    for (final widget in collected.widgets) {
      lines.add(emitWidget(widget));
    }

    for (final valueType in collected.valueTypes) {
      final unnamed = _unnamedCtor(valueType);
      if (unnamed != null) {
        lines.add(emitValueBuilder(unnamed));
      }
      for (final ctor in valueType.constructors) {
        if (ctor.name.isNotEmpty && !ctor.isPrivate) {
          lines.add(emitValueBuilder(ctor));
        }
      }
    }

    for (final constant in collected.constants) {
      lines.add(emitConstant(constant));
    }

    for (final method in collected.methods) {
      final receiverType =
          (method.enclosingElement3 as InterfaceElement).thisType;
      lines.add(emitMethod(method, receiverType: receiverType));
    }

    for (final subscriptable in collected.subscriptables) {
      lines.add(emitSubscript(subscriptable));
    }

    for (final fn in collected.functions) {
      lines.add(emitFunction(fn));
    }

    return lines.join('\n');
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Find the unnamed constructor for [cls], or null if none.
  ConstructorElement? _unnamedCtor(ClassElement cls) {
    for (final ctor in cls.constructors) {
      if (ctor.name.isEmpty && !ctor.isPrivate) return ctor;
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
  String _buildWidgetArgList(List<ParameterElement> params) {
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
  String _buildCallArgList(List<ParameterElement> params) {
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
