import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/widgets.dart';

import 'resolve.dart';
import 'runtime.dart';

class SduiScreen extends StatefulWidget {
  const SduiScreen({
    required this.runtime,
    required this.ir,
    this.inputs = const {},
    super.key,
  });

  final Runtime runtime;
  final IrTree ir;
  final Map<String, Object?> inputs;

  @override
  State<SduiScreen> createState() => _SduiScreenState();
}

class _SduiScreenState extends State<SduiScreen> {
  @override
  Widget build(BuildContext context) {
    try {
      final binding = widget.runtime.screenFor(widget.ir.name);
      final input = _composeInput(binding, widget.inputs, context);
      return resolveNode(
        context,
        widget.ir.root,
        input,
        widget.runtime,
      );
    } catch (error) {
      return widget.runtime.errorBuilder?.call(context, error) ??
          ErrorWidget(error);
    }
  }

  Map<String, Object?> _composeInput(
    ScreenBinding? binding,
    Map<String, Object?> userInputs,
    BuildContext context,
  ) {
    final input = <String, Object?>{
      'context': context,
      ...userInputs,
    };
    if (binding != null) {
      final methods = <String, Function>{};
      for (final entry in userInputs.entries) {
        final value = entry.value;
        if (value == null) continue;
        final typeName = value.runtimeType.toString();
        for (final methodName in binding.referencedMethodsFor(entry.key)) {
          // Try _callables first (unified registry), then _methods registry.
          final callable = widget.runtime.callableFor('$typeName.$methodName');
          if (callable != null) {
            methods['${entry.key}.$methodName'] =
                () => callable({r'$this': value});
            continue;
          }
          final handler =
              widget.runtime.resolveMethodHandler('$typeName.$methodName');
          if (handler == null) continue;
          // _bindEvent calls the stored fn via Function.apply(fn, positionalArgs).
          // Wrap handler so it accepts positional args and forwards them as
          // arg0, arg1, ... to the SduiMethodHandler.
          methods['${entry.key}.$methodName'] =
              (Object? arg0, [Object? arg1, Object? arg2]) {
            final args = <String, Object?>{'arg0': arg0};
            if (arg1 != null) args['arg1'] = arg1;
            if (arg2 != null) args['arg2'] = arg2;
            return handler(value, args);
          };
        }
      }
      input['__methods__'] = methods;

      final reactives = <String, Listenable>{};
      for (final r in binding.reactives) {
        reactives[r.path.join('.')] = r.read(userInputs);
      }
      input['__reactive__'] = reactives;
    }
    return input;
  }
}
