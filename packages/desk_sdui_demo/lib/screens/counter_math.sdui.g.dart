part of 'package:desk_sdui_demo/screens/counter_math.dart';

ScreenBinding get counter_mathBinding => ScreenBinding(
  name: 'counter_math',
  ir: IrTree(
    name: 'counter_math',
    version: 1,
    root: WidgetNode(
      name: 'Center',
      args: {
        'child': WidgetNode(
          name: 'Text',
          args: {
            'data': StringInterpNode([
              ArithOpNode(
                op: ArithOp.intDiv,
                left: ArithOpNode(
                  op: ArithOp.add,
                  left: ArithOpNode(
                    op: ArithOp.mul,
                    left: RefNode(['data', 'value']),
                    right: ConstNode(2),
                  ),
                  right: ConstNode(1),
                ),
                right: ConstNode(3),
              ),
            ]),
            'style': WidgetNode(
              name: 'TextStyle',
              args: {
                'fontSize': ConstNode(64),
                'fontWeight': RefNode(['FontWeight', 'w800']),
              },
            ),
          },
        ),
      },
    ),
  ),
  inputs: [InputBinding(name: 'data', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
