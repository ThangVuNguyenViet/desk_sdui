import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

import 'cell.dart';

/// Runtime descriptor for a single constructor in a payload class.
class PayloadCtor {
  PayloadCtor({
    required this.name,
    required this.params,
    required this.fieldInits,
    this.body,
  });

  final String name;
  final List<String> params;
  final Map<String, IrNode> fieldInits;
  final IrNode? body;
}

/// Descriptor for a payload-defined class.
///
/// Holds the class metadata including supertype, mixins, methods, field
/// initializers, and constructor information. The method lookup order (mro) is
/// computed at registration time and cached for efficient method dispatch.
class PayloadClass {
  PayloadClass({
    required this.name,
    this.supertype,
    this.mixins = const [],
    this.methods = const {},
    this.fieldInitializers = const {},
    this.ctors = const {},
    // Backward compatibility: single unnamed ctor (F15 compatibility)
    this.ctorParams = const [],
    this.ctorBody,
    this.isMixin = false,
  });

  final String name;
  final PayloadClass? supertype;
  final List<PayloadClass> mixins;
  final Map<String, PayloadFunctionNode> methods;
  final Map<String, IrNode> fieldInitializers;

  /// Map of constructor names to PayloadCtor descriptors.
  /// The key is the constructor name ('' for unnamed).
  final Map<String, PayloadCtor> ctors;

  // Backward compatibility fields (F15 single-ctor support)
  final List<String> ctorParams;
  final IrNode? ctorBody;

  /// True if this descriptor represents a mixin (non-instantiable).
  final bool isMixin;

  /// Resolved at registration time. Drives method dispatch (Feature 17).
  late final List<PayloadClass> methodLookupOrder;
}

/// An instance of a payload-defined class.
///
/// Stores the class type and a map of mutable field cells. Each field is
/// backed by a [Cell] to allow mutation during runtime.
class PayloadInstance {
  PayloadInstance({required this.type, required this.fields});

  final PayloadClass type;
  final Map<String, Cell> fields;

  @override
  String toString() =>
      '${type.name}(${fields.entries.map((e) => "${e.key}: ${e.value.value}").join(", ")})';
}

/// Runtime type value returned by [RuntimeTypeRefNode] for payload instances.
/// Comparable by identity (same class name = equal).
class PayloadTypeValue {
  PayloadTypeValue(this.cls);
  final PayloadClass cls;

  @override
  bool operator ==(Object other) =>
      other is PayloadTypeValue && other.cls.name == cls.name;

  @override
  int get hashCode => cls.name.hashCode;

  @override
  String toString() => cls.name;
}
