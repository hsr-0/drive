import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/controller/withdraw/withdraw_history_controller.dart';
import 'package:ovoride_driver/data/repo/withdraw/withdraw_history_repo.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/my_local_image_widget.dart';
import 'package:ovoride_driver/presentation/components/shimmer/transaction_card_shimmer.dart';

import '../../../../core/helper/date_converter.dart';
import '../../../../core/utils/dimensions.dart';
import '../../../../core/utils/my_color.dart';
import '../../../../core/utils/my_strings.dart';
import '../../../components/custom_loader/custom_loader.dart';
import '../../../components/no_data.dart';
import '../widget/custom_withdraw_card.dart';
import '../widget/withdraw_bottom_sheet.dart';
import '../widget/withdraw_history_filter.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final ScrollController scrollController = ScrollController();

  void scrollListener() {
    if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
      if (Get.find<WithdrawHistoryController>().hasNext()) {
        Get.find<WithdrawHistoryController>().loadPaginationData();
      }
    }
  }

  @override
  void initState() {
    Get.put(WithdrawHistoryRepo(apiClient: Get.find()));
    final controller = Get.put(
      WithdrawHistoryController(withdrawHistoryRepo: Get.find()),
    );
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controller.initData();
      scrollController.addListener(scrollListener);
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<WithdrawHistoryController>(
      builder: (controller) => Scaffold(
        backgroundColor: MyColor.getScreenBgColor(),
        appBar: CustomAppBar(
          title: MyStrings.withdraw.tr,
          actionsWidget: [
            CustomAppCard(
              width: Dimensions.space40,
              height: Dimensions.space40,
              padding: EdgeInsets.all(Dimensions.space6),
              radius: Dimensions.largeRadius,
              onPressed: () {
                controller.changeSearchStatus();
              },
              child: MyLocalImageWidget(
                imagePath: MyIcons.searchIcon,
                width: Dimensions.space35,
                height: Dimensions.space35,
                imageOverlayColor: MyColor.getPrimaryColor(),
                boxFit: BoxFit.contain,
              ),
            ),
            spaceSide(Dimensions.space10),
          ],
        ),
        body: controller.isLoading
            ? const CustomLoader()
            : Padding(
                padding: const EdgeInsets.only(
                  top: Dimensions.space20,
                  left: Dimensions.space16,
                  right: Dimensions.space16,
                ),
                child: Column(
                  children: [
                    Visibility(
                      visible: controller.isSearch,
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WithdrawHistoryFilter(),
                          SizedBox(height: Dimensions.space10),
                        ],
                      ),
                    ),
                    Expanded(
                      child: controller.filterLoading || controller.isLoading
                          ? ListView.separated(
                              itemCount: 20,
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
                          : controller.withdrawList.isEmpty && controller.filterLoading == false
                              ? const Center(
                                  child: NoDataWidget(
                                    text: MyStrings.noWithdrawFound,
                                    margin: 6,
                                  ),
                                )
                              : SizedBox(
                                  height: MediaQuery.of(context).size.height,
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    scrollDirection: Axis.vertical,
                                    physics: const BouncingScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    itemCount: controller.withdrawList.length + 1,
                                    controller: scrollController,
                                    separatorBuilder: (context, index) => const SizedBox(height: Dimensions.space10),
                                    itemBuilder: (context, index) {
                                      if (index == controller.withdrawList.length) {
                                        return controller.hasNext() ? const CustomLoader(isPagination: true) : const SizedBox();
                                      }
                                      return CustomWithdrawCard(
                                        onPressed: () {
                                          WithdrawBottomSheet().withdrawBottomSheet(
                                            index,
                                            context,
                                            controller.currency,
                                            controller,
                                          );
                                        },
                                        trxValue: controller.withdrawList[index].trx ?? "",
                                        date: DateConverter.estimatedDate(
                                          DateTime.tryParse(
                                                controller.withdrawList[index].createdAt ?? "",
                                              ) ??
                                              DateTime.now(),
                                          formatType: DateFormatType.onlyDate,
                                        ),
                                        status: controller.getStatus(index),
                                        statusBgColor: controller.getColor(index),
                                        amount: "${StringConverter.formatNumber(controller.withdrawList[index].amount ?? " ")} ${controller.currency}",
                                      );
                                    },
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
