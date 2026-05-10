import 'package:flutter/material.dart';

class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.color,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: color ?? Colors.grey[300],
      child: Center(
        child: Icon(Icons.image, color: Colors.grey[600], size: (width ?? height ?? 40) * 0.4),
      ),
    );
  }
}
