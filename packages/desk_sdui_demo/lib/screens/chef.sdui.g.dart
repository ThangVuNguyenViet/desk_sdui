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
                name: 'EdgeInsets.only',
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
                          name: 'EdgeInsets.fromLTRB',
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
                          name: 'EdgeInsets.fromLTRB',
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
                              name: 'EdgeInsets.fromLTRB',
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
                                            'borderRadius': WidgetNode(
                                              name: 'BorderRadius.circular',
                                              args: {'arg0': ConstNode(26)},
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
                            name: 'EdgeInsets.fromLTRB',
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
                                                name: 'EdgeInsets.symmetric',
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
                                                  'borderRadius': WidgetNode(
                                                    name:
                                                        'BorderRadius.circular',
                                                    args: {
                                                      'arg0': ConstNode(999),
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
                                          name: 'EdgeInsets.only',
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
                                                          name:
                                                              'EdgeInsets.symmetric',
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
                                                            'borderRadius':
                                                                WidgetNode(
                                                                  name:
                                                                      'BorderRadius.circular',
                                                                  args: {
                                                                    'arg0':
                                                                        ConstNode(
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
                          name: 'EdgeInsets.fromLTRB',
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
                    name: 'EdgeInsets.fromLTRB',
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
  methods: const [],
  reactives: const [],
);
