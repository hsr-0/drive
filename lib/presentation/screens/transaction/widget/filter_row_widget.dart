import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/presentation/components/card/inner_shadow_container.dart';
import '../../../../core/utils/my_color.dart';
import '../../../../core/utils/style.dart';

class FilterRowWidget extends StatefulWidget {
  final String text;
  final bool fromTrx;
  final Color iconColor;
  final Callback press;
  final bool isFilterBtn;
  final Color bgColor;

  const FilterRowWidget({
    super.key,
    this.bgColor = MyColor.containerBgColor,
    this.isFilterBtn = false,
    this.iconColor = MyColor.primaryColor,
    required this.text,
    required this.press,
    this.fromTrx = false,
  });

  @override
  State<FilterRowWidget> createState() => _FilterRowWidgetState();
}

class _FilterRowWidgetState extends State<FilterRowWidget> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.press,
      child: InnerShadowContainer(
        width: double.infinity,
        backgroundColor: MyColor.neutral50,
        borderRadius: Dimensions.largeRadius,
        blur: 6,
        offset: Offset(3, 3),
        shadowColor: MyColor.colorBlack.withValues(alpha: 0.04),
        isShadowTopLeft: true,
        isShadowBottomRight: true,
        padding: EdgeInsetsGeometry.symmetric(
          vertical: Dimensions.space16,
          horizontal: Dimensions.space16,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            widget.fromTrx
                ? Expanded(
                    child: Text(
                      widget.text.tr,
                      style: regularDefault.copyWith(
                        overflow: TextOverflow.ellipsis,
                        color: widget.isFilterBtn ? MyColor.colorBlack : MyColor.colorBlack,
                      ),
                    ),
                  )
                : Expanded(
                    child: Text(
                      widget.text.tr,
                      style: regularDefault.copyWith(
                        color: MyColor.colorBlack,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
            const SizedBox(width: 20),
            Icon(Icons.expand_more, color: widget.iconColor, size: 17),
          ],
        ),
      ),
    );
  }
}
