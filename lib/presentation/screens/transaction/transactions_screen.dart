import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/debouncer.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/controller/transaction/transactions_controller.dart';
import 'package:ovoride_driver/data/repo/transaction/transaction_repo.dart';
import 'package:ovoride_driver/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/custom_loader/custom_loader.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/my_local_image_widget.dart';
import 'package:ovoride_driver/presentation/components/shimmer/transaction_card_shimmer.dart';
import 'package:ovoride_driver/presentation/components/text-form-field/custom_text_field.dart';
import 'package:ovoride_driver/presentation/screens/transaction/widget/bottom_sheet.dart';
import 'package:ovoride_driver/presentation/screens/transaction/widget/custom_transaction_card.dart';
import 'package:ovoride_driver/presentation/screens/transaction/widget/filter_row_widget.dart';

import '../../../core/helper/date_converter.dart';
import '../../components/no_data.dart';
import '../../components/text/label_text.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final ScrollController scrollController = ScrollController();

  void fetchData() {
    Get.find<TransactionsController>().loadTransaction();
  }

  void scrollListener() {
    if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
      if (Get.find<TransactionsController>().hasNext()) {
        fetchData();
      }
    }
  }

  @override
  void initState() {
    Get.put(TransactionRepo(apiClient: Get.find()));
    final controller = Get.put(
      TransactionsController(transactionRepo: Get.find()),
    );

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controller.initialSelectedValue();
      scrollController.addListener(scrollListener);
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  final MyDebouncer _debouncer = MyDebouncer(
    delay: const Duration(milliseconds: 600),
  );
  @override
  Widget build(BuildContext context) {
    return GetBuilder<TransactionsController>(
      builder: (controller) => Scaffold(
        backgroundColor: MyColor.getScreenBgColor(),
        appBar: CustomAppBar(
          title: MyStrings.transaction,
          actionsWidget: [
            CustomAppCard(
              width: Dimensions.space40,
              height: Dimensions.space40,
              padding: EdgeInsets.all(Dimensions.space6),
              radius: Dimensions.largeRadius,
              onPressed: () {
                controller.changeSearchIcon();
              },
              child: MyLocalImageWidget(
                imagePath: MyIcons.filterIcon,
                width: Dimensions.space35,
                height: Dimensions.space35,
                imageOverlayColor: MyColor.getPrimaryColor(),
                boxFit: BoxFit.contain,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildFilterWidget(controller, context),
              Expanded(
                child: controller.isLoading || controller.filterLoading
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
                    : controller.transactionList.isEmpty && controller.filterLoading == false
                        ? const Center(
                            child: NoDataWidget(
                              text: MyStrings.noTrxFound,
                              margin: 6,
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            scrollDirection: Axis.vertical,
                            itemCount: controller.transactionList.length + 1,
                            separatorBuilder: (context, index) => const SizedBox(height: Dimensions.space10),
                            itemBuilder: (context, index) {
                              if (controller.transactionList.length == index) {
                                return controller.hasNext()
                                    ? Container(
                                        height: 40,
                                        width: MediaQuery.of(context).size.width,
                                        margin: const EdgeInsets.all(5),
                                        child: const CustomLoader(),
                                      )
                                    : const SizedBox();
                              }
                              return GestureDetector(
                                onTap: () {
                                  controller.changeExpandIndex(index);
                                },
                                child: CustomTransactionCard(
                                  index: index,
                                  expandIndex: controller.expandIndex,
                                  trxType: controller.transactionList[index].trxType ?? '',
                                  detailsText: controller.transactionList[index].details ?? "",
                                  trxData: controller.transactionList[index].trx ?? "",
                                  dateData: DateConverter.estimatedDate(
                                    DateTime.tryParse(
                                          controller.transactionList[index].createdAt ?? "",
                                        ) ??
                                        DateTime.now(),
                                    formatType: DateFormatType.dateTime12hr,
                                  ),
                                  amountData: "${controller.transactionList[index].trxType} ${controller.currencySym}${StringConverter.formatNumber(controller.transactionList[index].amount.toString())}",
                                  postBalanceData: "${StringConverter.formatNumber(controller.transactionList[index].postBalance.toString())} ${controller.currency}",
                                ),
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

  Widget buildFilterWidget(
    TransactionsController controller,
    BuildContext context,
  ) {
    return Visibility(
      visible: controller.isSearch,
      child: CustomAppCard(
        margin: const EdgeInsets.only(bottom: Dimensions.cardMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LabelText(text: MyStrings.type),
                      const SizedBox(height: Dimensions.space10),
                      FilterRowWidget(
                        fromTrx: true,
                        bgColor: Colors.transparent,
                        text: controller.selectedTrxType.isEmpty ? MyStrings.trxType : controller.selectedTrxType,
                        press: () {
                          showTrxBottomSheet(
                            controller.transactionTypeList.map((e) => e.toString()).toList(),
                            1,
                            MyStrings.selectTrxType,
                            context: context,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Dimensions.space15),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LabelText(text: MyStrings.remark),
                      const SizedBox(height: Dimensions.space10),
                      FilterRowWidget(
                        fromTrx: true,
                        bgColor: Colors.transparent,
                        text: StringConverter.replaceUnderscoreWithSpace(
                          controller.selectedRemark.isEmpty ? MyStrings.any : controller.selectedRemark,
                        ),
                        press: () {
                          showTrxBottomSheet(
                            controller.remarksList.map((e) => e.remark.toString()).toList(),
                            2,
                            MyStrings.selectRemarks,
                            context: context,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            spaceDown(Dimensions.space16),
            CustomTextField(
              controller: controller.trxController,
              onChanged: (value) {
                _debouncer.run(() {
                  controller.filterData();
                });
              },
              hintText: MyStrings.searchByTrxId.tr,
              isShowSuffixIcon: true,
              suffixWidget: Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: Dimensions.space10,
                ),
                child: InkWell(
                  onTap: () {
                    controller.filterData();
                  },
                  child: MyLocalImageWidget(
                    imagePath: MyIcons.searchIcon,
                    width: Dimensions.space35,
                    height: Dimensions.space35,
                    imageOverlayColor: MyColor.getPrimaryColor(),
                    boxFit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
