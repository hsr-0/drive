import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';

class CustomAppCard extends StatelessWidget {
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double radius;
  final VoidCallback? onPressed;
  final Widget child;
  final BoxBorder? boxBorder;
  final bool showBorder;

  const CustomAppCard({
    super.key,
    this.width,
    this.height,
    this.backgroundColor = MyColor.colorWhite,
    this.borderColor = MyColor.transparentColor,
    this.borderWidth = 0,
    this.radius = Dimensions.moreRadius,
    this.onPressed,
    required this.child,
    this.padding,
    this.margin,
    this.boxBorder,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: width,
        height: height,
        padding: padding ?? EdgeInsets.all(16),
        margin: margin,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(radius),
          border: showBorder ? boxBorder ?? Border.all(color: borderColor, width: borderWidth) : null,
        ),
        child: child,
      ),
    );
  }
}
