import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/account/profile_controller.dart';

import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';

class DeleteAccountBottomSheetBody extends StatefulWidget {
  ProfileController controller;
  DeleteAccountBottomSheetBody({super.key, required this.controller});
  @override
  State<DeleteAccountBottomSheetBody> createState() => _DeleteAccountBottomSheetBodyState();
}

class _DeleteAccountBottomSheetBodyState extends State<DeleteAccountBottomSheetBody> {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<ProfileController>(
      builder: (controller) {
        return LayoutBuilder(
          builder: (context, box) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () {
                        Get.back();
                      },
                      icon: Icon(
                        Icons.clear,
                        size: 22,
                        color: MyColor.getTextColor(),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: Dimensions.space12),
                  SvgPicture.asset(
                    MyIcons.deleteAccount,
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: Dimensions.space25),
                  Text(
                    MyStrings.deleteYourAccount,
                    style: regularDefault.copyWith(
                      color: MyColor.getTextColor(),
                      fontSize: Dimensions.fontMedium,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Dimensions.space25),
                  Text(
                    MyStrings.deleteBottomSheetSubtitle,
                    style: regularDefault.copyWith(
                      color: MyColor.getTextColor(),
                      fontSize: Dimensions.fontDefault,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Dimensions.space40),
                  GestureDetector(
                    onTap: () {
                      widget.controller.deleteAccount();
                    },
                    child: Container(
                      width: context.width,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 17,
                      ),
                      decoration: BoxDecoration(
                        color: MyColor.colorRed2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: controller.isDeleteBtnLoading
                            ? const SizedBox(
                                width: Dimensions.fontExtraLarge + 4,
                                height: Dimensions.fontExtraLarge + 4,
                                child: CircularProgressIndicator(
                                  color: MyColor.colorWhite,
                                ),
                              )
                            : Text(
                                MyStrings.deleteAccount,
                                style: mediumDefault.copyWith(
                                  color: MyColor.colorWhite,
                                  fontSize: Dimensions.fontExtraLarge,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimensions.space10),
                  GestureDetector(
                    onTap: () {
                      Get.back();
                    },
                    child: Container(
                      width: context.width,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 17,
                      ),
                      decoration: BoxDecoration(
                        color: MyColor.getTextColor().withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          MyStrings.cancel,
                          style: mediumDefault.copyWith(
                            color: MyColor.getTextColor(),
                            fontSize: Dimensions.fontExtraLarge,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
