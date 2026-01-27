import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/style.dart';

class BottomSheetLabelText extends StatelessWidget {
  final String text;
  final TextAlign? textAlign;

  const BottomSheetLabelText({super.key, required this.text, this.textAlign});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.tr,
      textAlign: textAlign,
      style: regularSmall.copyWith(
        color: MyColor.contentTextColor,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
