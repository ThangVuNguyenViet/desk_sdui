part of 'package:desk_sdui_demo/screens/chef.dart';

ScreenBinding get chefBinding => ScreenBinding(
  name: 'chef',
  ir: IrTree(
    name: 'chef',
    version: 1,
    root: WidgetNode(
      name: 'Stack',
      args: {
        'children': ListNode([
          WidgetNode(
            name: 'SingleChildScrollView',
            args: {
              'padding': WidgetNode(
                name: 'only',
                args: {'top': ConstNode(102), 'bottom': ConstNode(130)},
              ),
              'child': WidgetNode(
                name: 'Column',
                args: {
                  'crossAxisAlignment': RefNode([
                    'CrossAxisAlignment',
                    'stretch',
                  ]),
                  'children': ListNode([
                    WidgetNode(
                      name: 'Padding',
                      args: {
                        'padding': WidgetNode(
                          name: 'fromLTRB',
                          args: {
                            'arg0': ConstNode(24),
                            'arg1': ConstNode(10),
                            'arg2': ConstNode(24),
                            'arg3': ConstNode(22),
                          },
                        ),
                        'child': WidgetNode(
                          name: 'Column',
                          args: {
                            'crossAxisAlignment': RefNode([
                              'CrossAxisAlignment',
                              'start',
                            ]),
                            'children': ListNode([
                              WidgetNode(
                                name: 'Text',
                                args: {
                                  'data': RefNode(['data', 'headline']),
                                  'style': WidgetNode(
                                    name: 'TextStyle',
                                    args: {
                                      'fontSize': ConstNode(40),
                                      'height': ConstNode(1.02),
                                      'fontStyle': RefNode([
                                        'FontStyle',
                                        'italic',
                                      ]),
                                      'fontWeight': RefNode([
                                        'FontWeight',
                                        'w500',
                                      ]),
                                      'letterSpacing': ArithOpNode(
                                        op: ArithOp.sub,
                                        left: ConstNode(0),
                                        right: ConstNode(0.6),
                                      ),
                                    },
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
                                  'data': RefNode(['data', 'bio']),
                                  'style': WidgetNode(
                                    name: 'TextStyle',
                                    args: {
                                      'fontSize': ConstNode(13.5),
                                      'color': WidgetNode(
                                        name: 'Color',
                                        args: {'arg0': ConstNode(4285229931)},
                                      ),
                                      'height': ConstNode(1.55),
                                    },
                                  ),
                                },
                              ),
                            ]),
                          },
                        ),
                      },
                    ),
                    WidgetNode(
                      name: 'Container',
                      args: {
                        'margin': WidgetNode(
                          name: 'fromLTRB',
                          args: {
                            'arg0': ConstNode(20),
                            'arg1': ConstNode(0),
                            'arg2': ConstNode(20),
                            'arg3': ConstNode(26),
                          },
                        ),
                        'color': WidgetNode(
                          name: 'Color',
                          args: {'arg0': ConstNode(4281163565)},
                        ),
                        'child': WidgetNode(
                          name: 'Padding',
                          args: {
                            'padding': WidgetNode(
                              name: 'fromLTRB',
                              args: {
                                'arg0': ConstNode(24),
                                'arg1': ConstNode(28),
                                'arg2': ConstNode(24),
                                'arg3': ConstNode(24),
                              },
                            ),
                            'child': WidgetNode(
                              name: 'Column',
                              args: {
                                'crossAxisAlignment': RefNode([
                                  'CrossAxisAlignment',
                                  'start',
                                ]),
                                'children': ListNode([
                                  WidgetNode(
                                    name: 'Text',
                                    args: {
                                      'data': ConstNode(
                                        'Cooking is about patience, passion, and the pursuit of flavor that lingers in memory.',
                                      ),
                                      'style': WidgetNode(
                                        name: 'TextStyle',
                                        args: {
                                          'fontSize': ConstNode(22),
                                          'height': ConstNode(1.28),
                                          'fontStyle': RefNode([
                                            'FontStyle',
                                            'italic',
                                          ]),
                                          'color': WidgetNode(
                                            name: 'Color',
                                            args: {
                                              'arg0': ConstNode(4293454056),
                                            },
                                          ),
                                          'letterSpacing': ArithOpNode(
                                            op: ArithOp.sub,
                                            left: ConstNode(0),
                                            right: ConstNode(0.3),
                                          ),
                                        },
                                      ),
                                    },
                                  ),
                                  WidgetNode(
                                    name: 'SizedBox',
                                    args: {'height': ConstNode(20)},
                                  ),
                                  WidgetNode(
                                    name: 'Divider',
                                    args: {
                                      'color': WidgetNode(
                                        name: 'Color',
                                        args: {'arg0': ConstNode(654311423)},
                                      ),
                                      'height': ConstNode(1),
                                    },
                                  ),
                                  WidgetNode(
                                    name: 'SizedBox',
                                    args: {'height': ConstNode(20)},
                                  ),
                                  WidgetNode(
                                    name: 'Row',
                                    args: {
                                      'children': ListNode([
                                        WidgetNode(
                                          name: 'ClipRRect',
                                          args: {
                                            'borderRadius': EventNode(
                                              ['BorderRadius', 'circular'],
                                              args: {'arg0': LiteralNode(26)},
                                            ),
                                            'child': WidgetNode(
                                              name: 'SizedBox',
                                              args: {
                                                'width': ConstNode(52),
                                                'height': ConstNode(52),
                                                'child': WidgetNode(
                                                  name: 'Center',
                                                  args: {
                                                    'child': WidgetNode(
                                                      name: 'Icon',
                                                      args: {
                                                        'icon': RefNode([
                                                          'Icons',
                                                          'person',
                                                        ]),
                                                        'size': ConstNode(32),
                                                      },
                                                    ),
                                                  },
                                                ),
                                              },
                                            ),
                                          },
                                        ),
                                        WidgetNode(
                                          name: 'SizedBox',
                                          args: {'width': ConstNode(12)},
                                        ),
                                        WidgetNode(
                                          name: 'Expanded',
                                          args: {
                                            'child': WidgetNode(
                                              name: 'Column',
                                              args: {
                                                'crossAxisAlignment': RefNode([
                                                  'CrossAxisAlignment',
                                                  'start',
                                                ]),
                                                'children': ListNode([
                                                  WidgetNode(
                                                    name: 'Text',
                                                    args: {
                                                      'data': RefNode([
                                                        'data',
                                                        'chefName',
                                                      ]),
                                                      'style': WidgetNode(
                                                        name: 'TextStyle',
                                                        args: {
                                                          'fontSize': ConstNode(
                                                            15,
                                                          ),
                                                          'fontStyle': RefNode([
                                                            'FontStyle',
                                                            'italic',
                                                          ]),
                                                          'color': WidgetNode(
                                                            name: 'Color',
                                                            args: {
                                                              'arg0': ConstNode(
                                                                4293454056,
                                                              ),
                                                            },
                                                          ),
                                                        },
                                                      ),
                                                    },
                                                  ),
                                                  WidgetNode(
                                                    name: 'SizedBox',
                                                    args: {
                                                      'height': ConstNode(2),
                                                    },
                                                  ),
                                                  WidgetNode(
                                                    name: 'Text',
                                                    args: {
                                                      'data': RefNode([
                                                        'data',
                                                        'chefRoleUpper',
                                                      ]),
                                                      'style': WidgetNode(
                                                        name: 'TextStyle',
                                                        args: {
                                                          'fontSize': ConstNode(
                                                            11.5,
                                                          ),
                                                          'color': WidgetNode(
                                                            name: 'Color',
                                                            args: {
                                                              'arg0': ConstNode(
                                                                3003121663,
                                                              ),
                                                            },
                                                          ),
                                                          'letterSpacing':
                                                              ConstNode(1),
                                                          'fontWeight': RefNode(
                                                            [
                                                              'FontWeight',
                                                              'w600',
                                                            ],
                                                          ),
                                                        },
                                                      ),
                                                    },
                                                  ),
                                                ]),
                                              },
                                            ),
                                          },
                                        ),
                                        WidgetNode(
                                          name: 'Container',
                                          args: {
                                            'width': ConstNode(26),
                                            'height': ConstNode(26),
                                            'decoration': WidgetNode(
                                              name: 'BoxDecoration',
                                              args: {
                                                'shape': RefNode([
                                                  'BoxShape',
                                                  'circle',
                                                ]),
                                              },
                                            ),
                                            'child': WidgetNode(
                                              name: 'Icon',
                                              args: {
                                                'icon': RefNode([
                                                  'Icons',
                                                  'play_arrow',
                                                ]),
                                                'size': ConstNode(14),
                                                'color': WidgetNode(
                                                  name: 'Color',
                                                  args: {
                                                    'arg0': ConstNode(
                                                      4293454056,
                                                    ),
                                                  },
                                                ),
                                              },
                                            ),
                                          },
                                        ),
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
                    ForNode(
                      variable: 'dish',
                      source: RefNode(['data', 'dishes']),
                      body: WidgetNode(
                        name: 'Padding',
                        args: {
                          'padding': WidgetNode(
                            name: 'fromLTRB',
                            args: {
                              'arg0': ConstNode(24),
                              'arg1': ConstNode(0),
                              'arg2': ConstNode(24),
                              'arg3': ConstNode(26),
                            },
                          ),
                          'child': WidgetNode(
                            name: 'Row',
                            args: {
                              'crossAxisAlignment': RefNode([
                                'CrossAxisAlignment',
                                'start',
                              ]),
                              'children': ListNode([
                                WidgetNode(
                                  name: 'Stack',
                                  args: {
                                    'children': ListNode([
                                      WidgetNode(
                                        name: 'Container',
                                        args: {
                                          'width': ConstNode(118),
                                          'height': ConstNode(150),
                                          'color': IndexAccessNode(
                                            target: RefNode(['Colors', 'grey']),
                                            key: ConstNode(300),
                                          ),
                                        },
                                      ),
                                      WidgetNode(
                                        name: 'Positioned',
                                        args: {
                                          'bottom': ConstNode(8),
                                          'left': ConstNode(8),
                                          'child': WidgetNode(
                                            name: 'Container',
                                            args: {
                                              'padding': WidgetNode(
                                                name: 'symmetric',
                                                args: {
                                                  'horizontal': ConstNode(8),
                                                  'vertical': ConstNode(3),
                                                },
                                              ),
                                              'decoration': WidgetNode(
                                                name: 'BoxDecoration',
                                                args: {
                                                  'color': WidgetNode(
                                                    name: 'Color',
                                                    args: {
                                                      'arg0': ConstNode(
                                                        4076204272,
                                                      ),
                                                    },
                                                  ),
                                                  'borderRadius': EventNode(
                                                    [
                                                      'BorderRadius',
                                                      'circular',
                                                    ],
                                                    args: {
                                                      'arg0': LiteralNode(999),
                                                    },
                                                  ),
                                                },
                                              ),
                                              'child': WidgetNode(
                                                name: 'Text',
                                                args: {
                                                  'data': RefNode([
                                                    'dish',
                                                    'numberLabel',
                                                  ]),
                                                  'style': WidgetNode(
                                                    name: 'TextStyle',
                                                    args: {
                                                      'fontSize': ConstNode(
                                                        9.5,
                                                      ),
                                                      'fontWeight': RefNode([
                                                        'FontWeight',
                                                        'w700',
                                                      ]),
                                                      'letterSpacing':
                                                          ConstNode(1.5),
                                                    },
                                                  ),
                                                },
                                              ),
                                            },
                                          ),
                                        },
                                      ),
                                    ]),
                                  },
                                ),
                                WidgetNode(
                                  name: 'SizedBox',
                                  args: {'width': ConstNode(16)},
                                ),
                                WidgetNode(
                                  name: 'Expanded',
                                  args: {
                                    'child': WidgetNode(
                                      name: 'Padding',
                                      args: {
                                        'padding': WidgetNode(
                                          name: 'only',
                                          args: {'top': ConstNode(4)},
                                        ),
                                        'child': WidgetNode(
                                          name: 'Column',
                                          args: {
                                            'crossAxisAlignment': RefNode([
                                              'CrossAxisAlignment',
                                              'start',
                                            ]),
                                            'children': ListNode([
                                              WidgetNode(
                                                name: 'Row',
                                                args: {
                                                  'crossAxisAlignment':
                                                      RefNode([
                                                        'CrossAxisAlignment',
                                                        'baseline',
                                                      ]),
                                                  'textBaseline': RefNode([
                                                    'TextBaseline',
                                                    'alphabetic',
                                                  ]),
                                                  'children': ListNode([
                                                    WidgetNode(
                                                      name: 'Expanded',
                                                      args: {
                                                        'child': WidgetNode(
                                                          name: 'Text',
                                                          args: {
                                                            'data': RefNode([
                                                              'dish',
                                                              'name',
                                                            ]),
                                                            'style': WidgetNode(
                                                              name: 'TextStyle',
                                                              args: {
                                                                'fontSize':
                                                                    ConstNode(
                                                                      19,
                                                                    ),
                                                                'fontStyle':
                                                                    RefNode([
                                                                      'FontStyle',
                                                                      'italic',
                                                                    ]),
                                                                'letterSpacing':
                                                                    ArithOpNode(
                                                                      op: ArithOp
                                                                          .sub,
                                                                      left:
                                                                          ConstNode(
                                                                            0,
                                                                          ),
                                                                      right:
                                                                          ConstNode(
                                                                            0.2,
                                                                          ),
                                                                    ),
                                                                'height':
                                                                    ConstNode(
                                                                      1.1,
                                                                    ),
                                                              },
                                                            ),
                                                          },
                                                        ),
                                                      },
                                                    ),
                                                    WidgetNode(
                                                      name: 'SizedBox',
                                                      args: {
                                                        'width': ConstNode(8),
                                                      },
                                                    ),
                                                    WidgetNode(
                                                      name: 'Text',
                                                      args: {
                                                        'data': RefNode([
                                                          'dish',
                                                          'priceLabel',
                                                        ]),
                                                        'style': WidgetNode(
                                                          name: 'TextStyle',
                                                          args: {
                                                            'fontSize':
                                                                ConstNode(16),
                                                          },
                                                        ),
                                                      },
                                                    ),
                                                  ]),
                                                },
                                              ),
                                              ConditionalNode(
                                                condition: RefNode([
                                                  'dish',
                                                  'description',
                                                  'isNotEmpty',
                                                ]),
                                                thenBranch: SpreadNode(
                                                  ListNode([
                                                    WidgetNode(
                                                      name: 'SizedBox',
                                                      args: {
                                                        'height': ConstNode(8),
                                                      },
                                                    ),
                                                    WidgetNode(
                                                      name: 'Text',
                                                      args: {
                                                        'data': RefNode([
                                                          'dish',
                                                          'description',
                                                        ]),
                                                        'style': WidgetNode(
                                                          name: 'TextStyle',
                                                          args: {
                                                            'fontSize':
                                                                ConstNode(12.5),
                                                            'color': WidgetNode(
                                                              name: 'Color',
                                                              args: {
                                                                'arg0':
                                                                    ConstNode(
                                                                      4285229931,
                                                                    ),
                                                              },
                                                            ),
                                                            'height': ConstNode(
                                                              1.5,
                                                            ),
                                                          },
                                                        ),
                                                      },
                                                    ),
                                                  ]),
                                                ),
                                              ),
                                              WidgetNode(
                                                name: 'SizedBox',
                                                args: {'height': ConstNode(12)},
                                              ),
                                              WidgetNode(
                                                name: 'Wrap',
                                                args: {
                                                  'spacing': ConstNode(8),
                                                  'runSpacing': ConstNode(6),
                                                  'crossAxisAlignment':
                                                      RefNode([
                                                        'WrapCrossAlignment',
                                                        'center',
                                                      ]),
                                                  'children': ListNode([
                                                    WidgetNode(
                                                      name: 'Container',
                                                      args: {
                                                        'padding': WidgetNode(
                                                          name: 'symmetric',
                                                          args: {
                                                            'horizontal':
                                                                ConstNode(14),
                                                            'vertical':
                                                                ConstNode(8),
                                                          },
                                                        ),
                                                        'decoration': WidgetNode(
                                                          name: 'BoxDecoration',
                                                          args: {
                                                            'color': WidgetNode(
                                                              name: 'Color',
                                                              args: {
                                                                'arg0':
                                                                    ConstNode(
                                                                      4281794739,
                                                                    ),
                                                              },
                                                            ),
                                                            'borderRadius': EventNode(
                                                              [
                                                                'BorderRadius',
                                                                'circular',
                                                              ],
                                                              args: {
                                                                'arg0':
                                                                    LiteralNode(
                                                                      999,
                                                                    ),
                                                              },
                                                            ),
                                                          },
                                                        ),
                                                        'child': WidgetNode(
                                                          name: 'Text',
                                                          args: {
                                                            'data': ConstNode(
                                                              '+ Add to order',
                                                            ),
                                                            'style': WidgetNode(
                                                              name: 'TextStyle',
                                                              args: {
                                                                'color':
                                                                    RefNode([
                                                                      'Colors',
                                                                      'white',
                                                                    ]),
                                                                'fontSize':
                                                                    ConstNode(
                                                                      12,
                                                                    ),
                                                                'fontWeight':
                                                                    RefNode([
                                                                      'FontWeight',
                                                                      'w700',
                                                                    ]),
                                                                'letterSpacing':
                                                                    ConstNode(
                                                                      0.3,
                                                                    ),
                                                              },
                                                            ),
                                                          },
                                                        ),
                                                      },
                                                    ),
                                                    WidgetNode(
                                                      name: 'Text',
                                                      args: {
                                                        'data': ConstNode(
                                                          'single serving',
                                                        ),
                                                        'style': WidgetNode(
                                                          name: 'TextStyle',
                                                          args: {
                                                            'fontSize':
                                                                ConstNode(11),
                                                            'color': WidgetNode(
                                                              name: 'Color',
                                                              args: {
                                                                'arg0':
                                                                    ConstNode(
                                                                      4288585374,
                                                                    ),
                                                              },
                                                            ),
                                                            'letterSpacing':
                                                                ConstNode(0.4),
                                                          },
                                                        ),
                                                      },
                                                    ),
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
                              ]),
                            },
                          ),
                        },
                      ),
                    ),
                    WidgetNode(
                      name: 'Padding',
                      args: {
                        'padding': WidgetNode(
                          name: 'fromLTRB',
                          args: {
                            'arg0': ConstNode(24),
                            'arg1': ConstNode(34),
                            'arg2': ConstNode(24),
                            'arg3': ConstNode(0),
                          },
                        ),
                        'child': WidgetNode(
                          name: 'Text',
                          args: {
                            'data': StringInterpNode([
                              '— ',
                              RefNode(['data', 'refreshCadence']),
                              ' —',
                            ]),
                            'textAlign': RefNode(['TextAlign', 'center']),
                            'style': WidgetNode(
                              name: 'TextStyle',
                              args: {
                                'fontSize': ConstNode(14),
                                'fontStyle': RefNode(['FontStyle', 'italic']),
                                'color': WidgetNode(
                                  name: 'Color',
                                  args: {'arg0': ConstNode(4285229931)},
                                ),
                              },
                            ),
                          },
                        ),
                      },
                    ),
                  ]),
                },
              ),
            },
          ),
          WidgetNode(
            name: 'Positioned',
            args: {
              'top': ConstNode(0),
              'left': ConstNode(0),
              'right': ConstNode(0),
              'child': WidgetNode(
                name: 'Container',
                args: {
                  'padding': WidgetNode(
                    name: 'fromLTRB',
                    args: {
                      'arg0': ConstNode(20),
                      'arg1': ConstNode(56),
                      'arg2': ConstNode(20),
                      'arg3': ConstNode(14),
                    },
                  ),
                  'color': WidgetNode(
                    name: 'Color',
                    args: {'arg0': ConstNode(4210422000)},
                  ),
                  'child': WidgetNode(
                    name: 'Row',
                    args: {
                      'mainAxisAlignment': RefNode([
                        'MainAxisAlignment',
                        'spaceBetween',
                      ]),
                      'children': ListNode([
                        WidgetNode(
                          name: 'GestureDetector',
                          args: {
                            'onTap': RefNode(['controller', 'tapBack']),
                            'child': WidgetNode(
                              name: 'Icon',
                              args: {
                                'icon': RefNode([
                                  'Icons',
                                  'arrow_back_ios_new',
                                ]),
                                'size': ConstNode(20),
                              },
                            ),
                          },
                        ),
                        WidgetNode(
                          name: 'Text',
                          args: {
                            'data': ConstNode('CHEF\'S CHOICE'),
                            'style': WidgetNode(
                              name: 'TextStyle',
                              args: {
                                'fontSize': ConstNode(12),
                                'letterSpacing': ConstNode(2),
                                'fontWeight': RefNode(['FontWeight', 'w700']),
                              },
                            ),
                          },
                        ),
                        WidgetNode(
                          name: 'GestureDetector',
                          args: {
                            'onTap': RefNode(['controller', 'toggleBookmark']),
                            'child': WidgetNode(
                              name: 'Icon',
                              args: {
                                'icon': RefNode(['Icons', 'bookmark_border']),
                                'size': ConstNode(20),
                              },
                            ),
                          },
                        ),
                      ]),
                    },
                  ),
                },
              ),
            },
          ),
        ]),
      },
    ),
  ),
  inputs: [
    InputBinding(name: 'data', read: (v) => v as dynamic),
    InputBinding(name: 'controller', read: (v) => v as dynamic),
  ],
  methods: [
    MethodBinding(name: 'BorderRadius.circular', invoke: () {}),
    MethodBinding(name: 'BorderRadius.circular', invoke: () {}),
    MethodBinding(name: 'BorderRadius.circular', invoke: () {}),
  ],
  reactives: const [],
);

void registerChefDependencies(Runtime rt) {
  rt.registerWidget(
    'Stack',
    (args) => Stack(
      key: args['key'] as Key?,
      alignment:
          args['alignment'] as AlignmentGeometry? ??
          AlignmentDirectional.topStart,
      textDirection: args['textDirection'] as TextDirection?,
      fit: args['fit'] as StackFit? ?? StackFit.loose,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.hardEdge,
      children: (args['children'] as List?)?.cast<Widget>() ?? const [],
    ),
  );
  rt.registerWidget(
    'SingleChildScrollView',
    (args) => SingleChildScrollView(
      key: args['key'] as Key?,
      scrollDirection: args['scrollDirection'] as Axis? ?? Axis.vertical,
      reverse: args['reverse'] as bool? ?? false,
      padding: args['padding'] as EdgeInsetsGeometry?,
      primary: args['primary'] as bool?,
      physics: args['physics'] as ScrollPhysics?,
      controller: args['controller'] as ScrollController?,
      child: args['child'] as Widget?,
      dragStartBehavior:
          args['dragStartBehavior'] as DragStartBehavior? ??
          DragStartBehavior.start,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.hardEdge,
      hitTestBehavior:
          args['hitTestBehavior'] as HitTestBehavior? ?? HitTestBehavior.opaque,
      restorationId: args['restorationId'] as String?,
      keyboardDismissBehavior:
          args['keyboardDismissBehavior'] as ScrollViewKeyboardDismissBehavior?,
    ),
  );
  rt.registerWidget(
    'Column',
    (args) => Column(
      key: args['key'] as Key?,
      mainAxisAlignment:
          args['mainAxisAlignment'] as MainAxisAlignment? ??
          MainAxisAlignment.start,
      mainAxisSize: args['mainAxisSize'] as MainAxisSize? ?? MainAxisSize.max,
      crossAxisAlignment:
          args['crossAxisAlignment'] as CrossAxisAlignment? ??
          CrossAxisAlignment.center,
      textDirection: args['textDirection'] as TextDirection?,
      verticalDirection:
          args['verticalDirection'] as VerticalDirection? ??
          VerticalDirection.down,
      textBaseline: args['textBaseline'] as TextBaseline?,
      spacing: args['spacing'] as double? ?? 0.0,
      children: (args['children'] as List?)?.cast<Widget>() ?? const [],
    ),
  );
  rt.registerWidget(
    'Padding',
    (args) => Padding(
      key: args['key'] as Key?,
      padding: args['padding'] as EdgeInsetsGeometry,
      child: args['child'] as Widget?,
    ),
  );
  rt.registerWidget(
    'Text',
    (args) => Text(
      data: args['data'] as String,
      key: args['key'] as Key?,
      style: args['style'] as TextStyle?,
      strutStyle: args['strutStyle'] as StrutStyle?,
      textAlign: args['textAlign'] as TextAlign?,
      textDirection: args['textDirection'] as TextDirection?,
      locale: args['locale'] as Locale?,
      softWrap: args['softWrap'] as bool?,
      overflow: args['overflow'] as TextOverflow?,
      textScaleFactor: args['textScaleFactor'] as double?,
      textScaler: args['textScaler'] as TextScaler?,
      maxLines: args['maxLines'] as int?,
      semanticsLabel: args['semanticsLabel'] as String?,
      semanticsIdentifier: args['semanticsIdentifier'] as String?,
      textWidthBasis: args['textWidthBasis'] as TextWidthBasis?,
      textHeightBehavior: args['textHeightBehavior'] as TextHeightBehavior?,
      selectionColor: args['selectionColor'] as Color?,
    ),
  );
  rt.registerWidget(
    'SizedBox',
    (args) => SizedBox(
      key: args['key'] as Key?,
      width: args['width'] as double?,
      height: args['height'] as double?,
      child: args['child'] as Widget?,
    ),
  );
  rt.registerWidget(
    'Container',
    (args) => Container(
      key: args['key'] as Key?,
      alignment: args['alignment'] as AlignmentGeometry?,
      padding: args['padding'] as EdgeInsetsGeometry?,
      color: args['color'] as Color?,
      isAntiAlias: args['isAntiAlias'] as bool? ?? true,
      decoration: args['decoration'] as Decoration?,
      foregroundDecoration: args['foregroundDecoration'] as Decoration?,
      width: args['width'] as double?,
      height: args['height'] as double?,
      constraints: args['constraints'] as BoxConstraints?,
      margin: args['margin'] as EdgeInsetsGeometry?,
      transform: args['transform'] as Matrix4?,
      transformAlignment: args['transformAlignment'] as AlignmentGeometry?,
      child: args['child'] as Widget?,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.none,
    ),
  );
  rt.registerWidget(
    'Divider',
    (args) => Divider(
      key: args['key'] as Key?,
      height: args['height'] as double?,
      thickness: args['thickness'] as double?,
      indent: args['indent'] as double?,
      endIndent: args['endIndent'] as double?,
      color: args['color'] as Color?,
      radius: args['radius'] as BorderRadiusGeometry?,
    ),
  );
  rt.registerWidget(
    'Row',
    (args) => Row(
      key: args['key'] as Key?,
      mainAxisAlignment:
          args['mainAxisAlignment'] as MainAxisAlignment? ??
          MainAxisAlignment.start,
      mainAxisSize: args['mainAxisSize'] as MainAxisSize? ?? MainAxisSize.max,
      crossAxisAlignment:
          args['crossAxisAlignment'] as CrossAxisAlignment? ??
          CrossAxisAlignment.center,
      textDirection: args['textDirection'] as TextDirection?,
      verticalDirection:
          args['verticalDirection'] as VerticalDirection? ??
          VerticalDirection.down,
      textBaseline: args['textBaseline'] as TextBaseline?,
      spacing: args['spacing'] as double? ?? 0.0,
      children: (args['children'] as List?)?.cast<Widget>() ?? const [],
    ),
  );
  rt.registerWidget(
    'ClipRRect',
    (args) => ClipRRect(
      key: args['key'] as Key?,
      borderRadius:
          args['borderRadius'] as BorderRadiusGeometry? ?? BorderRadius.zero,
      clipper: args['clipper'] as CustomClipper<RRect>?,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.antiAlias,
      child: args['child'] as Widget?,
    ),
  );
  rt.registerWidget(
    'Center',
    (args) => Center(
      key: args['key'] as Key?,
      widthFactor: args['widthFactor'] as double?,
      heightFactor: args['heightFactor'] as double?,
      child: args['child'] as Widget?,
    ),
  );
  rt.registerWidget(
    'Icon',
    (args) => Icon(
      icon: args['icon'] as IconData?,
      key: args['key'] as Key?,
      size: args['size'] as double?,
      fill: args['fill'] as double?,
      weight: args['weight'] as double?,
      grade: args['grade'] as double?,
      opticalSize: args['opticalSize'] as double?,
      color: args['color'] as Color?,
      shadows: args['shadows'] as List<Shadow>?,
      semanticLabel: args['semanticLabel'] as String?,
      textDirection: args['textDirection'] as TextDirection?,
      applyTextScaling: args['applyTextScaling'] as bool?,
      blendMode: args['blendMode'] as BlendMode?,
      fontWeight: args['fontWeight'] as FontWeight?,
    ),
  );
  rt.registerWidget(
    'Expanded',
    (args) => Expanded(
      key: args['key'] as Key?,
      flex: args['flex'] as int? ?? 1,
      child: args['child'] as Widget,
    ),
  );
  rt.registerWidget(
    'Positioned',
    (args) => Positioned(
      key: args['key'] as Key?,
      left: args['left'] as double?,
      top: args['top'] as double?,
      right: args['right'] as double?,
      bottom: args['bottom'] as double?,
      width: args['width'] as double?,
      height: args['height'] as double?,
      child: args['child'] as Widget,
    ),
  );
  rt.registerWidget(
    'Wrap',
    (args) => Wrap(
      key: args['key'] as Key?,
      direction: args['direction'] as Axis? ?? Axis.horizontal,
      alignment: args['alignment'] as WrapAlignment? ?? WrapAlignment.start,
      spacing: args['spacing'] as double? ?? 0.0,
      runAlignment:
          args['runAlignment'] as WrapAlignment? ?? WrapAlignment.start,
      runSpacing: args['runSpacing'] as double? ?? 0.0,
      crossAxisAlignment:
          args['crossAxisAlignment'] as WrapCrossAlignment? ??
          WrapCrossAlignment.start,
      textDirection: args['textDirection'] as TextDirection?,
      verticalDirection:
          args['verticalDirection'] as VerticalDirection? ??
          VerticalDirection.down,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.none,
      children: (args['children'] as List?)?.cast<Widget>() ?? const [],
    ),
  );
  rt.registerWidget(
    'GestureDetector',
    (args) => GestureDetector(
      key: args['key'] as Key?,
      child: args['child'] as Widget?,
      onTapDown: args['onTapDown'] as void Function(TapDownDetails)?,
      onTapUp: args['onTapUp'] as void Function(TapUpDetails)?,
      onTap: args['onTap'] as void Function()?,
      onTapMove: args['onTapMove'] as void Function(TapMoveDetails)?,
      onTapCancel: args['onTapCancel'] as void Function()?,
      onSecondaryTap: args['onSecondaryTap'] as void Function()?,
      onSecondaryTapDown:
          args['onSecondaryTapDown'] as void Function(TapDownDetails)?,
      onSecondaryTapUp:
          args['onSecondaryTapUp'] as void Function(TapUpDetails)?,
      onSecondaryTapCancel: args['onSecondaryTapCancel'] as void Function()?,
      onTertiaryTapDown:
          args['onTertiaryTapDown'] as void Function(TapDownDetails)?,
      onTertiaryTapUp: args['onTertiaryTapUp'] as void Function(TapUpDetails)?,
      onTertiaryTapCancel: args['onTertiaryTapCancel'] as void Function()?,
      onDoubleTapDown:
          args['onDoubleTapDown'] as void Function(TapDownDetails)?,
      onDoubleTap: args['onDoubleTap'] as void Function()?,
      onDoubleTapCancel: args['onDoubleTapCancel'] as void Function()?,
      onLongPressDown:
          args['onLongPressDown'] as void Function(LongPressDownDetails)?,
      onLongPressCancel: args['onLongPressCancel'] as void Function()?,
      onLongPress: args['onLongPress'] as void Function()?,
      onLongPressStart:
          args['onLongPressStart'] as void Function(LongPressStartDetails)?,
      onLongPressMoveUpdate:
          args['onLongPressMoveUpdate']
              as void Function(LongPressMoveUpdateDetails)?,
      onLongPressUp: args['onLongPressUp'] as void Function()?,
      onLongPressEnd:
          args['onLongPressEnd'] as void Function(LongPressEndDetails)?,
      onSecondaryLongPressDown:
          args['onSecondaryLongPressDown']
              as void Function(LongPressDownDetails)?,
      onSecondaryLongPressCancel:
          args['onSecondaryLongPressCancel'] as void Function()?,
      onSecondaryLongPress: args['onSecondaryLongPress'] as void Function()?,
      onSecondaryLongPressStart:
          args['onSecondaryLongPressStart']
              as void Function(LongPressStartDetails)?,
      onSecondaryLongPressMoveUpdate:
          args['onSecondaryLongPressMoveUpdate']
              as void Function(LongPressMoveUpdateDetails)?,
      onSecondaryLongPressUp:
          args['onSecondaryLongPressUp'] as void Function()?,
      onSecondaryLongPressEnd:
          args['onSecondaryLongPressEnd']
              as void Function(LongPressEndDetails)?,
      onTertiaryLongPressDown:
          args['onTertiaryLongPressDown']
              as void Function(LongPressDownDetails)?,
      onTertiaryLongPressCancel:
          args['onTertiaryLongPressCancel'] as void Function()?,
      onTertiaryLongPress: args['onTertiaryLongPress'] as void Function()?,
      onTertiaryLongPressStart:
          args['onTertiaryLongPressStart']
              as void Function(LongPressStartDetails)?,
      onTertiaryLongPressMoveUpdate:
          args['onTertiaryLongPressMoveUpdate']
              as void Function(LongPressMoveUpdateDetails)?,
      onTertiaryLongPressUp: args['onTertiaryLongPressUp'] as void Function()?,
      onTertiaryLongPressEnd:
          args['onTertiaryLongPressEnd'] as void Function(LongPressEndDetails)?,
      onVerticalDragDown:
          args['onVerticalDragDown'] as void Function(DragDownDetails)?,
      onVerticalDragStart:
          args['onVerticalDragStart'] as void Function(DragStartDetails)?,
      onVerticalDragUpdate:
          args['onVerticalDragUpdate'] as void Function(DragUpdateDetails)?,
      onVerticalDragEnd:
          args['onVerticalDragEnd'] as void Function(DragEndDetails)?,
      onVerticalDragCancel: args['onVerticalDragCancel'] as void Function()?,
      onHorizontalDragDown:
          args['onHorizontalDragDown'] as void Function(DragDownDetails)?,
      onHorizontalDragStart:
          args['onHorizontalDragStart'] as void Function(DragStartDetails)?,
      onHorizontalDragUpdate:
          args['onHorizontalDragUpdate'] as void Function(DragUpdateDetails)?,
      onHorizontalDragEnd:
          args['onHorizontalDragEnd'] as void Function(DragEndDetails)?,
      onHorizontalDragCancel:
          args['onHorizontalDragCancel'] as void Function()?,
      onForcePressStart:
          args['onForcePressStart'] as void Function(ForcePressDetails)?,
      onForcePressPeak:
          args['onForcePressPeak'] as void Function(ForcePressDetails)?,
      onForcePressUpdate:
          args['onForcePressUpdate'] as void Function(ForcePressDetails)?,
      onForcePressEnd:
          args['onForcePressEnd'] as void Function(ForcePressDetails)?,
      onPanDown: args['onPanDown'] as void Function(DragDownDetails)?,
      onPanStart: args['onPanStart'] as void Function(DragStartDetails)?,
      onPanUpdate: args['onPanUpdate'] as void Function(DragUpdateDetails)?,
      onPanEnd: args['onPanEnd'] as void Function(DragEndDetails)?,
      onPanCancel: args['onPanCancel'] as void Function()?,
      onScaleStart: args['onScaleStart'] as void Function(ScaleStartDetails)?,
      onScaleUpdate:
          args['onScaleUpdate'] as void Function(ScaleUpdateDetails)?,
      onScaleEnd: args['onScaleEnd'] as void Function(ScaleEndDetails)?,
      behavior: args['behavior'] as HitTestBehavior?,
      excludeFromSemantics: args['excludeFromSemantics'] as bool? ?? false,
      dragStartBehavior:
          args['dragStartBehavior'] as DragStartBehavior? ??
          DragStartBehavior.start,
      trackpadScrollCausesScale:
          args['trackpadScrollCausesScale'] as bool? ?? false,
      trackpadScrollToScaleFactor:
          args['trackpadScrollToScaleFactor'] as Offset? ??
          kDefaultTrackpadScrollToScaleFactor,
      supportedDevices: args['supportedDevices'] as Set<PointerDeviceKind>?,
    ),
  );
  rt.registerValueBuilder(
    'EdgeInsets.fromLTRB',
    (args) => EdgeInsets.fromLTRB(
      args[0] as double,
      args[1] as double,
      args[2] as double,
      args[3] as double,
    ),
  );
  rt.registerValueBuilder(
    'EdgeInsets.all',
    (args) => EdgeInsets.all(args[0] as double),
  );
  rt.registerValueBuilder(
    'EdgeInsets.only',
    (args) => EdgeInsets.only(
      left: args['left'] as double? ?? 0.0,
      top: args['top'] as double? ?? 0.0,
      right: args['right'] as double? ?? 0.0,
      bottom: args['bottom'] as double? ?? 0.0,
    ),
  );
  rt.registerValueBuilder(
    'EdgeInsets.symmetric',
    (args) => EdgeInsets.symmetric(
      vertical: args['vertical'] as double? ?? 0.0,
      horizontal: args['horizontal'] as double? ?? 0.0,
    ),
  );
  rt.registerValueBuilder(
    'EdgeInsets.fromViewPadding',
    (args) =>
        EdgeInsets.fromViewPadding(args[0] as ViewPadding, args[1] as double),
  );
  rt.registerValueBuilder(
    'EdgeInsets.fromWindowPadding',
    (args) =>
        EdgeInsets.fromWindowPadding(args[0] as ViewPadding, args[1] as double),
  );
  rt.registerValueBuilder(
    'TextStyle',
    (args) => TextStyle(
      inherit: args['inherit'] as bool? ?? true,
      color: args['color'] as Color?,
      backgroundColor: args['backgroundColor'] as Color?,
      fontSize: args['fontSize'] as double?,
      fontWeight: args['fontWeight'] as FontWeight?,
      fontStyle: args['fontStyle'] as FontStyle?,
      letterSpacing: args['letterSpacing'] as double?,
      wordSpacing: args['wordSpacing'] as double?,
      textBaseline: args['textBaseline'] as TextBaseline?,
      height: args['height'] as double?,
      leadingDistribution:
          args['leadingDistribution'] as TextLeadingDistribution?,
      locale: args['locale'] as Locale?,
      foreground: args['foreground'] as Paint?,
      background: args['background'] as Paint?,
      shadows: args['shadows'] as List<Shadow>?,
      fontFeatures: args['fontFeatures'] as List<FontFeature>?,
      fontVariations: args['fontVariations'] as List<FontVariation>?,
      decoration: args['decoration'] as TextDecoration?,
      decorationColor: args['decorationColor'] as Color?,
      decorationStyle: args['decorationStyle'] as TextDecorationStyle?,
      decorationThickness: args['decorationThickness'] as double?,
      debugLabel: args['debugLabel'] as String?,
      fontFamily: args['fontFamily'] as String?,
      fontFamilyFallback: args['fontFamilyFallback'] as List<String>?,
      package: args['package'] as String?,
      overflow: args['overflow'] as TextOverflow?,
    ),
  );
  rt.registerValueBuilder('Color', (args) => Color(args[0] as int));
  rt.registerValueBuilder(
    'Color.from',
    (args) => Color.from(
      alpha: args['alpha'] as double,
      red: args['red'] as double,
      green: args['green'] as double,
      blue: args['blue'] as double,
      colorSpace: args['colorSpace'] as ColorSpace? ?? ColorSpace.sRGB,
    ),
  );
  rt.registerValueBuilder(
    'Color.fromARGB',
    (args) => Color.fromARGB(
      args[0] as int,
      args[1] as int,
      args[2] as int,
      args[3] as int,
    ),
  );
  rt.registerValueBuilder(
    'Color.fromRGBO',
    (args) => Color.fromRGBO(
      args[0] as int,
      args[1] as int,
      args[2] as int,
      args[3] as double,
    ),
  );
  rt.registerValueBuilder(
    'BorderRadius.all',
    (args) => BorderRadius.all(args[0] as Radius),
  );
  rt.registerValueBuilder(
    'BorderRadius.circular',
    (args) => BorderRadius.circular(args[0] as double),
  );
  rt.registerValueBuilder(
    'BorderRadius.vertical',
    (args) => BorderRadius.vertical(
      top: args['top'] as Radius? ?? Radius.zero,
      bottom: args['bottom'] as Radius? ?? Radius.zero,
    ),
  );
  rt.registerValueBuilder(
    'BorderRadius.horizontal',
    (args) => BorderRadius.horizontal(
      left: args['left'] as Radius? ?? Radius.zero,
      right: args['right'] as Radius? ?? Radius.zero,
    ),
  );
  rt.registerValueBuilder(
    'BorderRadius.only',
    (args) => BorderRadius.only(
      topLeft: args['topLeft'] as Radius? ?? Radius.zero,
      topRight: args['topRight'] as Radius? ?? Radius.zero,
      bottomLeft: args['bottomLeft'] as Radius? ?? Radius.zero,
      bottomRight: args['bottomRight'] as Radius? ?? Radius.zero,
    ),
  );
  rt.registerValueBuilder(
    'BoxDecoration',
    (args) => BoxDecoration(
      color: args['color'] as Color?,
      image: args['image'] as DecorationImage?,
      border: args['border'] as BoxBorder?,
      borderRadius: args['borderRadius'] as BorderRadiusGeometry?,
      boxShadow: args['boxShadow'] as List<BoxShadow>?,
      gradient: args['gradient'] as Gradient?,
      backgroundBlendMode: args['backgroundBlendMode'] as BlendMode?,
      shape: args['shape'] as BoxShape? ?? BoxShape.rectangle,
    ),
  );
  rt.registerConstant('CrossAxisAlignment.stretch', CrossAxisAlignment.stretch);
  rt.registerConstant('CrossAxisAlignment.start', CrossAxisAlignment.start);
  rt.registerConstant('FontStyle.italic', FontStyle.italic);
  rt.registerConstant('FontWeight.w500', FontWeight.w500);
  rt.registerConstant('Icons.person', Icons.person);
  rt.registerConstant('FontWeight.w600', FontWeight.w600);
  rt.registerConstant('BoxShape.circle', BoxShape.circle);
  rt.registerConstant('Icons.play_arrow', Icons.play_arrow);
  rt.registerConstant('Colors.grey', Colors.grey);
  rt.registerConstant('FontWeight.w700', FontWeight.w700);
  rt.registerConstant(
    'CrossAxisAlignment.baseline',
    CrossAxisAlignment.baseline,
  );
  rt.registerConstant('TextBaseline.alphabetic', TextBaseline.alphabetic);
  rt.registerConstant('WrapCrossAlignment.center', WrapCrossAlignment.center);
  rt.registerConstant('Colors.white', Colors.white);
  rt.registerConstant('TextAlign.center', TextAlign.center);
  rt.registerConstant(
    'MainAxisAlignment.spaceBetween',
    MainAxisAlignment.spaceBetween,
  );
  rt.registerConstant('Icons.arrow_back_ios_new', Icons.arrow_back_ios_new);
  rt.registerConstant('Icons.bookmark_border', Icons.bookmark_border);
  rt.registerSubscript(
    'MaterialColor.[]',
    (recv, key) => (recv as MaterialColor)[key as int],
  );
}
