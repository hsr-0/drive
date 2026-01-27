import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/data/controller/vehicle_verification/vehicle_verification_controller.dart';
import 'package:ovoride_driver/data/model/global/formdata/global_kyc_form_data.dart';
import 'package:ovoride_driver/data/repo/vehicle_verification/vehicle_verification_repo.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/card/inner_shadow_container.dart';
import 'package:ovoride_driver/presentation/components/checkbox/custom_check_box.dart';
import 'package:ovoride_driver/presentation/components/custom_drop_down_button_with_text_field.dart';
import 'package:ovoride_driver/presentation/components/custom_loader/custom_loader.dart';
import 'package:ovoride_driver/presentation/components/custom_radio_button.dart';
import 'package:ovoride_driver/presentation/components/image/my_local_image_widget.dart';
import 'package:ovoride_driver/presentation/screens/vehicle_verification/widget/vahecle_alrady_veified_widget.dart';
import 'package:ovoride_driver/presentation/screens/vehicle_verification/widget/vehicle_bottom_sheet.dart';
import 'package:ovoride_driver/presentation/screens/vehicle_verification/widget/vehicle_brand_widget.dart';
import 'package:ovoride_driver/presentation/screens/vehicle_verification/widget/vehicle_service_widget.dart';
import 'package:ovoride_driver/presentation/screens/vehicle_verification/widget/vehicle_verification_pending.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

import '../../../core/utils/dimensions.dart';
import '../../../core/utils/my_color.dart';
import '../../../core/utils/my_strings.dart';
import '../../../core/utils/style.dart';
import '../../components/app-bar/custom_appbar.dart';
import '../../components/buttons/rounded_button.dart';
import '../../components/divider/custom_spacer.dart';
import '../../components/text-form-field/custom_text_field.dart';
import '../../components/text/header_text.dart';
import '../../components/text/label_text_with_instructions.dart';

class VehicleVerificationScreen extends StatefulWidget {
  const VehicleVerificationScreen({super.key});

  @override
  State<VehicleVerificationScreen> createState() => _VehicleVerificationScreenState();
}

class _VehicleVerificationScreenState extends State<VehicleVerificationScreen> {
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    Get.put(VehicleVerificationRepo(apiClient: Get.find()));
    Get.put(VehicleVerificationController(repo: Get.find()));
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<VehicleVerificationController>().beforeInitLoadKycData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VehicleVerificationController>(
      builder: (controller) {
        return Scaffold(
          appBar: CustomAppBar(
            isShowBackBtn: true,
            title: controller.isAlreadyVerified ? MyStrings.vehicleInformation.tr : MyStrings.vehicleVerification.tr,
          ),
          body: SingleChildScrollView(
            padding: Dimensions.previewPaddingHV,
            physics: const BouncingScrollPhysics(),
            child: controller.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(Dimensions.space15),
                    child: CustomLoader(isFullScreen: true),
                  )
                : controller.isAlreadyPending
                    ? const VehicleVerificationPendingSection()
                    : controller.isNoDataFound
                        ? const VehicleAlreadyVerifiedWidget(isPending: false)
                        : Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                //Select Service
                                CustomAppCard(
                                  width: double.infinity,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      HeaderText(
                                        text: MyStrings.vehicleVerification.tr,
                                        style: boldExtraLarge.copyWith(
                                          color: MyColor.getHeadingTextColor(),
                                          fontSize: Dimensions.fontTitleLarge,
                                        ),
                                      ),
                                      spaceDown(Dimensions.space3),
                                      Text(
                                        MyStrings.vehicleVerificationSubTitle.tr,
                                        style: regularDefault.copyWith(
                                          color: MyColor.getBodyTextColor(),
                                          fontSize: Dimensions.fontMedium,
                                        ),
                                      ),
                                      spaceDown(Dimensions.space15),
                                      HeaderText(
                                        text: MyStrings.selectService,
                                        style: boldLarge.copyWith(
                                          color: MyColor.getHeadingTextColor(),
                                          fontSize: Dimensions.fontLarge,
                                        ),
                                      ),
                                      spaceDown(Dimensions.space10),
                                      SingleChildScrollView(
                                        clipBehavior: Clip.none,
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        child: Row(
                                          children: List.generate(
                                            controller.services.length,
                                            (index) {
                                              return VehicleServiceWidget(
                                                image: "${controller.serviceImagePath}/${controller.services[index].image ?? ''}",
                                                name: controller.services[index].name ?? '',
                                                isSelected: controller.services[index].id == controller.selectedService.id,
                                                onTap: () {
                                                  controller.selectService(
                                                    controller.services[index],
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                spaceDown(Dimensions.space15),
                                CustomAppCard(
                                  width: double.infinity,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      HeaderText(
                                        text: MyStrings.selectBrand,
                                        style: boldLarge.copyWith(
                                          color: MyColor.getHeadingTextColor(),
                                          fontSize: Dimensions.fontLarge,
                                        ),
                                      ),
                                      spaceDown(Dimensions.space20),
                                      SingleChildScrollView(
                                        clipBehavior: Clip.none,
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        child: Row(
                                          children: List.generate(
                                            controller.brands.length,
                                            (index) => VehicleBrandWidget(
                                              image: "${controller.brandImagePath}/${controller.brands[index].image ?? ''}",
                                              name: controller.brands[index].name ?? '',
                                              isSelected: controller.brands[index].id == controller.selectedBrand.id,
                                              onTap: () {
                                                controller.selectBrand(
                                                  controller.brands[index],
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      spaceDown(Dimensions.space20),
                                      CustomTextField(
                                        hintText: controller.modelValue.name,
                                        labelWidget: Column(
                                          children: [
                                            HeaderText(
                                              text: (MyStrings.vehicleModel.tr),
                                              style: regularDefault.copyWith(
                                                color: MyColor.getHeadingTextColor(),
                                                fontSize: Dimensions.fontLarge,
                                              ),
                                            ),
                                            spaceDown(Dimensions.space10),
                                          ],
                                        ),
                                        controller: TextEditingController(
                                          text: controller.modelValue.name,
                                        ),
                                        labelText: MyStrings.vehicleModel,
                                        onChanged: (value) {},
                                        readOnly: true,
                                        onTap: () {
                                          controller.clearSearchField();
                                          VehicleBottomSheet.vehicleModelBottomSheet(
                                            context,
                                            controller,
                                          );
                                        },
                                        isShowSuffixIcon: true,
                                        suffixWidget: SizedBox(
                                          height: 30,
                                          width: 30,
                                          child: Icon(
                                            Icons.keyboard_arrow_down,
                                            color: MyColor.colorGrey,
                                          ),
                                        ),
                                        validator: (value) {
                                          if (controller.modelValue.id == "-1") {
                                            return '${MyStrings.vehicleModel.tr} ${MyStrings.isRequired.tr}';
                                          } else {
                                            return null;
                                          }
                                        },
                                      ),
                                      spaceDown(Dimensions.space20),
                                      CustomTextField(
                                        hintText: controller.colorValue.name,
                                        labelWidget: Column(
                                          children: [
                                            HeaderText(
                                              text: (MyStrings.vehicleColor.tr),
                                              style: regularDefault.copyWith(
                                                color: MyColor.getHeadingTextColor(),
                                                fontSize: Dimensions.fontLarge,
                                              ),
                                            ),
                                            spaceDown(Dimensions.space10),
                                          ],
                                        ),
                                        controller: TextEditingController(
                                          text: controller.colorValue.name,
                                        ),
                                        labelText: MyStrings.vehicleColor,
                                        onChanged: (value) {},
                                        readOnly: true,
                                        onTap: () {
                                          controller.clearSearchField();
                                          VehicleBottomSheet.vehicleColorBottomSheet(
                                            context,
                                            controller,
                                          );
                                        },
                                        isShowSuffixIcon: true,
                                        suffixWidget: SizedBox(
                                          height: 30,
                                          width: 30,
                                          child: Icon(
                                            Icons.keyboard_arrow_down,
                                            color: MyColor.colorGrey,
                                          ),
                                        ),
                                        validator: (value) {
                                          if (controller.colorValue.id == "-1") {
                                            return '${MyStrings.vehicleColor.tr} ${MyStrings.isRequired.tr}';
                                          } else {
                                            return null;
                                          }
                                        },
                                      ),
                                      spaceDown(Dimensions.space20),
                                      CustomTextField(
                                        hintText: controller.yearValue.name,
                                        labelWidget: Column(
                                          children: [
                                            HeaderText(
                                              text: (MyStrings.vehicleYear.tr),
                                              style: regularDefault.copyWith(
                                                color: MyColor.getHeadingTextColor(),
                                                fontSize: Dimensions.fontLarge,
                                              ),
                                            ),
                                            spaceDown(Dimensions.space10),
                                          ],
                                        ),
                                        controller: TextEditingController(
                                          text: controller.yearValue.name,
                                        ),
                                        isShowInstructionWidget: true,
                                        labelText: (MyStrings.vehicleYear.tr),
                                        onChanged: (value) {},
                                        readOnly: true,
                                        onTap: () {
                                          controller.clearSearchField();
                                          VehicleBottomSheet.vehicleYearBottomSheet(
                                            context,
                                            controller,
                                          );
                                        },
                                        isShowSuffixIcon: true,
                                        suffixWidget: SizedBox(
                                          height: 30,
                                          width: 30,
                                          child: Icon(
                                            Icons.keyboard_arrow_down,
                                            color: MyColor.colorGrey,
                                          ),
                                        ),
                                        validator: (value) {
                                          if (controller.yearValue.id == "-1") {
                                            return '${MyStrings.vehicleYear.tr} ${MyStrings.isRequired.tr}';
                                          } else {
                                            return null;
                                          }
                                        },
                                      ),
                                      spaceDown(Dimensions.space20),
                                      CustomTextField(
                                        controller: controller.vehicleNumberController,
                                        labelWidget: Column(
                                          children: [
                                            HeaderText(
                                              text: (MyStrings.vehicleNumber.tr),
                                              style: regularDefault.copyWith(
                                                color: MyColor.getHeadingTextColor(),
                                                fontSize: Dimensions.fontLarge,
                                              ),
                                            ),
                                            spaceDown(Dimensions.space10),
                                          ],
                                        ),
                                        hintText: "Example: A395DCF",
                                        isShowInstructionWidget: true,
                                        labelText: MyStrings.vehicleNumber,
                                        isRequired: true,
                                        textInputType: TextInputType.text,
                                        onChanged: (value) {},
                                        validator: (value) {
                                          if (value.toString().isEmpty) {
                                            return '${MyStrings.vehicleNumber.tr} ${MyStrings.isRequired.tr}';
                                          } else {
                                            return null;
                                          }
                                        },
                                      ),
                                      spaceDown(Dimensions.space20),
                                      LabelTextInstruction(
                                        text: MyStrings.vehicleImage.tr,
                                        textStyle: regularDefault.copyWith(
                                          color: MyColor.getHeadingTextColor(),
                                          fontSize: Dimensions.fontLarge,
                                        ),
                                        isRequired: true,
                                        instructions: null,
                                      ),
                                      spaceDown(Dimensions.space10),
                                      ZoomTapAnimation(
                                        onTap: () {
                                          controller.pickFile(0, isVehicle: true);
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
                                          child: controller.imageFile == null
                                              ? Column(
                                                  children: [
                                                    const Icon(
                                                      Icons.attachment_rounded,
                                                      color: MyColor.colorGrey,
                                                    ),
                                                    Text(
                                                      MyStrings.attachment.tr,
                                                      style: lightDefault.copyWith(
                                                        color: MyColor.colorGrey,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : Image.file(
                                                  controller.imageFile!,
                                                  fit: BoxFit.contain,
                                                  height: 140,
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                spaceDown(Dimensions.space20),
                                if (controller.formList.isNotEmpty) ...[
                                  CustomAppCard(
                                    width: double.infinity,
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ListView.builder(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            scrollDirection: Axis.vertical,
                                            padding: EdgeInsets.zero,
                                            itemCount: controller.formList.length,
                                            itemBuilder: (ctx, index) {
                                              GlobalFormModel? model = controller.formList[index];
                                              return Padding(
                                                padding: const EdgeInsets.all(3),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    model.type == 'text' || model.type == 'number' || model.type == 'email' || model.type == 'url'
                                                        ? Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              CustomTextField(
                                                                hintText: (model.name ?? '').toLowerCase().capitalizeFirst,
                                                                labelWidget: Column(
                                                                  children: [
                                                                    LabelTextInstruction(
                                                                      text: model.name ?? '',
                                                                      isRequired: model.isRequired == 'optional' ? false : true,
                                                                      instructions: model.instruction,
                                                                      textStyle: regularDefault.copyWith(
                                                                        color: MyColor.getHeadingTextColor(),
                                                                        fontSize: Dimensions.fontLarge,
                                                                      ),
                                                                    ),
                                                                    spaceDown(
                                                                      Dimensions.space10,
                                                                    ),
                                                                  ],
                                                                ),
                                                                isShowInstructionWidget: true,
                                                                instructions: model.instruction,
                                                                labelText: model.name ?? '',
                                                                isRequired: model.isRequired == 'optional' ? false : true,
                                                                textInputType: model.type == 'number'
                                                                    ? TextInputType.number
                                                                    : model.type == 'email'
                                                                        ? TextInputType.emailAddress
                                                                        : model.type == 'url'
                                                                            ? TextInputType.url
                                                                            : TextInputType.text,
                                                                onChanged: (value) {
                                                                  controller.changeSelectedValue(
                                                                    value,
                                                                    index,
                                                                  );
                                                                },
                                                                validator: (value) {
                                                                  if (model.isRequired != 'optional' && value.toString().isEmpty) {
                                                                    return '${model.name.toString().capitalizeFirst} ${MyStrings.isRequired}';
                                                                  } else {
                                                                    return null;
                                                                  }
                                                                },
                                                              ),
                                                              const SizedBox(
                                                                height: Dimensions.space10,
                                                              ),
                                                            ],
                                                          )
                                                        : model.type == 'textarea'
                                                            ? Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  CustomTextField(
                                                                    instructions: model.instruction,
                                                                    isShowInstructionWidget: true,
                                                                    labelText: model.name ?? '',
                                                                    labelWidget: Column(
                                                                      children: [
                                                                        LabelTextInstruction(
                                                                          text: model.name ?? '',
                                                                          isRequired: model.isRequired == 'optional' ? false : true,
                                                                          instructions: model.instruction,
                                                                          textStyle: regularDefault.copyWith(
                                                                            color: MyColor.getHeadingTextColor(),
                                                                            fontSize: Dimensions.fontLarge,
                                                                          ),
                                                                        ),
                                                                        spaceDown(
                                                                          Dimensions.space10,
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    isRequired: model.isRequired == 'optional' ? false : true,
                                                                    hintText: (model.name ?? '').capitalizeFirst,
                                                                    textInputType: TextInputType.multiline,
                                                                    maxLines: 5,
                                                                    onChanged: (value) {
                                                                      controller.changeSelectedValue(
                                                                        value,
                                                                        index,
                                                                      );
                                                                    },
                                                                    validator: (value) {
                                                                      if (model.isRequired != 'optional' && value.toString().isEmpty) {
                                                                        return '${model.name.toString().capitalizeFirst} ${MyStrings.isRequired}';
                                                                      } else {
                                                                        return null;
                                                                      }
                                                                    },
                                                                  ),
                                                                  const SizedBox(
                                                                    height: Dimensions.space10,
                                                                  ),
                                                                ],
                                                              )
                                                            : model.type == 'select'
                                                                ? Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    children: [
                                                                      LabelTextInstruction(
                                                                        text: model.name ?? '',
                                                                        isRequired: model.isRequired == 'optional' ? false : true,
                                                                        instructions: model.instruction,
                                                                        textStyle: regularDefault.copyWith(
                                                                          color: MyColor.getHeadingTextColor(),
                                                                          fontSize: Dimensions.fontLarge,
                                                                        ),
                                                                      ),
                                                                      spaceDown(
                                                                        Dimensions.space10,
                                                                      ),
                                                                      CustomDropDownWithTextField(
                                                                        list: model.options ?? [],
                                                                        onChanged: (value) {
                                                                          controller.changeSelectedValue(
                                                                            value,
                                                                            index,
                                                                          );
                                                                        },
                                                                        selectedValue: model.selectedValue,
                                                                      ),
                                                                      const SizedBox(
                                                                        height: Dimensions.space10,
                                                                      ),
                                                                    ],
                                                                  )
                                                                : model.type == 'radio'
                                                                    ? Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                          LabelTextInstruction(
                                                                            text: model.name ?? '',
                                                                            isRequired: model.isRequired == 'optional' ? false : true,
                                                                            instructions: model.instruction,
                                                                            textStyle: regularDefault.copyWith(
                                                                              color: MyColor.getHeadingTextColor(),
                                                                              fontSize: Dimensions.fontLarge,
                                                                            ),
                                                                          ),
                                                                          spaceDown(
                                                                            Dimensions.space10,
                                                                          ),
                                                                          CustomRadioButton(
                                                                            title: model.name,
                                                                            selectedIndex: controller.formList[index].options?.indexOf(
                                                                                  model.selectedValue ?? '',
                                                                                ) ??
                                                                                0,
                                                                            list: model.options ?? [],
                                                                            onChanged: (selectedIndex) {
                                                                              controller.changeSelectedRadioBtnValue(
                                                                                index,
                                                                                selectedIndex,
                                                                              );
                                                                            },
                                                                          ),
                                                                        ],
                                                                      )
                                                                    : model.type == 'checkbox'
                                                                        ? Column(
                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                            children: [
                                                                              LabelTextInstruction(
                                                                                text: model.name ?? '',
                                                                                isRequired: model.isRequired == 'optional' ? false : true,
                                                                                instructions: model.instruction,
                                                                                textStyle: regularDefault.copyWith(
                                                                                  color: MyColor.getHeadingTextColor(),
                                                                                  fontSize: Dimensions.fontLarge,
                                                                                ),
                                                                              ),
                                                                              spaceDown(
                                                                                Dimensions.space10,
                                                                              ),
                                                                              CustomCheckBox(
                                                                                selectedValue: controller.formList[index].cbSelected,
                                                                                list: model.options ?? [],
                                                                                onChanged: (value) {
                                                                                  controller.changeSelectedCheckBoxValue(
                                                                                    index,
                                                                                    value,
                                                                                  );
                                                                                },
                                                                              ),
                                                                            ],
                                                                          )
                                                                        : model.type == 'file'
                                                                            ? Column(
                                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                                children: [
                                                                                  LabelTextInstruction(
                                                                                    text: model.name ?? '',
                                                                                    isRequired: model.isRequired == 'optional' ? false : true,
                                                                                    instructions: model.instruction,
                                                                                    textStyle: regularDefault.copyWith(
                                                                                      color: MyColor.getHeadingTextColor(),
                                                                                      fontSize: Dimensions.fontLarge,
                                                                                    ),
                                                                                  ),
                                                                                  spaceDown(
                                                                                    Dimensions.space10,
                                                                                  ),
                                                                                  CustomTextField(
                                                                                    hintText: model.imageFile == null ? (model.name ?? '') : model.selectedValue ?? MyStrings.chooseFile,
                                                                                    isShowInstructionWidget: true,
                                                                                    instructions: model.instruction,
                                                                                    labelText: '',
                                                                                    readOnly: true,
                                                                                    isRequired: model.isRequired == 'optional' ? false : true,
                                                                                    textInputType: TextInputType.none,
                                                                                    onChanged: (value) {},
                                                                                    onTap: () {
                                                                                      controller.pickFile(
                                                                                        index,
                                                                                      );
                                                                                    },
                                                                                    hintTextStyle: regularLarge.copyWith(
                                                                                      color: MyColor.getPrimaryColor(),
                                                                                    ),
                                                                                    prefixIcon: Padding(
                                                                                      padding: EdgeInsetsDirectional.only(
                                                                                        start: Dimensions.space10,
                                                                                      ),
                                                                                      child: MyLocalImageWidget(
                                                                                        imagePath: MyIcons.attachment,
                                                                                        imageOverlayColor: MyColor.getPrimaryColor(),
                                                                                        width: Dimensions.space30,
                                                                                        height: Dimensions.space30,
                                                                                        boxFit: BoxFit.contain,
                                                                                      ),
                                                                                    ),
                                                                                    validator: (value) {
                                                                                      if (model.isRequired != 'optional' && model.imageFile == null) {
                                                                                        return '${model.name.toString()} ${MyStrings.isRequired}';
                                                                                      } else {
                                                                                        return null;
                                                                                      }
                                                                                    },
                                                                                  ),
                                                                                ],
                                                                              )
                                                                            : model.type == 'datetime'
                                                                                ? Column(
                                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                                    children: [
                                                                                      Padding(
                                                                                        padding: const EdgeInsets.symmetric(
                                                                                          vertical: Dimensions.textToTextSpace,
                                                                                        ),
                                                                                        child: CustomTextField(
                                                                                          isShowInstructionWidget: true,
                                                                                          labelWidget: Column(
                                                                                            children: [
                                                                                              LabelTextInstruction(
                                                                                                text: model.name ?? '',
                                                                                                isRequired: model.isRequired == 'optional' ? false : true,
                                                                                                instructions: model.instruction,
                                                                                                textStyle: regularDefault.copyWith(
                                                                                                  color: MyColor.getHeadingTextColor(),
                                                                                                  fontSize: Dimensions.fontLarge,
                                                                                                ),
                                                                                              ),
                                                                                              spaceDown(
                                                                                                Dimensions.space10,
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                          instructions: model.instruction,
                                                                                          isRequired: model.isRequired == 'optional' ? false : true,
                                                                                          hintText: (model.name ?? '').toString().capitalizeFirst,
                                                                                          labelText: model.name ?? '',
                                                                                          controller: controller.formList[index].textEditingController,
                                                                                          textInputType: TextInputType.datetime,
                                                                                          readOnly: true,
                                                                                          validator: (value) {
                                                                                            if (model.isRequired != 'optional' && value.toString().isEmpty) {
                                                                                              return '${model.name.toString().capitalizeFirst} ${MyStrings.isRequired}';
                                                                                            } else {
                                                                                              return null;
                                                                                            }
                                                                                          },
                                                                                          onTap: () {
                                                                                            controller.changeSelectedDateTimeValue(
                                                                                              index,
                                                                                              context,
                                                                                            );
                                                                                          },
                                                                                          onChanged: (value) {
                                                                                            controller.changeSelectedValue(
                                                                                              value,
                                                                                              index,
                                                                                            );
                                                                                          },
                                                                                        ),
                                                                                      ),
                                                                                    ],
                                                                                  )
                                                                                : model.type == 'date'
                                                                                    ? Column(
                                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                                        children: [
                                                                                          Padding(
                                                                                            padding: const EdgeInsets.symmetric(
                                                                                              vertical: Dimensions.textToTextSpace,
                                                                                            ),
                                                                                            child: CustomTextField(
                                                                                              isShowInstructionWidget: true,
                                                                                              instructions: model.instruction,
                                                                                              labelWidget: Column(
                                                                                                children: [
                                                                                                  LabelTextInstruction(
                                                                                                    text: model.name ?? '',
                                                                                                    isRequired: model.isRequired == 'optional' ? false : true,
                                                                                                    instructions: model.instruction,
                                                                                                    textStyle: regularDefault.copyWith(
                                                                                                      color: MyColor.getHeadingTextColor(),
                                                                                                      fontSize: Dimensions.fontLarge,
                                                                                                    ),
                                                                                                  ),
                                                                                                  spaceDown(
                                                                                                    Dimensions.space10,
                                                                                                  ),
                                                                                                ],
                                                                                              ),
                                                                                              isRequired: model.isRequired == 'optional' ? false : true,
                                                                                              hintText: (model.name ?? '').toString().capitalizeFirst,
                                                                                              labelText: model.name ?? '',
                                                                                              controller: controller.formList[index].textEditingController,
                                                                                              textInputType: TextInputType.datetime,
                                                                                              readOnly: true,
                                                                                              validator: (value) {
                                                                                                if (model.isRequired != 'optional' && value.toString().isEmpty) {
                                                                                                  return '${model.name.toString().capitalizeFirst} ${MyStrings.isRequired}';
                                                                                                } else {
                                                                                                  return null;
                                                                                                }
                                                                                              },
                                                                                              onTap: () {
                                                                                                controller.changeSelectedDateOnlyValue(
                                                                                                  index,
                                                                                                  context,
                                                                                                );
                                                                                              },
                                                                                              onChanged: (value) {
                                                                                                controller.changeSelectedValue(
                                                                                                  value,
                                                                                                  index,
                                                                                                );
                                                                                              },
                                                                                            ),
                                                                                          ),
                                                                                        ],
                                                                                      )
                                                                                    : model.type == 'time'
                                                                                        ? Column(
                                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                                            children: [
                                                                                              Padding(
                                                                                                padding: const EdgeInsets.symmetric(
                                                                                                  vertical: Dimensions.textToTextSpace,
                                                                                                ),
                                                                                                child: CustomTextField(
                                                                                                  isShowInstructionWidget: true,
                                                                                                  instructions: model.instruction,
                                                                                                  labelWidget: Column(
                                                                                                    children: [
                                                                                                      LabelTextInstruction(
                                                                                                        text: model.name ?? '',
                                                                                                        isRequired: model.isRequired == 'optional' ? false : true,
                                                                                                        instructions: model.instruction,
                                                                                                        textStyle: regularDefault.copyWith(
                                                                                                          color: MyColor.getHeadingTextColor(),
                                                                                                          fontSize: Dimensions.fontLarge,
                                                                                                        ),
                                                                                                      ),
                                                                                                      spaceDown(
                                                                                                        Dimensions.space10,
                                                                                                      ),
                                                                                                    ],
                                                                                                  ),
                                                                                                  isRequired: model.isRequired == 'optional' ? false : true,
                                                                                                  hintText: (model.name ?? '').toString().capitalizeFirst,
                                                                                                  labelText: model.name ?? '',
                                                                                                  controller: controller.formList[index].textEditingController,
                                                                                                  textInputType: TextInputType.datetime,
                                                                                                  readOnly: true,
                                                                                                  validator: (value) {
                                                                                                    if (model.isRequired != 'optional' && value.toString().isEmpty) {
                                                                                                      return '${model.name.toString().capitalizeFirst} ${MyStrings.isRequired}';
                                                                                                    } else {
                                                                                                      return null;
                                                                                                    }
                                                                                                  },
                                                                                                  onTap: () {
                                                                                                    controller.changeSelectedTimeOnlyValue(
                                                                                                      index,
                                                                                                      context,
                                                                                                    );
                                                                                                  },
                                                                                                  onChanged: (value) {
                                                                                                    controller.changeSelectedValue(
                                                                                                      value,
                                                                                                      index,
                                                                                                    );
                                                                                                  },
                                                                                                ),
                                                                                              ),
                                                                                            ],
                                                                                          )
                                                                                        : const SizedBox(),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  spaceDown(Dimensions.space20),
                                ],
                                if (controller.riderRules.isNotEmpty) ...[
                                  CustomAppCard(
                                    width: double.infinity,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        HeaderText(
                                          text: MyStrings.selectRideRules.tr,
                                          style: boldExtraLarge.copyWith(
                                            color: MyColor.getHeadingTextColor(),
                                            fontSize: Dimensions.fontTitleLarge,
                                          ),
                                        ),
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: controller.riderRules.length,
                                          padding: EdgeInsets.zero,
                                          itemBuilder: (context, index) {
                                            return CheckboxListTile(
                                              contentPadding: EdgeInsets.zero,
                                              side: BorderSide(
                                                color: MyColor.borderColor,
                                                width: 1.5,
                                              ),
                                              activeColor: MyColor.getPrimaryColor(),
                                              checkboxShape: RoundedRectangleBorder(
                                                borderRadius: BorderRadiusGeometry.circular(
                                                  Dimensions.defaultRadius,
                                                ),
                                              ),
                                              title: Text(
                                                controller.riderRules[index].name ?? '',
                                                style: regularLarge.copyWith(
                                                  color: MyColor.getHeadingTextColor(),
                                                ),
                                              ),
                                              value: controller.selectedRiderRules.contains(
                                                controller.riderRules[index],
                                              ),
                                              onChanged: (value) {
                                                controller.selectRideRule(
                                                  controller.riderRules[index],
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                spaceDown(Dimensions.space15),
                                RoundedButton(
                                  text: MyStrings.submit,
                                  isLoading: controller.submitLoading,
                                  press: () {
                                    if (formKey.currentState!.validate()) {
                                      controller.submitKycData();
                                    }
                                  },
                                ),
                                spaceDown(Dimensions.space15),
                              ],
                            ),
                          ),
          ),
        );
      },
    );
  }
}
