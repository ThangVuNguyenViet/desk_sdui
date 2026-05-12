// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'type_collector.dart';

/// Walks a [CollectedTypes] and returns a sorted list of unique
/// `import '...';` lines covering every reachable element's library.
///
/// Skips:
///   - `dart:core` (always available)
///   - URIs already covered by [excludedUris]
///   - any element whose library URI is null / empty
///   - any URI whose scheme is not `dart:` or `package:`
///
/// For `package:` URIs, [packageName] controls normalization:
///   - URIs for [packageName] itself are kept as-is.
///   - URIs for packages in [excludedPackages] are skipped.
///   - All other `package:` URIs are normalized to `package:$pkg/$pkg.dart`.
List<String> emitImportsForCollectedTypes({
  required CollectedTypes collected,
  required String packageName,
  Set<String> excludedPackages = const {},
  Set<String> excludedUris = const {},
}) {
  final uris = <String>{};

  void recordElement(Element element) {
    final uri = element.library?.firstFragment.source.uri.toString();
    if (uri == null || uri.isEmpty) return;
    if (uri == 'dart:core') return;
    uris.add(uri);
  }

  void recordDartType(DartType type) {
    final element = type.element;
    if (element != null) {
      recordElement(element);
    }
    if (type is InterfaceType) {
      for (final arg in type.typeArguments) {
        recordDartType(arg);
      }
    }
    if (type is RecordType) {
      for (final field in type.positionalFields) {
        recordDartType(field.type);
      }
      for (final field in type.namedFields) {
        recordDartType(field.type);
      }
    }
  }

  // Walk widgets and valueTypes, including constructor parameter types.
  for (final cls in {...collected.widgets, ...collected.valueTypes}) {
    recordElement(cls);
    for (final ctor in cls.constructors) {
      for (final param in ctor.formalParameters) {
        recordDartType(param.type);
      }
    }
  }

  // Constants: enclosing element (class) and the constant itself.
  for (final constant in collected.constants) {
    final enclosing = constant.enclosingElement;
    if (enclosing != null) recordElement(enclosing);
    recordElement(constant);
  }

  // Methods: enclosing element (class), method itself, and parameter types.
  for (final method in collected.methods) {
    final enclosing = method.enclosingElement;
    if (enclosing != null) recordElement(enclosing);
    recordElement(method);
    for (final param in method.formalParameters) {
      recordDartType(param.type);
    }
  }

  // Subscriptables: the type's element and its type arguments.
  for (final subscriptable in collected.subscriptables) {
    recordDartType(subscriptable);
  }

  // Functions: function itself and parameter types.
  for (final fn in collected.functions) {
    recordElement(fn);
    for (final param in fn.formalParameters) {
      recordDartType(param.type);
    }
  }

  // Convert URIs to import lines.
  final lines = <String>{};

  for (final uri in uris) {
    if (excludedUris.contains(uri)) continue;

    String importUri;
    if (uri.startsWith('package:')) {
      final pkg = uri.substring('package:'.length).split('/').first;
      if (excludedPackages.contains(pkg)) continue;
      if (pkg == packageName) {
        importUri = uri;
      } else {
        importUri = 'package:$pkg/$pkg.dart';
      }
    } else if (uri.startsWith('dart:')) {
      importUri = uri;
    } else {
      continue;
    }

    lines.add("import '$importUri';");
  }

  return lines.toList()..sort();
}
