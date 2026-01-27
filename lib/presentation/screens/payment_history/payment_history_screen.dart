import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/controller/payment_history/payment_history_controller.dart';
import 'package:ovoride_driver/data/repo/payment_history/payment_history_repo.dart';
import 'package:ovoride_driver/data/services/api_client.dart';
import 'package:ovoride_driver/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovoride_driver/presentation/screens/payment_history/widget/custom_payment_card.dart';

import '../../../core/helper/date_converter.dart';
import '../../../core/utils/dimensions.dart';
import '../../components/custom_loader/custom_loader.dart';
import '../../components/no_data.dart';
import '../../components/shimmer/transaction_card_shimmer.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final ScrollController scrollController = ScrollController();

  void scrollListener() {
    if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
      if (Get.find<PaymentHistoryController>().hasNext()) {
        Get.find<PaymentHistoryController>().loadPaymentHistory();
      }
    }
  }

  @override
  void initState() {
    Get.put(PaymentHistoryRepo(apiClient: Get.find()));
    final controller = Get.put(
      PaymentHistoryController(paymentHistoryRepo: Get.find()),
    );

    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((time) {
      controller.loadPaymentHistory();
      scrollController.addListener(scrollListener);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PaymentHistoryController>(
      builder: (controller) => Scaffold(
        appBar: CustomAppBar(title: MyStrings.paymentHistory.tr),
        body: controller.isLoading
            ? ListView.separated(
                itemCount: 20,
                padding: EdgeInsets.symmetric(
                  horizontal: Dimensions.space16,
                  vertical: Dimensions.space20,
                ),
                separatorBuilder: (context, index) => const SizedBox(height: Dimensions.space10),
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: MyColor.getCardBgColor(),
                      boxShadow: MyUtils.getCardShadow(),
                      borderRadius: BorderRadius.circular(
                        Dimensions.moreRadius,
                      ),
                    ),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.space16,
                      vertical: Dimensions.space16,
                    ),
                    child: TransactionCardShimmer(),
                  );
                },
              )
            : controller.paymentHistoryList.isEmpty && controller.isLoading == false
                ? const Center(
                    child: NoDataWidget(text: MyStrings.noDataToShow, margin: 6),
                  )
                : ListView.separated(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(
                      horizontal: Dimensions.space16,
                      vertical: Dimensions.space20,
                    ),
                    scrollDirection: Axis.vertical,
                    itemCount: controller.paymentHistoryList.length + 1,
                    separatorBuilder: (context, index) => const SizedBox(height: Dimensions.space10),
                    itemBuilder: (context, index) {
                      if (controller.paymentHistoryList.length == index) {
                        return controller.hasNext()
                            ? Container(
                                height: 40,
                                width: MediaQuery.of(context).size.width,
                                margin: const EdgeInsets.all(5),
                                child: const CustomLoader(),
                              )
                            : const SizedBox();
                      }
                      return CustomPaymentCard(
                        index: index,
                        rideUid: "${controller.paymentHistoryList[index].ride?.uid}",
                        dateData: DateConverter.estimatedDate(
                          DateTime.tryParse(
                                controller.paymentHistoryList[index].createdAt ?? "",
                              ) ??
                              DateTime.now(),
                          formatType: DateFormatType.onlyDate,
                        ),
                        amountData: " ${Get.find<ApiClient>().getCurrency(isSymbol: true)}${controller.paymentHistoryList[index].amount}",
                        paymentType: controller.paymentHistoryList[index].paymentType ?? "-1",
                      );
                    },
                  ),
      ),
    );
  }
}
