import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/dimensions.dart';
import '../../../core/utils/my_color.dart';

class BidDialogUserCard extends StatelessWidget {
  String? username, fullName, subtitle;
  String? image;
  bool isAsset;
  bool noAvatar;
  TextStyle? titleStyle, subtitleStyle;
  Widget? rightWidget;
  Widget? imgWidget;
  double? imgHeight;
  double? imgWidth;
  BidDialogUserCard({
    super.key,
    this.username,
    this.fullName,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
    this.isAsset = true,
    this.noAvatar = false,
    this.rightWidget,
    this.imgHeight,
    this.imgWidth,
    this.imgWidget,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (imgWidget != null) ...[imgWidget!],
                const SizedBox(width: Dimensions.space15),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          "$fullName".toCapitalized(),
                          style: titleStyle ??
                              boldDefault.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: Dimensions.fontLarge + 3,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: Dimensions.space3),
                      Text(
                        "@$username",
                        style: titleStyle ??
                            regularDefault.copyWith(
                              fontSize: Dimensions.fontSmall,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Dimensions.space5),
                      Text(
                        subtitle ?? "",
                        style: subtitleStyle ??
                            regularDefault.copyWith(
                              fontSize: Dimensions.fontSmall,
                              color: MyColor.getBodyTextColor().withValues(
                                alpha: 0.8,
                              ),
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          rightWidget ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}
