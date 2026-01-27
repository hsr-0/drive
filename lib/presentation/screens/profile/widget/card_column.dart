import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/presentation/components/card/inner_shadow_container.dart';

import '../../../../core/utils/dimensions.dart';
import '../../../../core/utils/my_color.dart';
import '../../../../core/utils/style.dart';

class ProfileCardColumn extends StatelessWidget {
  final String header;
  final String body;
  final bool alignmentEnd;
  final Color? textColor;
  final String? subBody;
  final TextStyle? headerTextDecoration;
  final TextStyle? bodyTextDecoration;
  final TextStyle? subBodyTextDecoration;
  final double? space = 3;
  final Widget? endWidget;

  const ProfileCardColumn({
    super.key,
    this.alignmentEnd = false,
    required this.header,
    this.textColor,
    this.headerTextDecoration,
    this.bodyTextDecoration,
    required this.body,
    this.subBody,
    this.subBodyTextDecoration,
    this.endWidget,
  });

  @override
  Widget build(BuildContext context) {
    return InnerShadowContainer(
      width: double.infinity,
      backgroundColor: MyColor.textFieldBgColor,
      borderRadius: Dimensions.largeRadius,
      blur: 6,
      offset: Offset(3, 3),
      shadowColor: MyColor.colorBlack.withValues(alpha: 0.04),
      isShadowTopLeft: true,
      isShadowBottomRight: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.space12,
          vertical: Dimensions.space12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: alignmentEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    header.tr,
                    style: headerTextDecoration ??
                        regularDefault.copyWith(
                          color: MyColor.getTextColor().withValues(alpha: 0.6),
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: space),
                  Text(
                    body.tr,
                    style: bodyTextDecoration ??
                        boldDefault.copyWith(
                          fontSize: Dimensions.fontExtraLarge - 1,
                          color: textColor ?? MyColor.getTextColor(),
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (endWidget != null) ...[endWidget!],
          ],
        ),
      ),
    );
  }
}
