part of 'package:desk_sdui_demo/screens/async_action_demo.dart';

ScreenBinding get async_action_demoBinding => ScreenBinding(
  name: 'async_action_demo',
  ir: IrTree(
    name: 'async_action_demo',
    version: 1,
    root: WidgetNode(
      name: 'Center',
      args: {
        'child': WidgetNode(
          name: 'ElevatedButton',
          args: {
            'onPressed': ActionSequenceNode(
              steps: [
                ActionStepNode(
                  call: MethodCallNode(
                    receiver: RefNode(['vm']),
                    name: 'simulateLogin',
                    args: [],
                  ),
                  awaitResult: true,
                  bindResult: 'user',
                ),
                ActionStepNode(
                  call: MethodCallNode(
                    receiver: RefNode(['vm']),
                    name: 'log',
                    args: [
                      StringInterpNode([
                        'Logged in as ',
                        RefNode(['user']),
                      ]),
                    ],
                  ),
                  awaitResult: false,
                ),
              ],
            ),
            'child': WidgetNode(
              name: 'Text',
              args: {'data': ConstNode('Login')},
            ),
          },
        ),
      },
    ),
  ),
  inputs: [InputBinding(name: 'vm', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
