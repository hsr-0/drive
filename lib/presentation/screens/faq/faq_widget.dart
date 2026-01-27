import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/presentation/components/text/default_text.dart';

import '../../../core/utils/dimensions.dart';
import '../../../core/utils/my_color.dart';
import '../../../core/utils/style.dart';
import '../../components/animated_widget/expanded_widget.dart';

class FaqListItem extends StatelessWidget {
  final String question;
  final String answer;
  final int index;
  final int selectedIndex;
  final VoidCallback press;

  const FaqListItem({
    super.key,
    required this.answer,
    required this.question,
    required this.index,
    required this.press,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.space15,
        vertical: Dimensions.space15,
      ),
      decoration: BoxDecoration(
        color: MyColor.getCardBgColor(),
        borderRadius: BorderRadius.circular(Dimensions.largeRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: press,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.7,
                  child: DefaultText(
                    text: question.tr,
                    textStyle: semiBoldDefault,
                    textColor: MyColor.getTextColor(),
                  ),
                ),
              ),
              Center(
                child: IconButton(
                  onPressed: press,
                  icon: Icon(
                    index == selectedIndex ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: MyColor.getPrimaryColor(),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          ExpandedSection(
            expand: index == selectedIndex,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Dimensions.space10),
                DefaultText(
                  text: answer.tr,
                  textStyle: regularSmall.copyWith(
                    color: MyColor.getBodyTextColor(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
