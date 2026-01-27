import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/controller/payment_history/payment_history_controller.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_divider.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';
import 'package:ovoride_driver/presentation/screens/payment_history/widget/payment_status_widget.dart';

import '../../../../core/utils/dimensions.dart';
import '../../../../core/utils/my_color.dart';
import '../../../../core/utils/my_strings.dart';
import '../../../components/column_widget/card_column.dart';

class CustomPaymentCard extends StatelessWidget {
  final String rideUid;
  final String dateData;
  final String amountData;
  final String paymentType;
  final int index;

  const CustomPaymentCard({
    super.key,
    required this.index,
    required this.rideUid,
    required this.dateData,
    required this.amountData,
    required this.paymentType,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PaymentHistoryController>(
      builder: (controller) => CustomAppCard(
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
                      MyUtils.copy(text: rideUid);
                    },
                    child: HeaderText(
                      text: "#$rideUid",
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
                    body: StringConverter.formatNumber(amountData),
                    headerTextStyle: regularDefault.copyWith(
                      color: MyColor.getBodyTextColor(),
                    ),
                    bodyTextStyle: boldLarge.copyWith(
                      color: MyColor.getHeadingTextColor(),
                      fontSize: Dimensions.fontTitleLarge,
                    ),
                  ),
                ),
                PaymentStatusWidget(
                  status: paymentType == "1" ? MyStrings.onlinePayment.tr : MyStrings.cashPayment.tr,
                  color: paymentType == "1" ? MyColor.informationColor : MyColor.greenSuccessColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
