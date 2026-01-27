import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_divider.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';
import '../../../../core/utils/dimensions.dart';
import '../../../../core/utils/my_color.dart';
import '../../../../core/utils/my_strings.dart';
import '../../../../core/utils/util.dart';
import '../../../components/column_widget/card_column.dart';
import '../../withdraw/widget/status_widget.dart';

class CustomDepositsCard extends StatelessWidget {
  final String trxValue, date, status, amount;
  final Color statusBgColor;
  final VoidCallback onPressed;

  const CustomDepositsCard({
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
      child: CustomAppCard(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                CardColumn(
                  header: MyStrings.amount,
                  body: amount,
                  headerTextStyle: regularDefault.copyWith(
                    color: MyColor.getBodyTextColor(),
                  ),
                  bodyTextStyle: boldExtraLarge.copyWith(
                    color: MyColor.getHeadingTextColor(),
                    fontSize: Dimensions.fontTitleLarge,
                  ),
                ),
                StatusWidget(status: status, color: statusBgColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
