import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_divider.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';

import '../../../../core/utils/dimensions.dart';
import '../../../../core/utils/my_color.dart';
import '../../../../core/utils/my_strings.dart';
import '../../../../data/controller/transaction/transactions_controller.dart';
import '../../../components/animated_widget/expanded_widget.dart';
import '../../../components/column_widget/card_column.dart';

class CustomTransactionCard extends StatelessWidget {
  final String trxData;
  final String dateData;
  final String amountData;
  final String detailsText;
  final String postBalanceData;
  final int index;
  final int expandIndex;
  final String trxType;

  const CustomTransactionCard({
    super.key,
    required this.index,
    required this.trxData,
    required this.dateData,
    required this.amountData,
    required this.postBalanceData,
    required this.expandIndex,
    required this.detailsText,
    required this.trxType,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<TransactionsController>(
      builder: (controller) => CustomAppCard(
        width: MediaQuery.of(context).size.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      MyUtils.copy(text: trxData);
                    },
                    child: HeaderText(
                      text: "#$trxData",
                      style: boldLarge.copyWith(
                        color: MyColor.getBodyTextColor(),
                      ),
                    ),
                  ),
                ),
                spaceSide(Dimensions.space10),
                Expanded(
                  child: HeaderText(
                    text: dateData,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: CardColumn(
                    header: MyStrings.amount,
                    body: amountData,
                    headerTextStyle: regularDefault.copyWith(
                      color: MyColor.getBodyTextColor(),
                    ),
                    textColor: controller.changeTextColor(trxType),
                  ),
                ),
                Expanded(
                  child: CardColumn(
                    alignmentEnd: true,
                    header: MyStrings.postBalance,
                    body: postBalanceData,
                    headerTextStyle: regularDefault.copyWith(
                      color: MyColor.getBodyTextColor(),
                    ),
                    bodyTextStyle: boldExtraLarge.copyWith(
                      color: MyColor.getHeadingTextColor(),
                      fontSize: Dimensions.fontTitleLarge,
                    ),
                  ),
                ),
              ],
            ),
            ExpandedSection(
              expand: expandIndex == index,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CustomDivider(space: Dimensions.space15),
                  CardColumn(header: MyStrings.details, body: detailsText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
