import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/controller/support/ticket_details_controller.dart';
import 'package:ovoride_driver/data/repo/support/support_repo.dart';
import 'package:ovoride_driver/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/card/inner_shadow_container.dart';
import 'package:ovoride_driver/presentation/components/custom_loader/custom_loader.dart';
import 'package:ovoride_driver/presentation/components/dialog/app_dialog.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/no_data.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';
import 'package:ovoride_driver/presentation/components/text-form-field/custom_text_field.dart';
import 'package:ovoride_driver/presentation/components/text/label_text.dart';
import 'package:ovoride_driver/presentation/screens/support_ticket/ticket_details/widget/attachment_preview.dart';
import 'package:ovoride_driver/presentation/screens/support_ticket/ticket_details/widget/ticket_meassge_widget.dart';

import 'package:zoom_tap_animation/zoom_tap_animation.dart';

class TicketDetailsScreen extends StatefulWidget {
  const TicketDetailsScreen({super.key});

  @override
  State<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  String title = "";
  String ticketId = "-1";
  @override
  void initState() {
    ticketId = Get.arguments[0];
    title = Get.arguments[1];

    Get.put(SupportRepo(apiClient: Get.find()));
    var controller = Get.put(
      TicketDetailsController(repo: Get.find(), ticketId: ticketId),
    );

    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controller.loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<TicketDetailsController>(
      builder: (controller) {
        return Scaffold(
          appBar: CustomAppBar(
            title: title,
            actionsWidget: [
              if (controller.model.data?.myTickets?.status != '3') ...[
                CustomAppCard(
                  width: Dimensions.space40,
                  height: Dimensions.space40,
                  padding: EdgeInsets.all(0),
                  radius: Dimensions.largeRadius,
                  onPressed: () {
                    AppDialog().warningAlertDialog(
                      context,
                      msgText: MyStrings.closeTicketWarningTxt.tr,
                      () {
                        controller.closeTicket(
                          controller.model.data?.myTickets?.id.toString() ?? '-1',
                        );
                        Get.back();
                      },
                    );
                  },
                  child: Center(
                    child: controller.closeLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: MyColor.redCancelTextColor,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.close,
                            color: MyColor.redCancelTextColor,
                            size: Dimensions.space30,
                          ),
                  ),
                ),
                spaceSide(Dimensions.space10),
              ],
            ],
          ),
          body: controller.isLoading
              ? const CustomLoader(isFullScreen: true)
              : SingleChildScrollView(
                  padding: Dimensions.screenPaddingHV,
                  child: Container(
                    // padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        CustomAppCard(
                          showBorder: true,
                          borderColor: MyColor.borderColor,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: "[#${controller.model.data?.myTickets?.ticket ?? ''}] ",
                                              style: boldDefault.copyWith(
                                                color: MyColor.getBodyTextColor(),
                                              ),
                                            ),
                                            TextSpan(
                                              text: controller.model.data?.myTickets?.subject ?? '',
                                              style: boldDefault.copyWith(
                                                color: MyColor.getHeadingTextColor(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    spaceSide(Dimensions.space10),
                                    CustomAppCard(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: Dimensions.space10,
                                        vertical: Dimensions.space2,
                                      ),
                                      radius: Dimensions.largeRadius,
                                      backgroundColor: controller
                                          .getStatusColor(
                                            controller.model.data?.myTickets?.status ?? "0",
                                          )
                                          .withValues(alpha: 0.2),
                                      borderColor: controller.getStatusColor(
                                        controller.model.data?.myTickets?.status ?? "0",
                                      ),
                                      child: Text(
                                        controller.getStatusText(
                                          controller.model.data?.myTickets?.status ?? "0",
                                        ),
                                        style: regularDefault.copyWith(
                                          color: controller.getStatusColor(
                                            controller.model.data?.myTickets?.status ?? "0",
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Dimensions.space15),
                        CustomAppCard(
                          showBorder: true,
                          borderColor: MyColor.borderColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomTextField(
                                labelText: MyStrings.message,
                                controller: controller.replyController,
                                hintText: MyStrings.yourReply.tr,
                                maxLines: 4,
                                onChanged: (value) {},
                              ),
                              spaceDown(Dimensions.space10),
                              LabelText(text: MyStrings.attachments.tr),
                              spaceDown(Dimensions.space10),
                              if (controller.attachmentList.isNotEmpty) ...[
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      Stack(
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              if (controller.attachmentList.length < 5) {
                                                controller.pickFile();
                                              } else {
                                                CustomSnackBar.error(
                                                  errorList: [
                                                    MyStrings.maxAttachmentError,
                                                  ],
                                                );
                                              }
                                            },
                                            child: InnerShadowContainer(
                                              width: context.width / 5,
                                              height: context.width / 5,
                                              backgroundColor: MyColor.neutral50,
                                              borderRadius: Dimensions.largeRadius,
                                              blur: 6,
                                              offset: Offset(3, 3),
                                              shadowColor: MyColor.colorBlack.withValues(alpha: 0.04),
                                              isShadowTopLeft: true,
                                              isShadowBottomRight: true,
                                              padding: EdgeInsetsGeometry.all(
                                                Dimensions.space8,
                                              ),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.attachment_rounded,
                                                      color: MyColor.getBodyTextColor(),
                                                    ),
                                                    Text(
                                                      MyStrings.chooseFile.tr,
                                                      style: regularDefault.copyWith(
                                                        color: MyColor.getBodyTextColor(),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: List.generate(
                                          controller.attachmentList.length,
                                          (index) => AttachmentPreviewWidget(
                                            path: '',
                                            onTap: () {
                                              controller.removeAttachmentFromList(
                                                index,
                                              );
                                            },
                                            isShowCloseButton: true,
                                            file: controller.attachmentList[index],
                                            isFileImg: MyUtils.isImage(
                                              controller.attachmentList[index].path,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                ZoomTapAnimation(
                                  onTap: () {
                                    controller.pickFile();
                                  },
                                  child: InnerShadowContainer(
                                    width: double.infinity,
                                    backgroundColor: MyColor.neutral50,
                                    borderRadius: Dimensions.largeRadius,
                                    blur: 6,
                                    offset: Offset(3, 3),
                                    shadowColor: MyColor.colorBlack.withValues(
                                      alpha: 0.04,
                                    ),
                                    isShadowTopLeft: true,
                                    isShadowBottomRight: true,
                                    padding: EdgeInsetsGeometry.symmetric(
                                      vertical: Dimensions.space16,
                                      horizontal: Dimensions.space16,
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.attachment_rounded,
                                          color: MyColor.getBodyTextColor(),
                                        ),
                                        Text(
                                          MyStrings.chooseFile.tr,
                                          style: regularDefault.copyWith(
                                            color: MyColor.getBodyTextColor(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: Dimensions.space30),
                              RoundedButton(
                                isLoading: controller.submitLoading,
                                text: MyStrings.reply.tr,
                                press: () {
                                  controller.uploadTicketViewReply();
                                },
                              ),
                              const SizedBox(height: Dimensions.space30),
                            ],
                          ),
                        ),
                        controller.messageList.isEmpty
                            ? NoDataWidget()
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 30,
                                ),
                                child: ListView.separated(
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: controller.messageList.length,
                                  separatorBuilder: (context, index) => const SizedBox(
                                    height: Dimensions.space20,
                                  ),
                                  shrinkWrap: true,
                                  itemBuilder: (context, index) => TicketViewCommentReplyModel(
                                    index: index,
                                    messages: controller.messageList[index],
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
