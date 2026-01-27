import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/helper/date_converter.dart';
import 'package:ovoride_driver/data/model/transctions/transaction_response_model.dart';

import '../../../../core/helper/string_format_helper.dart';
import '../../../../core/utils/dimensions.dart';
import '../../../../core/utils/my_color.dart';
import '../../../../core/utils/style.dart';
import '../../../components/column_widget/card_column.dart';

class RecentTransactionCard extends StatelessWidget {
  final int index;
  TransactionData transaction;
  String currency;
  final VoidCallback press;

  RecentTransactionCard({
    super.key,
    required this.index,
    required this.press,
    required this.transaction,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.space15,
          horizontal: Dimensions.space10,
        ),
        decoration: BoxDecoration(color: MyColor.getCardBgColor()),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    height: 35,
                    width: 35,
                    alignment: Alignment.center,
                    child: Container(
                      height: 35,
                      width: 35,
                      decoration: BoxDecoration(
                        color: transaction.trxType == "-" ? MyColor.colorRed.withValues(alpha: 0.2) : MyColor.colorGreen.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        transaction.trxType == "-" ? Icons.arrow_upward : Icons.arrow_downward,
                        color: transaction.trxType == "-" ? MyColor.colorRed : MyColor.colorGreen,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: Dimensions.space10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (transaction.remark?.replaceAll('_', ' ') ?? '').toTitleCase(),
                          style: boldDefault.copyWith(
                            color: MyColor.getTextColor(),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: Dimensions.space8),
                        SizedBox(
                          width: 150,
                          child: Text(
                            "#${transaction.trx}",
                            style: regularSmall.copyWith(
                              color: MyColor.getTextColor().withValues(
                                alpha: 0.5,
                              ),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: CardColumn(
                header: "$currency${StringConverter.formatNumber("${transaction.amount}".toString())}",
                body: DateConverter.estimatedDate(
                  DateTime.tryParse(transaction.createdAt ?? "") ?? DateTime.now(),
                ),
                bodyTextStyle: regularSmall.copyWith(
                  color: MyColor.getBodyTextColor(),
                  fontSize: Dimensions.fontExtraSmall,
                ),
                alignmentEnd: true,
                headerTextStyle: boldDefault.copyWith(
                  color: transaction.trxType == "-" ? MyColor.colorRed3 : MyColor.colorGreen,
                  fontSize: Dimensions.fontLarge + 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
