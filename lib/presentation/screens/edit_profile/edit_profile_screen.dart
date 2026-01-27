import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/data/controller/account/profile_controller.dart';
import 'package:ovoride_driver/data/repo/account/profile_repo.dart';
import 'package:ovoride_driver/presentation/components/annotated_region/annotated_region_widget.dart';
import 'package:ovoride_driver/presentation/components/app-bar/custom_appbar.dart';
import '../../../core/utils/style.dart';
import '../../components/buttons/rounded_button.dart';
import '../../components/card/app_body_card.dart';
import '../../components/divider/custom_spacer.dart';
import '../../components/image/my_network_image_widget.dart';
import '../../components/text-form-field/custom_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  @override
  void initState() {
    Get.put(ProfileRepo(apiClient: Get.find()));
    final controller = Get.put(ProfileController(profileRepo: Get.find()));

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controller.loadProfileInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ProfileController>(
      builder: (controller) => AnnotatedRegionWidget(
        child: Scaffold(
          backgroundColor: MyColor.secondaryScreenBgColor,
          appBar: CustomAppBar(
            isShowBackBtn: true,
            title: MyStrings.editProfile.tr,
          ),
          body: SingleChildScrollView(
            padding: Dimensions.screenPaddingHV,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          top: Dimensions.space50,
                        ),
                        child: AppBodyWidgetCard(
                          child: Form(
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                spaceDown(Dimensions.space50 + 10),
                                CustomTextField(
                                  isRequired: true,
                                  controller: controller.firstNameController,
                                  labelText: MyStrings.firstName.tr,
                                  hintText: MyStrings.firstName,
                                  onChanged: (value) {},
                                  focusNode: controller.firstNameFocusNode,
                                  nextFocus: controller.lastNameFocusNode,
                                  textInputType: TextInputType.text,
                                  inputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return MyStrings.fieldErrorMsg.tr;
                                    } else {
                                      return null;
                                    }
                                  },
                                ),
                                spaceDown(Dimensions.space20),
                                CustomTextField(
                                  isRequired: true,
                                  controller: controller.lastNameController,
                                  labelText: MyStrings.lastName.tr,
                                  hintText: MyStrings.lastName,
                                  onChanged: (value) {},
                                  focusNode: controller.lastNameFocusNode,
                                  nextFocus: controller.addressFocusNode,
                                  textInputType: TextInputType.text,
                                  inputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return MyStrings.fieldErrorMsg.tr;
                                    } else {
                                      return null;
                                    }
                                  },
                                ),
                                spaceDown(Dimensions.space20),
                                CustomTextField(
                                  readOnly: true,
                                  fillColor: MyColor.colorGrey.withValues(
                                    alpha: 0.1,
                                  ),
                                  controller: controller.emailController,
                                  labelText: MyStrings.email.tr,
                                  hintText: MyStrings.email,
                                  onChanged: (value) {},
                                  focusNode: controller.emailFocusNode,
                                  textInputType: TextInputType.emailAddress,
                                  inputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return MyStrings.fieldErrorMsg.tr;
                                    } else {
                                      return null;
                                    }
                                  },
                                ),
                                spaceDown(Dimensions.space20),
                                CustomTextField(
                                  readOnly: true,
                                  fillColor: MyColor.colorGrey.withValues(
                                    alpha: 0.1,
                                  ),
                                  controller: controller.mobileNoController,
                                  labelText: MyStrings.phone.tr,
                                  hintText: MyStrings.phone,
                                  onChanged: (value) {},
                                  focusNode: controller.mobileNoFocusNode,
                                  textInputType: TextInputType.phone,
                                  inputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return MyStrings.fieldErrorMsg.tr;
                                    } else {
                                      return null;
                                    }
                                  },
                                ),
                                spaceDown(Dimensions.space20),
                                CustomTextField(
                                  controller: controller.addressController,
                                  labelText: MyStrings.address.tr,
                                  hintText: MyStrings.address,
                                  onChanged: (value) {},
                                  focusNode: controller.addressFocusNode,
                                  nextFocus: controller.cityFocusNode,
                                  textInputType: TextInputType.text,
                                  inputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return MyStrings.fieldErrorMsg.tr;
                                    } else {
                                      return null;
                                    }
                                  },
                                ),
                                spaceDown(Dimensions.space20),
                                CustomTextField(
                                  hintText: MyStrings.city,
                                  controller: controller.cityController,
                                  labelText: MyStrings.city.tr,
                                  onChanged: (value) {},
                                  focusNode: controller.cityFocusNode,
                                  nextFocus: controller.stateFocusNode,
                                  textInputType: TextInputType.text,
                                  inputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return MyStrings.fieldErrorMsg.tr;
                                    } else {
                                      return null;
                                    }
                                  },
                                ),
                                spaceDown(Dimensions.space20),
                                CustomTextField(
                                  controller: controller.stateController,
                                  labelText: MyStrings.state.tr,
                                  hintText: MyStrings.state,
                                  onChanged: (value) {},
                                  focusNode: controller.stateFocusNode,
                                  nextFocus: controller.zipCodeFocusNode,
                                  textInputType: TextInputType.text,
                                  inputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return MyStrings.fieldErrorMsg.tr;
                                    } else {
                                      return null;
                                    }
                                  },
                                ),
                                spaceDown(Dimensions.space20),
                                CustomTextField(
                                  controller: controller.zipCodeController,
                                  hintText: MyStrings.zipCode,
                                  labelText: MyStrings.zipCode.tr,
                                  onChanged: (value) {},
                                  focusNode: controller.zipCodeFocusNode,
                                  textInputType: TextInputType.text,
                                  inputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return MyStrings.fieldErrorMsg.tr;
                                    } else {
                                      return null;
                                    }
                                  },
                                ),
                                spaceDown(Dimensions.space40),
                                RoundedButton(
                                  text: MyStrings.updateProfile,
                                  textStyle: boldExtraLarge.copyWith(
                                    color: MyColor.colorWhite,
                                  ),
                                  press: () {
                                    if (controller.isSubmitLoading == false) {
                                      controller.updateProfile();
                                    }
                                  },
                                  isLoading: controller.isSubmitLoading,
                                  isOutlined: false,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        left: 0,
                        child: Align(
                          alignment: Alignment.center,
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: MyColor.screenBgColor,
                                    width: Dimensions.mediumRadius,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                height: Dimensions.space50 + 60,
                                width: Dimensions.space50 + 60,
                                child: ClipOval(
                                  child: controller.imageFile == null
                                      ? MyImageWidget(
                                          imageUrl: controller.imageUrl,
                                          boxFit: BoxFit.cover,
                                          height: Dimensions.space50 + 60,
                                          width: Dimensions.space50 + 60,
                                          isProfile: true,
                                        )
                                      : Image.file(
                                          controller.imageFile!,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Stack(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          controller.openGallery(context);
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: MyColor.simpleBg,
                                            border: Border.all(
                                              color: MyColor.colorWhite,
                                              width: Dimensions.space3,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          height: Dimensions.space40,
                                          width: Dimensions.space40,
                                          child: ClipOval(
                                            child: Icon(
                                              Icons.add_a_photo_outlined,
                                              size: Dimensions.space20,
                                              color: MyColor.getTextColor(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
