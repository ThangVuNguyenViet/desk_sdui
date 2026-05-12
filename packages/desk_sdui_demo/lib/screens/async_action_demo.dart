import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'async_action_demo.sdui.g.dart';

class AsyncActionController {
  AsyncActionController({this.onLogged});
  final void Function(String message)? onLogged;

  Future<String> simulateLogin() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return 'guest-123';
  }

  void log(String msg) => onLogged?.call(msg);
}

@Screen('async_action_demo')
Widget asyncActionDemo(AsyncActionController vm) {
  return Center(
    child: ElevatedButton(
      onPressed: () async {
        final user = await vm.simulateLogin();
        vm.log('Logged in as $user');
      },
      child: const Text('Login'),
    ),
  );
}
