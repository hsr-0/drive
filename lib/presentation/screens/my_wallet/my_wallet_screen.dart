import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/data/controller/transaction/transactions_controller.dart';
import 'package:ovoride_driver/data/repo/transaction/transaction_repo.dart';
import 'package:ovoride_driver/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/custom_loader/custom_loader.dart';
import 'package:ovoride_driver/presentation/components/no_data.dart';
import 'package:ovoride_driver/presentation/components/shimmer/transaction_card_shimmer.dart';

import '../../../core/utils/dimensions.dart';
import '../../../core/utils/my_color.dart';
import '../../../core/utils/my_strings.dart';
import '../../../core/utils/style.dart';
import '../../components/divider/custom_spacer.dart';
import '../../components/text/header_text.dart';
import 'widgets/recent_transaction_card.dart';

class MyWalletScreen extends StatefulWidget {
  const MyWalletScreen({super.key});

  @override
  State<MyWalletScreen> createState() => _MyWalletScreenState();
}

class _MyWalletScreenState extends State<MyWalletScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColor.screenBgColor,
      appBar: CustomAppBar(title: MyStrings.myWallet.tr),
      body: GetBuilder<TransactionsController>(
        builder: (controller) {
          return RefreshIndicator(
            onRefresh: () async {
              if (controller.isLoading == false) {
                controller.loadTransaction(p: 1);
              }
            },
            child: SingleChildScrollView(
              padding: Dimensions.screenPaddingHV,
              controller: scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  CustomAppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HeaderText(
                                text: MyStrings.totalBalance,
                                style: regularLarge.copyWith(
                                  color: MyColor.getBodyTextColor(),
                                ),
                              ),
                              spaceDown(Dimensions.space8),
                              HeaderText(
                                text: controller.isLoading ? '${controller.currencySym}0.0' : '${controller.currencySym}${StringConverter.formatNumber(controller.driver.balance ?? '0')}',
                                style: boldExtraLarge.copyWith(
                                  color: MyColor.colorBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: RoundedButton(
                            text: MyStrings.withdrawalTitle,
                            press: () {
                              Get.toNamed(RouteHelper.newWithdrawScreen);
                            },
                            bgColor: MyColor.getPrimaryColor().withValues(
                              alpha: 0.1,
                            ),
                            textColor: MyColor.getPrimaryColor(),
                            textStyle: regularDefault.copyWith(
                              color: MyColor.getPrimaryColor(),
                              fontSize: Dimensions.fontLarge,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  spaceDown(Dimensions.space10),
                  CustomAppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        HeaderText(
                          text: MyStrings.recentTransactions.tr,
                          style: mediumOverLarge.copyWith(
                            fontSize: Dimensions.fontOverLarge,
                            fontWeight: FontWeight.w500,
                            color: MyColor.colorBlack,
                          ),
                        ),
                        spaceDown(Dimensions.space15),
                        if (controller.isLoading) ...[
                          Column(
                            children: List.generate(10, (index) {
                              return const TransactionCardShimmer();
                            }),
                          ),
                        ] else if (controller.isLoading == false && controller.transactionList.isEmpty) ...[
                          NoDataWidget(),
                        ] else ...[
                          ListView.builder(
                            itemCount: controller.transactionList.length + 1,
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              if (controller.transactionList.length == index) {
                                return controller.hasNext()
                                    ? Container(
                                        height: 40,
                                        width: MediaQuery.of(
                                          context,
                                        ).size.width,
                                        margin: const EdgeInsets.all(5),
                                        child: const CustomLoader(),
                                      )
                                    : const SizedBox();
                              }
                              return RecentTransactionCard(
                                index: index,
                                press: () {},
                                currency: controller.currencySym,
                                transaction: controller.transactionList[index],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
