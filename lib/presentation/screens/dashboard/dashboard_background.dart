import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';

class DashboardBackground extends StatelessWidget {
  final Widget child;
  const DashboardBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MyColor.secondaryScreenBgColor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              height: 400,
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MyColor.getPrimaryColor().withValues(alpha: 0.2),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 100.0,
                  sigmaY: 100.0,
                  tileMode: TileMode.repeated,
                ),
                child: Container(
                  height: 400,
                  width: MediaQuery.of(context).size.width,
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
