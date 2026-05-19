part of 'package:desk_sdui_demo/screens/counter_demo.dart';

ScreenBinding get counter_demoBinding => ScreenBinding(
  name: 'counter_demo',
  ir: IrTree(
    name: 'counter_demo',
    version: 1,
    root: ScreenWithFunctionsNode(
      functions: [
        PayloadFunctionNode(
          name: 'tripled',
          params: ['x'],
          body: ArithOpNode(
            op: ArithOp.mul,
            left: RefNode(['x']),
            right: ConstNode(3),
          ),
        ),
      ],
      classes: [
        PayloadClassNode(
          name: 'Counter',
          mixinNames: [],
          fields: [
            PayloadFieldDeclNode(
              name: 'count',
              initializer: LiteralNode(0),
              isFinal: false,
            ),
            PayloadFieldDeclNode(
              name: 'step',
              initializer: LiteralNode(1),
              isFinal: false,
            ),
            PayloadFieldDeclNode(
              name: 'history',
              initializer: ListNode([]),
              isFinal: false,
            ),
            PayloadFieldDeclNode(
              name: 'busy',
              initializer: LiteralNode(false),
              isFinal: false,
            ),
            PayloadFieldDeclNode(
              name: 'mode',
              initializer: LiteralNode('add'),
              isFinal: false,
            ),
          ],
          ctors: [],
          methods: [],
        ),
      ],
      screenBody: BlockNode(
        statements: [
          LetStatementNode(
            name: 'label',
            value: ConstNode('Counter'),
            isFinal: false,
          ),
          AssignNode(
            name: 'label',
            value: StringInterpNode([
              GetterNode(receiver: RefNode(['c']), name: 'Counter.count'),
            ]),
          ),
          LetStatementNode(
            name: 'theme',
            value: MethodCallNode(
              receiver: null,
              name: 'Theme.of',
              args: [
                RefNode(['context']),
              ],
            ),
            isFinal: true,
          ),
          LetStatementNode(
            name: 'doubled',
            value: ArithOpNode(
              op: ArithOp.mul,
              left: GetterNode(receiver: RefNode(['c']), name: 'Counter.count'),
              right: ConstNode(2),
            ),
            isFinal: true,
          ),
          LetStatementNode(
            name: 'tripled_val',
            value: PayloadFunctionCallNode(
              name: 'tripled',
              args: [
                GetterNode(receiver: RefNode(['c']), name: 'Counter.count'),
              ],
            ),
            isFinal: true,
          ),
          LetStatementNode(
            name: 'status',
            value: LetNode(
              name: '__scrut0__',
              value: GetterNode(receiver: RefNode(['c']), name: 'Counter.mode'),
              body: ConditionalNode(
                condition: CompareOpNode(
                  op: CompareOp.eq,
                  left: RefNode(['__scrut0__']),
                  right: ConstNode('add'),
                ),
                thenBranch: ConstNode('Adding'),
                elseBranch: ConditionalNode(
                  condition: CompareOpNode(
                    op: CompareOp.eq,
                    left: RefNode(['__scrut0__']),
                    right: ConstNode('sub'),
                  ),
                  thenBranch: ConstNode('Subtracting'),
                  elseBranch: ConstNode('Idle'),
                ),
              ),
            ),
            isFinal: true,
          ),
          LetStatementNode(
            name: 'historySum',
            value: ConstNode(0),
            isFinal: false,
          ),
          ImperativeForNode(
            init: LetStatementNode(
              name: 'i',
              value: ConstNode(0),
              isFinal: false,
            ),
            condition: CompareOpNode(
              op: CompareOp.lt,
              left: RefNode(['i']),
              right: LengthOfNode(
                GetterNode(receiver: RefNode(['c']), name: 'Counter.history'),
              ),
            ),
            update: AssignNode(
              name: 'i',
              value: ArithOpNode(
                op: ArithOp.add,
                left: RefNode(['i']),
                right: ConstNode(1),
              ),
            ),
            body: BlockNode(
              statements: [
                AssignNode(
                  name: 'historySum',
                  value: ArithOpNode(
                    op: ArithOp.add,
                    left: RefNode(['historySum']),
                    right: IndexAccessNode(
                      target: GetterNode(
                        receiver: RefNode(['c']),
                        name: 'Counter.history',
                      ),
                      key: RefNode(['i']),
                    ),
                  ),
                ),
              ],
            ),
          ),
          LetStatementNode(
            name: 'countdown',
            value: ConstNode(5),
            isFinal: false,
          ),
          LetStatementNode(
            name: 'countdownStr',
            value: ConstNode(''),
            isFinal: false,
          ),
          WhileNode(
            condition: CompareOpNode(
              op: CompareOp.gt,
              left: RefNode(['countdown']),
              right: ConstNode(0),
            ),
            body: BlockNode(
              statements: [
                AssignNode(
                  name: 'countdownStr',
                  value: StringInterpNode([
                    RefNode(['countdownStr']),
                    RefNode(['countdown']),
                    ',',
                  ]),
                ),
                AssignNode(
                  name: 'countdown',
                  value: ArithOpNode(
                    op: ArithOp.sub,
                    left: RefNode(['countdown']),
                    right: ConstNode(1),
                  ),
                ),
              ],
            ),
          ),
          ReturnNode(
            value: WidgetNode(
              name: 'Center',
              args: {
                'child': WidgetNode(
                  name: 'SingleChildScrollView',
                  args: {
                    'child': WidgetNode(
                      name: 'Column',
                      args: {
                        'mainAxisAlignment': RefNode([
                          'MainAxisAlignment',
                          'center',
                        ]),
                        'children': ListNode([
                          WidgetNode(
                            name: 'Text',
                            args: {
                              'data': RefNode(['label']),
                              'style': GetterNode(
                                receiver: GetterNode(
                                  receiver: RefNode(['theme']),
                                  name: 'ThemeData.textTheme',
                                ),
                                name: 'TextTheme.headlineLarge',
                              ),
                            },
                          ),
                          WidgetNode(
                            name: 'SizedBox',
                            args: {'height': ConstNode(8)},
                          ),
                          WidgetNode(
                            name: 'Text',
                            args: {
                              'data': StringInterpNode([
                                'Mode: ',
                                RefNode(['status']),
                              ]),
                              'style': GetterNode(
                                receiver: GetterNode(
                                  receiver: RefNode(['theme']),
                                  name: 'ThemeData.textTheme',
                                ),
                                name: 'TextTheme.labelLarge',
                              ),
                            },
                          ),
                          WidgetNode(
                            name: 'SizedBox',
                            args: {'height': ConstNode(16)},
                          ),
                          WidgetNode(
                            name: 'Text',
                            args: {
                              'data': StringInterpNode([
                                'Doubled: ',
                                RefNode(['doubled']),
                              ]),
                            },
                          ),
                          WidgetNode(
                            name: 'Text',
                            args: {
                              'data': StringInterpNode([
                                'Tripled: ',
                                RefNode(['tripled_val']),
                              ]),
                            },
                          ),
                          WidgetNode(
                            name: 'Text',
                            args: {
                              'data': StringInterpNode([
                                'Sum: ',
                                RefNode(['historySum']),
                              ]),
                            },
                          ),
                          WidgetNode(
                            name: 'SizedBox',
                            args: {'height': ConstNode(16)},
                          ),
                          WidgetNode(
                            name: 'Row',
                            args: {
                              'mainAxisAlignment': RefNode([
                                'MainAxisAlignment',
                                'center',
                              ]),
                              'children': ListNode([
                                WidgetNode(
                                  name: 'ElevatedButton',
                                  args: {
                                    'onPressed': EventNode(
                                      ['a', 'decrementCount'],
                                      args: {
                                        'arg0': RefNode(['c']),
                                      },
                                    ),
                                    'child': WidgetNode(
                                      name: 'Text',
                                      args: {'data': ConstNode('-')},
                                    ),
                                  },
                                ),
                                WidgetNode(
                                  name: 'SizedBox',
                                  args: {'width': ConstNode(12)},
                                ),
                                WidgetNode(
                                  name: 'ElevatedButton',
                                  args: {
                                    'onPressed': EventNode(
                                      ['a', 'incrementCount'],
                                      args: {
                                        'arg0': RefNode(['c']),
                                      },
                                    ),
                                    'child': WidgetNode(
                                      name: 'Text',
                                      args: {'data': ConstNode('+')},
                                    ),
                                  },
                                ),
                              ]),
                            },
                          ),
                          WidgetNode(
                            name: 'SizedBox',
                            args: {'height': ConstNode(12)},
                          ),
                          WidgetNode(
                            name: 'Row',
                            args: {
                              'mainAxisAlignment': RefNode([
                                'MainAxisAlignment',
                                'center',
                              ]),
                              'children': ListNode([
                                WidgetNode(
                                  name: 'ElevatedButton',
                                  args: {
                                    'onPressed': EventNode(
                                      ['a', 'setStep'],
                                      args: {
                                        'arg0': RefNode(['c']),
                                        'arg1': LiteralNode(1),
                                      },
                                    ),
                                    'child': WidgetNode(
                                      name: 'Text',
                                      args: {'data': ConstNode('Step +1')},
                                    ),
                                  },
                                ),
                                WidgetNode(
                                  name: 'SizedBox',
                                  args: {'width': ConstNode(8)},
                                ),
                                WidgetNode(
                                  name: 'ElevatedButton',
                                  args: {
                                    'onPressed': EventNode(
                                      ['a', 'setStep'],
                                      args: {
                                        'arg0': RefNode(['c']),
                                        'arg1': LiteralNode(5),
                                      },
                                    ),
                                    'child': WidgetNode(
                                      name: 'Text',
                                      args: {'data': ConstNode('Step +5')},
                                    ),
                                  },
                                ),
                              ]),
                            },
                          ),
                          WidgetNode(
                            name: 'SizedBox',
                            args: {'height': ConstNode(12)},
                          ),
                          WidgetNode(
                            name: 'Row',
                            args: {
                              'mainAxisAlignment': RefNode([
                                'MainAxisAlignment',
                                'center',
                              ]),
                              'children': ListNode([
                                WidgetNode(
                                  name: 'ElevatedButton',
                                  args: {
                                    'onPressed': EventNode(
                                      ['a', 'setMode'],
                                      args: {
                                        'arg0': RefNode(['c']),
                                        'arg1': LiteralNode('add'),
                                      },
                                    ),
                                    'child': WidgetNode(
                                      name: 'Text',
                                      args: {'data': ConstNode('Add')},
                                    ),
                                  },
                                ),
                                WidgetNode(
                                  name: 'SizedBox',
                                  args: {'width': ConstNode(8)},
                                ),
                                WidgetNode(
                                  name: 'ElevatedButton',
                                  args: {
                                    'onPressed': EventNode(
                                      ['a', 'setMode'],
                                      args: {
                                        'arg0': RefNode(['c']),
                                        'arg1': LiteralNode('sub'),
                                      },
                                    ),
                                    'child': WidgetNode(
                                      name: 'Text',
                                      args: {'data': ConstNode('Sub')},
                                    ),
                                  },
                                ),
                              ]),
                            },
                          ),
                          WidgetNode(
                            name: 'SizedBox',
                            args: {'height': ConstNode(12)},
                          ),
                          WidgetNode(
                            name: 'ElevatedButton',
                            args: {
                              'onPressed': EventNode(
                                ['a', 'incrementCount'],
                                args: {
                                  'arg0': RefNode(['c']),
                                },
                              ),
                              'child': WidgetNode(
                                name: 'Text',
                                args: {'data': ConstNode('Add to history')},
                              ),
                            },
                          ),
                          WidgetNode(
                            name: 'SizedBox',
                            args: {'height': ConstNode(16)},
                          ),
                          WidgetNode(
                            name: 'ElevatedButton',
                            args: {
                              'onPressed': ActionSequenceNode(
                                steps: [
                                  TryStepNode(
                                    trySteps: [
                                      ActionStepNode(
                                        call: MethodCallNode(
                                          receiver: RefNode(['a']),
                                          name: 'save',
                                          args: [
                                            RefNode(['c']),
                                          ],
                                        ),
                                        awaitResult: true,
                                      ),
                                    ],
                                    catchSteps: [
                                      ActionStepNode(
                                        call: MethodCallNode(
                                          receiver: RefNode(['a']),
                                          name: 'handleSaveError',
                                          args: [
                                            RefNode(['c']),
                                          ],
                                        ),
                                        awaitResult: false,
                                      ),
                                    ],
                                    exceptionBind: 'e',
                                  ),
                                ],
                              ),
                              'child': WidgetNode(
                                name: 'Text',
                                args: {'data': ConstNode('Save')},
                              ),
                            },
                          ),
                          WidgetNode(
                            name: 'SizedBox',
                            args: {'height': ConstNode(12)},
                          ),
                          WidgetNode(
                            name: 'ElevatedButton',
                            args: {
                              'onPressed': EventNode(
                                ['a', 'reset'],
                                args: {
                                  'arg0': RefNode(['c']),
                                },
                              ),
                              'child': WidgetNode(
                                name: 'Text',
                                args: {'data': ConstNode('Reset')},
                              ),
                            },
                          ),
                          WidgetNode(
                            name: 'SizedBox',
                            args: {'height': ConstNode(16)},
                          ),
                          ConditionalNode(
                            condition: GetterNode(
                              receiver: GetterNode(
                                receiver: RefNode(['c']),
                                name: 'Counter.history',
                              ),
                              name: 'List.isNotEmpty',
                            ),
                            thenBranch: WidgetNode(
                              name: 'Column',
                              args: {
                                'children': ListNode([
                                  WidgetNode(
                                    name: 'Text',
                                    args: {'data': ConstNode('History:')},
                                  ),
                                  WidgetNode(
                                    name: 'Row',
                                    args: {
                                      'mainAxisAlignment': RefNode([
                                        'MainAxisAlignment',
                                        'center',
                                      ]),
                                      'children': ListNode([
                                        ForNode(
                                          variable: 'v',
                                          source: GetterNode(
                                            receiver: RefNode(['c']),
                                            name: 'Counter.history',
                                          ),
                                          body: WidgetNode(
                                            name: 'Text',
                                            args: {
                                              'data': StringInterpNode([
                                                RefNode(['v']),
                                                ',',
                                              ]),
                                            },
                                          ),
                                        ),
                                      ]),
                                    },
                                  ),
                                ]),
                              },
                            ),
                            elseBranch: WidgetNode(
                              name: 'Text',
                              args: {'data': ConstNode('(empty)')},
                            ),
                          ),
                          WidgetNode(
                            name: 'SizedBox',
                            args: {'height': ConstNode(8)},
                          ),
                          WidgetNode(
                            name: 'Text',
                            args: {
                              'data': StringInterpNode([
                                'Countdown: ',
                                RefNode(['countdownStr']),
                              ]),
                            },
                          ),
                        ]),
                      },
                    ),
                  },
                ),
              },
            ),
          ),
        ],
      ),
    ),
  ),
  inputs: [
    InputBinding(name: 'context', read: (v) => v as dynamic),
    InputBinding(name: 'c', read: (v) => v as dynamic),
    InputBinding(name: 'a', read: (v) => v as dynamic),
  ],
  methodRefs: {
    'a': ['decrementCount', 'incrementCount', 'setStep', 'setMode', 'reset'],
  },
  reactives: const [],
);
