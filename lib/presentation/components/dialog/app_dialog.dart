import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_images.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';

class AppDialog {
  Future showRideDetailsDialog(
    BuildContext context, {
    required String title,
    required String description,
    required Function() onTap,
    Color? yes,
    Color? no,
  }) {
    return showDialog(
      context: context,
      useSafeArea: true,
      barrierDismissible: false,
      traversalEdgeBehavior: TraversalEdgeBehavior.leaveFlutterView,
      builder: (_) {
        return Dialog(
          surfaceTintColor: MyColor.transparentColor,
          insetPadding: EdgeInsets.zero,
          backgroundColor: MyColor.transparentColor,
          insetAnimationCurve: Curves.easeIn,
          insetAnimationDuration: const Duration(milliseconds: 100),
          child: LayoutBuilder(
            builder: (context, constraint) {
              return CustomAppCard(
                padding: const EdgeInsetsDirectional.only(
                  end: Dimensions.space5,
                  start: Dimensions.space5,
                  top: Dimensions.space30,
                  bottom: Dimensions.space20,
                ),
                margin: const EdgeInsets.all(Dimensions.space16),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraint.minHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            MyImages.warningImage,
                            height: 60,
                            width: 60,
                          ),
                          const SizedBox(height: Dimensions.space20),
                          Text(
                            title,
                            style: semiBoldDefault.copyWith(
                              color: MyColor.getPrimaryColor(),
                              fontSize: 20,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            description,
                            style: lightDefault.copyWith(
                              color: MyColor.getBodyTextColor(),
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Dimensions.space20),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Dimensions.space15,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: RoundedButton(
                                    text: MyStrings.cancel.tr,
                                    press: () {
                                      Navigator.pop(context);
                                    },
                                    bgColor: MyColor.getPrimaryColor().withValues(alpha: 0.1),
                                    textColor: MyColor.getPrimaryColor(),
                                    textStyle: regularDefault.copyWith(
                                      color: MyColor.getPrimaryColor(),
                                      fontSize: Dimensions.fontLarge,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                spaceSide(Dimensions.space10),
                                Expanded(
                                  child: RoundedButton(
                                    text: MyStrings.confirm.tr,
                                    press: () {
                                      Get.back();
                                      onTap();
                                    },
                                  ),
                                ),
                                // Expanded(
                                //   child: InkWell(
                                //     onTap: () {
                                //       Get.back();
                                //     },
                                //     borderRadius: BorderRadius.circular(Dimensions.extraRadius),
                                //     child: Container(
                                //       width: double.infinity,
                                //       padding: const EdgeInsets.symmetric(horizontal: Dimensions.space15, vertical: Dimensions.space12),
                                //       decoration: BoxDecoration(
                                //         color: MyColor.transparentColor,
                                //         borderRadius: BorderRadius.circular(Dimensions.extraRadius),
                                //         border: Border.all(color: MyColor.getBodyTextColor(), width: 0.6),
                                //       ),
                                //       child: Center(
                                //         child: Text(
                                //           "Cancel",
                                //           style: regularDefault.copyWith(
                                //             color: MyColor.primaryColor,
                                //             fontSize: Dimensions.fontLarge,
                                //           ),
                                //         ),
                                //       ),
                                //     ),
                                //   ),
                                // ),
                                // const SizedBox(width: Dimensions.space10),
                                // Expanded(
                                //   child: InkWell(
                                //     onTap: () {
                                //       Get.back();
                                //       onTap();
                                //     },
                                //     borderRadius: BorderRadius.circular(Dimensions.extraRadius),
                                //     child: Container(
                                //       width: double.infinity,
                                //       padding: const EdgeInsets.symmetric(horizontal: Dimensions.space15, vertical: Dimensions.space12),
                                //       decoration: BoxDecoration(color: yes ?? MyColor.primaryColor, borderRadius: BorderRadius.circular(Dimensions.extraRadius)),
                                //       child: Center(
                                //         child: Text(
                                //           MyStrings.confirm.tr,
                                //           style: boldDefault.copyWith(color: MyColor.colorWhite, fontSize: Dimensions.fontLarge),
                                //         ),
                                //       ),
                                //     ),
                                //   ),
                                // )
                              ],
                            ),
                          ),
                          const SizedBox(height: Dimensions.space10),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void warningAlertDialog(
    BuildContext context,
    VoidCallback press, {
    required String msgText,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        surfaceTintColor: MyColor.transparentColor,
        backgroundColor: MyColor.getCardBgColor(),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: Dimensions.space40,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.only(
                  top: Dimensions.space40,
                  bottom: Dimensions.space15,
                  left: Dimensions.space15,
                  right: Dimensions.space15,
                ),
                alignment: Alignment.center,
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  color: MyColor.getCardBgColor(),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Column(
                  children: [
                    /*  Text(
                            MyStrings.areYouSure_.tr,
                            style: semiBoldLarge.copyWith(color: MyColor.colorRed),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),*/
                    const SizedBox(height: Dimensions.space15),
                    Text(
                      msgText.tr,
                      style: regularDefault.copyWith(
                        color: MyColor.getTextColor(),
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 4,
                    ),
                    const SizedBox(height: Dimensions.space20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: RoundedButton(
                            text: MyStrings.no.tr,
                            press: () {
                              Navigator.pop(context);
                            },
                            bgColor: MyColor.greenSuccessColor,
                            textColor: MyColor.colorWhite,
                          ),
                        ),
                        const SizedBox(width: Dimensions.space10),
                        Expanded(
                          child: RoundedButton(
                            text: MyStrings.yes.tr,
                            press: press,
                            bgColor: MyColor.redCancelTextColor,
                            textColor: MyColor.colorWhite,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -30,
                left: MediaQuery.of(context).padding.left,
                right: MediaQuery.of(context).padding.right,
                child: Image.asset(
                  MyImages.warningImage,
                  height: 60,
                  width: 60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
