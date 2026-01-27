import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';

class AppBodyWidgetCard extends StatefulWidget {
  final VoidCallback? onPressed;
  EdgeInsetsGeometry? padding;
  EdgeInsetsGeometry? margin;
  final Widget? child;
  final double? width;
  final BoxDecoration? decoration;
  AppBodyWidgetCard({
    super.key,
    this.onPressed,
    required this.child,
    this.margin,
    this.padding,
    this.width,
    this.decoration,
  });

  @override
  State<AppBodyWidgetCard> createState() => _AppBodyWidgetCardState();
}

class _AppBodyWidgetCardState extends State<AppBodyWidgetCard> {
  @override
  Widget build(BuildContext context) {
    return widget.onPressed != null
        ? GestureDetector(
            onTap: widget.onPressed,
            child: Container(
              width: double.infinity,
              margin: widget.margin,
              padding: widget.padding ??
                  EdgeInsets.symmetric(
                    horizontal: Dimensions.space15 + 1,
                    vertical: Dimensions.space25 - 1,
                  ),
              decoration: BoxDecoration(
                color: MyColor.colorWhite,
                borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
              ),
              child: widget.child,
            ),
          )
        : Container(
            width: double.infinity,
            margin: widget.margin,
            padding: widget.padding ??
                EdgeInsets.symmetric(
                  horizontal: Dimensions.space15 + 1,
                  vertical: Dimensions.space25 - 1,
                ),
            decoration: BoxDecoration(
              color: MyColor.colorWhite,
              borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
            ),
            child: widget.child,
          );
  }
}
