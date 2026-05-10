import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';
import '../data/chef_data.dart';
import '../controllers/chef_controller.dart';

part 'chef.sdui.g.dart';

@Screen('chef')
Widget buildChef(ChefData data, ChefController controller) => Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(top: 102, bottom: 130),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.headline,
                      style: const TextStyle(
                        fontSize: 40,
                        height: 1.02,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data.bio,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF6B6B6B),
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                color: const Color(0xFF2D5F2D),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cooking is about patience, passion, and the pursuit of flavor that lingers in memory.',
                        style: TextStyle(
                          fontSize: 22,
                          height: 1.28,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFFE8E8E8),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(
                        color: Color(0x26FFFFFF),
                        height: 1,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: SizedBox(
                              width: 52,
                              height: 52,
                              child: const Center(
                                child: Icon(Icons.person, size: 32),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.chefName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFFE8E8E8),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  data.chefRoleUpper,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xB2FFFFFF),
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              size: 14,
                              color: Color(0xFFE8E8E8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              for (final dish in data.dishes) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 118,
                            height: 150,
                            color: Colors.grey[300],
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xF2F5F0F0),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                dish.numberLabel,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Expanded(
                                    child: Text(
                                      dish.name,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontStyle: FontStyle.italic,
                                        letterSpacing: -0.2,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    dish.priceLabel,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                              if (dish.description.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  dish.description,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF6B6B6B),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3700B3),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      '+ Add to order',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'single serving',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9E9E9E),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 34, 24, 0),
                child: Text(
                  '\u2014 ${data.refreshCadence} \u2014',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 14),
            color: const Color(0xFAF5F0F0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: controller.tapBack,
                  child: const Icon(Icons.arrow_back_ios_new, size: 20),
                ),
                const Text(
                  "CHEF'S CHOICE",
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: controller.toggleBookmark,
                  child: const Icon(Icons.bookmark_border, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
