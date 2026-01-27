import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/my_local_image_widget.dart';
import 'package:ovoride_driver/presentation/components/no_data.dart';
import 'package:ovoride_driver/presentation/components/shimmer/transaction_card_shimmer.dart';
import 'package:ovoride_driver/presentation/screens/deposits/widget/custom_deposits_card.dart';
import 'package:ovoride_driver/presentation/screens/deposits/widget/deposit_bottom_sheet.dart';
import 'package:ovoride_driver/presentation/screens/deposits/widget/deposit_history_top.dart';
import 'package:get/get.dart';

import '../../../core/helper/date_converter.dart';
import '../../../core/route/route.dart';
import '../../../core/utils/dimensions.dart';
import '../../../core/utils/my_color.dart';
import '../../../core/utils/my_strings.dart';
import '../../../data/controller/deposit/deposit_history_controller.dart';
import '../../../data/repo/deposit/deposit_repo.dart';
import '../../components/custom_loader/custom_loader.dart';

class DepositsScreen extends StatefulWidget {
  const DepositsScreen({super.key});

  @override
  State<DepositsScreen> createState() => _DepositsScreenState();
}

class _DepositsScreenState extends State<DepositsScreen> {
  final ScrollController scrollController = ScrollController();

  void fetchData() {
    Get.find<DepositController>().fetchNewList();
  }

  void _scrollListener() {
    if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
      if (Get.find<DepositController>().hasNext()) {
        fetchData();
      }
    }
  }

  @override
  void initState() {
    Get.put(DepositRepo(apiClient: Get.find()));
    final controller = Get.put(DepositController(depositRepo: Get.find()));
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controller.beforeInitLoadData();
      scrollController.addListener(_scrollListener);
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DepositController>(
      builder: (controller) => Scaffold(
        backgroundColor: MyColor.getScreenBgColor(),
        appBar: CustomAppBar(
          title: MyStrings.deposit.tr,
          actionsWidget: [
            CustomAppCard(
              width: Dimensions.space40,
              height: Dimensions.space40,
              padding: EdgeInsets.all(Dimensions.space6),
              radius: Dimensions.largeRadius,
              onPressed: () {
                controller.changeIsPress();
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
            CustomAppCard(
              width: Dimensions.space40,
              height: Dimensions.space40,
              padding: EdgeInsets.all(0),
              radius: Dimensions.largeRadius,
              onPressed: () {
                Get.toNamed(RouteHelper.newDepositScreenScreen);
              },
              child: Center(
                child: Icon(
                  Icons.add,
                  color: MyColor.getPrimaryColor(),
                  size: Dimensions.space30,
                ),
              ),
            ),
            spaceSide(Dimensions.space10),
          ],
        ),
        body: Padding(
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
                    DepositHistoryTop(),
                    SizedBox(height: Dimensions.space15),
                  ],
                ),
              ),
              Expanded(
                child: controller.searchLoading || controller.isLoading
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
                    : controller.depositList.isEmpty && controller.searchLoading == false
                        ? const Center(
                            child: NoDataWidget(
                              text: MyStrings.noDepositFound,
                              margin: 6,
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            controller: scrollController,
                            scrollDirection: Axis.vertical,
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: controller.depositList.length + 1,
                            separatorBuilder: (context, index) => const SizedBox(height: Dimensions.space10),
                            itemBuilder: (context, index) {
                              if (controller.depositList.length == index) {
                                return controller.hasNext()
                                    ? SizedBox(
                                        height: 40,
                                        width: MediaQuery.of(context).size.width,
                                        child: const Center(child: CustomLoader()),
                                      )
                                    : const SizedBox();
                              }
                              return CustomDepositsCard(
                                onPressed: () {
                                  DepositBottomSheet.depositBottomSheet(
                                    context,
                                    index,
                                  );
                                },
                                trxValue: controller.depositList[index].trx ?? "",
                                date: DateConverter.estimatedDate(
                                  DateTime.tryParse(
                                        controller.depositList[index].createdAt ?? "",
                                      ) ??
                                      DateTime.now(),
                                  formatType: DateFormatType.onlyDate,
                                ),
                                status: controller.getStatus(index),
                                statusBgColor: controller.getStatusColor(index),
                                amount: "${StringConverter.formatNumber(controller.depositList[index].amount ?? " ")} ${controller.currency}",
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
