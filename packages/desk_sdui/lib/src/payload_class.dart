import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

import 'cell.dart';

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
    this.ctorParams = const [],
    this.ctorBody,
  });

  final String name;
  final PayloadClass? supertype;
  final List<PayloadClass> mixins;
  final Map<String, PayloadFunctionNode> methods;
  final Map<String, IrNode> fieldInitializers;
  final List<String> ctorParams;
  final IrNode? ctorBody;

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
