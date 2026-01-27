import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_images.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/data/controller/withdraw/add_new_withdraw_controller.dart';
import 'package:ovoride_driver/presentation/components/annotated_region/annotated_region_widget.dart';
import 'package:ovoride_driver/presentation/components/bottom-sheet/bottom_sheet_header_row.dart';
import 'package:ovoride_driver/presentation/components/image/my_network_image_widget.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';

class WithdrawMethodListBottomSheet extends StatelessWidget {
  const WithdrawMethodListBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AddNewWithdrawController>(
      builder: (controller) {
        return AnnotatedRegionWidget(
          child: Container(
            constraints: BoxConstraints(maxHeight: context.height * .8),
            color: MyColor.colorWhite,
            child: Column(
              children: [
                const BottomSheetHeaderRow(),
                HeaderText(
                  text: MyStrings.withdrawMethod.tr,
                  style: mediumOverLarge.copyWith(
                    fontSize: Dimensions.fontOverLarge,
                    fontWeight: FontWeight.normal,
                    color: MyColor.colorBlack,
                  ),
                ),
                const SizedBox(height: Dimensions.space15),
                Flexible(
                  child: ListView.builder(
                    itemCount: controller.withdrawMethodList.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final method = controller.withdrawMethodList[index];
                      final bool selected = controller.withdrawMethod?.id == method.id;
                      return Container(
                        margin: const EdgeInsetsDirectional.only(
                          top: Dimensions.space15,
                        ),
                        child: Material(
                          elevation: 0.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              Dimensions.space12,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? MyColor.primaryColor
                                  : MyColor.rideBorderColor.withValues(
                                      alpha: .9,
                                    ),
                            ),
                          ),
                          color: Colors.white,
                          child: CheckboxListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                Dimensions.space12,
                              ),
                            ),
                            value: selected,
                            checkColor: MyColor.colorWhite,
                            onChanged: (val) {
                              if (method.id != -1) {
                                controller.setWithdrawMethod(method);
                                Get.back();
                              }
                            },
                            checkboxShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                Dimensions.space10,
                              ),
                            ),
                            overlayColor: WidgetStateProperty.all(
                              MyColor.primaryColor.withValues(alpha: .1),
                            ),
                            contentPadding: const EdgeInsetsDirectional.only(
                              start: Dimensions.space20,
                              end: Dimensions.space20,
                              top: Dimensions.space1,
                              bottom: Dimensions.space1,
                            ),
                            activeColor: MyColor.primaryColor,
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                method.id == -1
                                    ? Image.asset(
                                        MyImages.amount,
                                        width: Dimensions.space35,
                                        height: Dimensions.space35,
                                        fit: BoxFit.fitWidth,
                                        color: MyColor.primaryColor,
                                      )
                                    : MyImageWidget(
                                        imageUrl: '${UrlContainer.domainUrl}/${controller.imagePath}/${method.image}',
                                        width: Dimensions.space40,
                                        height: Dimensions.space40,
                                        boxFit: BoxFit.fitWidth,
                                        radius: 4,
                                      ),
                                const SizedBox(width: Dimensions.space10),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    method.name ?? '',
                                    style: semiBoldDefault.copyWith(
                                      color: MyColor.colorBlack,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
