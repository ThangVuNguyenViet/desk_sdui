part of 'package:desk_sdui_demo/screens/try_step_demo.dart';

ScreenBinding get try_step_demoBinding => ScreenBinding(
  name: 'try_step_demo',
  ir: IrTree(
    name: 'try_step_demo',
    version: 1,
    root: WidgetNode(
      name: 'ElevatedButton',
      args: {
        'onPressed': ActionSequenceNode(
          steps: [
            TryStepNode(
              trySteps: [
                ActionStepNode(
                  call: MethodCallNode(
                    receiver: RefNode(['vm']),
                    name: 'save',
                    args: [],
                  ),
                  awaitResult: true,
                ),
              ],
              catchSteps: [
                ActionStepNode(
                  call: MethodCallNode(
                    receiver: RefNode(['vm']),
                    name: 'showError',
                    args: [
                      RefNode(['e']),
                    ],
                  ),
                  awaitResult: false,
                ),
              ],
              exceptionBind: 'e',
            ),
          ],
        ),
        'child': WidgetNode(name: 'Text', args: {'data': ConstNode('Save')}),
      },
    ),
  ),
  inputs: [InputBinding(name: 'vm', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
