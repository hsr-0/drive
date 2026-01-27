import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/dimensions.dart';
import '../../../core/utils/my_color.dart';
import '../../../core/utils/style.dart';

class LabelTextInstruction extends StatelessWidget {
  final bool isRequired;
  final String text;
  final String? instructions;
  final TextAlign? textAlign;
  final TextStyle? textStyle;

  const LabelTextInstruction({
    super.key,
    required this.text,
    this.textAlign,
    this.textStyle,
    this.isRequired = false,
    this.instructions,
  });

  @override
  Widget build(BuildContext context) {
    final GlobalKey<TooltipState> tooltipKey = GlobalKey<TooltipState>();

    return isRequired
        ? Row(
            children: [
              Text(
                text.tr,
                textAlign: textAlign,
                style: textStyle ?? regularDefault.copyWith(color: MyColor.getTextColor()),
              ),
              const SizedBox(width: 2),
              if (instructions != null) ...[
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 2,
                    end: Dimensions.space10,
                  ),
                  child: Tooltip(
                    key: tooltipKey,
                    message: "$instructions",
                    child: GestureDetector(
                      onTap: () {
                        tooltipKey.currentState?.ensureTooltipVisible();
                      },
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: Dimensions.space15,
                        color: MyColor.primaryColor.withValues(alpha: .5),
                      ),
                    ),
                  ),
                ),
              ],
              Text(
                '*',
                style: semiBoldDefault.copyWith(color: MyColor.colorRed),
              ),
            ],
          )
        : Row(
            children: [
              Text(
                text.tr,
                textAlign: textAlign,
                style: textStyle ?? regularDefault.copyWith(color: MyColor.getTextColor()),
              ),
              if (instructions != null) ...[
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 2,
                    end: Dimensions.space10,
                  ),
                  child: Tooltip(
                    key: tooltipKey,
                    message: "$instructions",
                    child: GestureDetector(
                      onTap: () {
                        tooltipKey.currentState?.ensureTooltipVisible();
                      },
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: Dimensions.space15,
                        color: MyColor.getLabelTextColor().withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
  }
}
