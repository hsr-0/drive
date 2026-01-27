import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/date_converter.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/ticket_helper.dart';
import 'package:ovoride_driver/data/controller/support/support_controller.dart';
import 'package:ovoride_driver/data/repo/support/support_repo.dart';
import 'package:ovoride_driver/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/column_widget/card_column.dart';
import 'package:ovoride_driver/presentation/components/custom_loader/custom_loader.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/no_data.dart';
import 'package:ovoride_driver/presentation/components/shimmer/ticket_card_shimmer.dart';

class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({super.key});

  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  ScrollController scrollController = ScrollController();

  void scrollListener() {
    if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
      if (Get.find<SupportController>().hasNext()) {
        Get.find<SupportController>().getSupportTicket();
      }
    }
  }

  @override
  void initState() {
    Get.put(SupportRepo(apiClient: Get.find()));
    final controller = Get.put(SupportController(repo: Get.find()));
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controller.loadData();
      scrollController.addListener(scrollListener);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SupportController>(
      builder: (controller) {
        return Scaffold(
          backgroundColor: MyColor.getScreenBgColor(),
          appBar: CustomAppBar(
            title: MyStrings.supportTicket,
            isTitleCenter: true,
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              controller.loadData();
            },
            color: MyColor.primaryColor,
            child: Padding(
              padding: const EdgeInsets.only(
                top: Dimensions.space20,
                left: Dimensions.space16,
                right: Dimensions.space16,
              ),
              child: Column(
                children: [
                  controller.isLoading
                      ? Expanded(
                          child: ListView.separated(
                            itemCount: 10,
                            shrinkWrap: true,
                            separatorBuilder: (context, index) => const SizedBox(height: Dimensions.space10),
                            itemBuilder: (BuildContext context, int index) {
                              return const TicketCardShimmer();
                            },
                          ),
                        )
                      : (controller.ticketList.isEmpty && controller.isLoading == false)
                          ? Expanded(
                              child: NoDataWidget(
                                text: MyStrings.noSupportTicket.tr,
                              ),
                            )
                          : Expanded(
                              child: ListView.separated(
                                controller: scrollController,
                                itemCount: controller.ticketList.length + 1,
                                shrinkWrap: true,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                separatorBuilder: (context, index) => const SizedBox(height: Dimensions.space10),
                                itemBuilder: (context, index) {
                                  if (controller.ticketList.length == index) {
                                    return controller.hasNext() ? const CustomLoader(isPagination: true) : const SizedBox();
                                  }
                                  var ticket = controller.ticketList[index];
                                  return CustomAppCard(
                                    onPressed: () {
                                      String id = ticket.ticket ?? '-1';
                                      String subject = ticket.subject ?? '';
                                      Get.toNamed(
                                        RouteHelper.supportTicketDetailsScreen,
                                        arguments: [id, subject],
                                      )?.then((v) {
                                        controller.loadData(shouldLoad: false);
                                      });
                                    },
                                    child: Column(
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Padding(
                                                padding: const EdgeInsetsDirectional.only(
                                                  end: Dimensions.space10,
                                                ),
                                                child: Column(
                                                  children: [
                                                    CardColumn(
                                                      header: "[${MyStrings.ticket.tr} #${ticket.ticket}]",
                                                      body: ticket.subject ?? "",
                                                      space: 5,
                                                      headerTextStyle: regularDefault.copyWith(
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                      bodyTextStyle: regularDefault.copyWith(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            CustomAppCard(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: Dimensions.space10,
                                                vertical: Dimensions.space2,
                                              ),
                                              radius: Dimensions.largeRadius,
                                              backgroundColor: TicketHelper.getStatusColor(
                                                ticket.status ?? "0",
                                              ).withValues(alpha: 0.2),
                                              borderColor: TicketHelper.getStatusColor(
                                                ticket.status ?? "0",
                                              ),
                                              child: Text(
                                                TicketHelper.getPriorityText(
                                                  ticket.status ?? '0',
                                                ),
                                                style: regularDefault.copyWith(
                                                  color: TicketHelper.getStatusColor(
                                                    ticket.status ?? "0",
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        spaceDown(Dimensions.space10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            CustomAppCard(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: Dimensions.space10,
                                                vertical: Dimensions.space2,
                                              ),
                                              radius: Dimensions.mediumRadius,
                                              backgroundColor: TicketHelper.getPriorityColor(
                                                ticket.priority ?? "0",
                                              ).withValues(alpha: 0.2),
                                              borderColor: TicketHelper.getPriorityColor(
                                                ticket.priority ?? "0",
                                              ),
                                              child: Text(
                                                TicketHelper.getPriorityText(
                                                  ticket.priority ?? '0',
                                                ),
                                                style: regularDefault.copyWith(
                                                  color: TicketHelper.getPriorityColor(
                                                    ticket.priority ?? "0",
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              DateConverter.getTimeAgo(
                                                ticket.createdAt ?? '',
                                              ),
                                              style: regularDefault.copyWith(
                                                fontSize: 10,
                                                color: MyColor.getGreyText(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Get.toNamed(
                RouteHelper.createSupportTicketScreen,
              )?.then((value) => {controller.loadData()});
            },
            backgroundColor: MyColor.colorWhite,
            icon: Icon(Icons.add, color: MyColor.getPrimaryColor()),
            label: Text(
              MyStrings.create.tr,
              style: boldLarge.copyWith(color: MyColor.getPrimaryColor()),
            ), // The text labe
          ),
        );
      },
    );
  }
}
