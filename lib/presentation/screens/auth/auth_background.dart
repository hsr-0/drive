import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/utils/my_images.dart';

import '../../../core/utils/my_color.dart';

class AuthBackgroundWidget extends StatelessWidget {
  final List<Color>? colors;
  final Widget child;

  const AuthBackgroundWidget({super.key, this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.loose,
      children: [
        Positioned.fill(
          child: Image.asset(
            MyImages.backgroundImage,
            height: double.infinity,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            height: double.infinity,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: colors ??
                    [
                      MyColor.primaryColor.withValues(alpha: 0.95),
                      MyColor.primaryColor.withValues(alpha: 0.85),
                      MyColor.primaryColor.withValues(alpha: 0.80),
                    ],
              ),
            ),
          ),
        ),
        SafeArea(child: child),
      ],
    );
  }
}
