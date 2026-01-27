import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/driver_kyc_controller/driver_kyc_controller.dart';
import 'package:ovoride_driver/data/model/global/formdata/global_kyc_form_data.dart';
import 'package:ovoride_driver/data/repo/driver_profile_verification/driver_kyc_repo.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/checkbox/custom_check_box.dart';
import 'package:ovoride_driver/presentation/components/custom_drop_down_button_with_text_field.dart';
import 'package:ovoride_driver/presentation/components/custom_loader/custom_loader.dart';
import 'package:ovoride_driver/presentation/components/custom_radio_button.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/my_local_image_widget.dart';
import 'package:ovoride_driver/presentation/components/no_data.dart';
import 'package:ovoride_driver/presentation/screens/driver_profile_verification/widget/already_verifed.dart';
import '../../../core/utils/dimensions.dart';
import '../../../core/utils/my_color.dart';
import '../../../core/utils/my_strings.dart';
import '../../components/app-bar/custom_appbar.dart';
import '../../components/buttons/rounded_button.dart';
import '../../components/text-form-field/custom_text_field.dart';
import '../../components/text/label_text_with_instructions.dart';

class DriverProfileVerificationScreen extends StatefulWidget {
  const DriverProfileVerificationScreen({super.key});

  @override
  State<DriverProfileVerificationScreen> createState() => _DriverProfileVerificationScreenState();
}

class _DriverProfileVerificationScreenState extends State<DriverProfileVerificationScreen> {
  final formKey = GlobalKey<FormState>();
  @override
  void initState() {
    Get.put(DriverVerificationKycRepo(apiClient: Get.find()));
    Get.put(DriverKycController(repo: Get.find()));
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<DriverKycController>().beforeInitLoadKycData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DriverKycController>(
      builder: (controller) {
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Scaffold(
            appBar: CustomAppBar(
              isShowBackBtn: true,
              title: MyStrings.driverDocumentVerification.tr,
            ),
            body: SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: controller.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(Dimensions.space15),
                      child: CustomLoader(),
                    )
                  : controller.isAlreadyVerified
                      ? const AlreadyVerifiedWidget()
                      : controller.isAlreadyPending
                          ? const AlreadyVerifiedWidget(
                              isPending: true,
                              title: MyStrings.driverVerificationUnderReviewMsg,
                            )
                          : controller.isNoDataFound
                              ? const NoDataWidget()
                              : Form(
                                  key: formKey,
                                  child: SingleChildScrollView(
                                    padding: Dimensions.screenPaddingHV,
                                    child: Column(
                                      children: [
                                        CustomAppCard(
                                          width: double.infinity,
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
                                        spaceDown(Dimensions.space15),
                                        RoundedButton(
                                          isLoading: controller.submitLoading,
                                          press: () {
                                            if (formKey.currentState!.validate()) {
                                              controller.submitKycData();
                                            }
                                          },
                                          text: MyStrings.submit.tr,
                                        ),
                                        spaceDown(Dimensions.space15),
                                      ],
                                    ),
                                  ),
                                ),
            ),
          ),
        );
      },
    );
  }
}
