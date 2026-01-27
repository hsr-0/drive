import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_divider.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';
import 'package:ovoride_driver/presentation/screens/withdraw/widget/status_widget.dart';

import '../../../../core/utils/dimensions.dart';
import '../../../../core/utils/my_color.dart';
import '../../../../core/utils/my_strings.dart';
import '../../../components/column_widget/card_column.dart';

class CustomWithdrawCard extends StatelessWidget {
  final String trxValue, date, status, amount;
  final Color statusBgColor;
  final VoidCallback onPressed;

  const CustomWithdrawCard({
    super.key,
    required this.trxValue,
    required this.date,
    required this.status,
    required this.statusBgColor,
    required this.amount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.space20,
          horizontal: Dimensions.space15,
        ),
        decoration: BoxDecoration(
          color: MyColor.colorWhite,
          borderRadius: BorderRadius.circular(Dimensions.defaultRadius),
          boxShadow: MyUtils.getCardShadow(),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      MyUtils.copy(text: trxValue);
                    },
                    child: HeaderText(
                      text: "#$trxValue",
                      style: boldLarge.copyWith(
                        color: MyColor.getBodyTextColor(),
                      ),
                    ),
                  ),
                ),
                spaceSide(Dimensions.space10),
                Expanded(
                  child: HeaderText(
                    text: date,
                    textAlign: TextAlign.end,
                    style: regularDefault.copyWith(
                      color: MyColor.getBodyTextColor(),
                    ),
                  ),
                ),
              ],
            ),
            const CustomDivider(space: Dimensions.space15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CardColumn(header: MyStrings.amount, body: amount),
                StatusWidget(status: status, color: statusBgColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
