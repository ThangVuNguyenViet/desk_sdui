import 'package:flutter/material.dart';

void demoShowSuccess(BuildContext context, String title) {
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
      ),
      title: const Text(
        'Confirmed',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Text(
        'Added $title to your cart!',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Awesome', style: TextStyle(color: Color(0xFF00FFCC))),
        ),
      ],
    ),
  );
}

void demoShowSnackBar(BuildContext context, String title) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Added $title to cart'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF2A2A35),
    ),
  );
}
