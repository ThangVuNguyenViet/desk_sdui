import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/widgets.dart';

import 'resolve.dart';
import 'runtime.dart';

class SduiScreen extends StatefulWidget {
  const SduiScreen({
    required this.runtime,
    required this.name,
    this.inputs = const {},
    super.key,
  });

  final Runtime runtime;
  final String name;
  final Map<String, Object?> inputs;

  @override
  State<SduiScreen> createState() => _SduiScreenState();
}

class _SduiScreenState extends State<SduiScreen> {
  late Future<IrTree> _ir;

  @override
  void initState() {
    super.initState();
    _ir = widget.runtime.load(widget.name);
  }

  @override
  void didUpdateWidget(SduiScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name || oldWidget.runtime != widget.runtime) {
      _ir = widget.runtime.load(widget.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IrTree>(
      future: _ir,
      builder: (ctx, snap) {
        if (snap.hasError) {
          return widget.runtime.errorBuilder?.call(ctx, snap.error!) ??
              ErrorWidget(snap.error!);
        }
        if (!snap.hasData) {
          return widget.runtime.loadingBuilder?.call(ctx) ??
              const SizedBox.shrink();
        }
        final binding = widget.runtime.screenFor(widget.name);
        final input = _composeInput(binding, widget.inputs, context);
        return resolveNode(
          ctx,
          snap.data!.root,
          input,
          widget.runtime,
        );
      },
    );
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
          final fn = widget.runtime.callableFor('$typeName.$methodName');
          if (fn == null) continue;
          methods['${entry.key}.$methodName'] =
              () => fn({r'$this': value});
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
