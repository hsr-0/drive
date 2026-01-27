import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/controller/support/new_ticket_controller.dart';
import 'package:ovoride_driver/data/repo/support/support_repo.dart';
import 'package:ovoride_driver/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/card/inner_shadow_container.dart';
import 'package:ovoride_driver/presentation/components/custom_loader/custom_loader.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';
import 'package:ovoride_driver/presentation/components/text-form-field/custom_text_field.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';
import 'package:ovoride_driver/presentation/screens/support_ticket/ticket_details/widget/attachment_preview.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

class AddNewTicketScreen extends StatefulWidget {
  const AddNewTicketScreen({super.key});

  @override
  State<AddNewTicketScreen> createState() => _AddNewTicketScreenState();
}

class _AddNewTicketScreenState extends State<AddNewTicketScreen> {
  @override
  void initState() {
    Get.put(SupportRepo(apiClient: Get.find()));
    Get.put(NewTicketController(repo: Get.find()));

    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NewTicketController>(
      builder: (controller) => Scaffold(
        backgroundColor: MyColor.getScreenBgColor(),
        appBar: CustomAppBar(
          title: MyStrings.createTicket.tr,
          isTitleCenter: true,
        ),
        body: controller.isLoading
            ? const CustomLoader(isFullScreen: true)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(Dimensions.space16),
                child: CustomAppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextField(
                        labelWidget: Column(
                          children: [
                            HeaderText(
                              text: MyStrings.subject,
                              style: regularDefault.copyWith(
                                color: MyColor.getTextColor(),
                                fontSize: Dimensions.fontNormal,
                              ),
                            ),
                            spaceDown(Dimensions.space5),
                          ],
                        ),
                        labelText: MyStrings.subject,
                        hintText: MyStrings.enterYourSubject.tr,
                        controller: controller.subjectController,
                        isPassword: false,
                        isShowSuffixIcon: false,
                        nextFocus: controller.messageFocusNode,
                        onSuffixTap: () {},
                        onChanged: (value) {},
                      ),
                      spaceDown(Dimensions.space10),
                      HeaderText(
                        text: MyStrings.priority,
                        style: regularDefault.copyWith(
                          color: MyColor.getTextColor(),
                          fontSize: Dimensions.fontNormal,
                        ),
                      ),
                      spaceDown(Dimensions.space5),
                      DropDownTextFieldContainer(
                        child: DropdownButton<String>(
                          dropdownColor: MyColor.colorWhite,
                          value: controller.selectedPriority,
                          elevation: 8,
                          icon: const Icon(Icons.keyboard_arrow_down),
                          iconDisabledColor: Colors.grey,
                          iconEnabledColor: MyColor.primaryColor,
                          isExpanded: true,
                          underline: Container(
                            height: 0,
                            color: Colors.deepPurpleAccent,
                          ),
                          onChanged: (String? newValue) {
                            controller.setPriority(newValue);
                          },
                          padding: const EdgeInsets.symmetric(
                            vertical: Dimensions.space2,
                          ),
                          borderRadius: BorderRadius.circular(0),
                          items: controller.priorityList.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: regularDefault.copyWith(
                                  fontSize: Dimensions.fontDefault,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      spaceDown(Dimensions.space10),
                      HeaderText(
                        text: MyStrings.message,
                        style: regularDefault.copyWith(
                          color: MyColor.getTextColor(),
                          fontSize: Dimensions.fontNormal,
                        ),
                      ),
                      spaceDown(Dimensions.space5),
                      CustomTextField(
                        hintText: MyStrings.enterYourMessage.tr,
                        isPassword: false,
                        controller: controller.messageController,
                        maxLines: 5,
                        focusNode: controller.messageFocusNode,
                        isShowSuffixIcon: false,
                        onSuffixTap: () {},
                        onChanged: (value) {},
                      ),
                      const SizedBox(height: Dimensions.textToTextSpace),
                      const SizedBox(height: Dimensions.textToTextSpace),
                      ZoomTapAnimation(
                        onTap: () {
                          if (controller.attachmentList.length < 5) {
                            controller.pickFile();
                          } else {
                            CustomSnackBar.error(
                              errorList: [MyStrings.maxAttachmentError],
                            );
                          }
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
                      const SizedBox(height: Dimensions.space2),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: MyStrings.supportedFileHint,
                              style: regularDefault.copyWith(
                                color: MyColor.highPriorityPurpleColor,
                              ),
                            ),
                            TextSpan(
                              text: " .jpg, .jpeg, .png, .pdf, .doc, .docx",
                              style: regularDefault.copyWith(
                                color: MyColor.highPriorityPurpleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Dimensions.space10),
                      if (controller.attachmentList.isNotEmpty) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(
                              controller.attachmentList.length,
                              (index) => AttachmentPreviewWidget(
                                path: controller.attachmentList[index].path,
                                onTap: () => controller.removeAttachmentFromList(index),
                                file: controller.attachmentList[index],
                                isShowCloseButton: true,
                                isFileImg: MyUtils.isImage(
                                  controller.attachmentList[index].path,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      Center(
                        child: RoundedButton(
                          isLoading: controller.submitLoading,
                          text: MyStrings.submit.tr,
                          press: () {
                            controller.submit();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class DropDownTextFieldContainer extends StatelessWidget {
  final Widget child;

  const DropDownTextFieldContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return InnerShadowContainer(
      width: double.infinity,
      backgroundColor: MyColor.neutral50,
      borderRadius: Dimensions.largeRadius,
      blur: 6,
      offset: Offset(3, 3),
      shadowColor: MyColor.colorBlack.withValues(alpha: 0.04),
      isShadowTopLeft: true,
      isShadowBottomRight: true,
      padding: EdgeInsetsGeometry.symmetric(
        vertical: Dimensions.space5,
        horizontal: Dimensions.space16,
      ),
      child: child,
    );
  }
}
