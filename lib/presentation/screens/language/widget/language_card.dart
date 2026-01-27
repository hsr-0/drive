import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/presentation/components/text/small_text.dart';
import '../../../components/image/my_network_image_widget.dart';

class LanguageCard extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final bool isShowTopRight;
  final String langName;
  final String flag;

  const LanguageCard({
    super.key,
    required this.index,
    required this.selectedIndex,
    this.isShowTopRight = false,
    required this.langName,
    required this.flag,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Dimensions.space8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                height: 55,
                width: 55,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MyColor.getScreenBgColor(),
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(Dimensions.space4),
                child: flag.isNotEmpty
                    ? MyImageWidget(height: 60, width: 100, imageUrl: flag)
                    : Icon(
                        Icons.g_translate,
                        color: MyColor.primaryColor,
                        size: 22.5,
                      ),
              ),
              const SizedBox(width: Dimensions.space10),
              SmallText(
                text: langName.tr,
                textStyle: semiBoldSmall.copyWith(
                  color: MyColor.getTextColor(),
                ),
              ),
            ],
          ),
          Container(
            height: 20,
            width: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: index == selectedIndex ? MyColor.getPrimaryColor() : MyColor.colorWhite,
              shape: BoxShape.circle,
              border: index != selectedIndex ? Border.all(color: MyColor.primaryColor) : null,
            ),
            child: index == selectedIndex ? Icon(Icons.check, color: MyColor.colorWhite, size: 14) : null,
          ),
        ],
      ),
    );
  }
}
