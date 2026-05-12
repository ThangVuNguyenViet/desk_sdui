import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'try_step_demo.sdui.g.dart';

class SaveController {
  SaveController({this.onError, this.onSaved});
  final void Function(Object e)? onError;
  final VoidCallback? onSaved;

  Future<void> save() async {
    await Future.delayed(const Duration(milliseconds: 100));
    throw StateError('save failed (demo)');
  }

  void showError(Object e) => onError?.call(e);
}

@Screen('try_step_demo')
Widget tryStepDemo(SaveController vm) {
  return ElevatedButton(
    onPressed: () async {
      try {
        await vm.save();
      } catch (e) {
        vm.showError(e);
      }
    },
    child: const Text('Save'),
  );
}
