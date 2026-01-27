import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/data/controller/account/change_password_controller.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/image/custom_svg_picture.dart';
import 'package:ovoride_driver/presentation/components/text-form-field/custom_text_field.dart';

class ChangePasswordForm extends StatefulWidget {
  const ChangePasswordForm({super.key});

  @override
  State<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<ChangePasswordForm> {
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ChangePasswordController>(
      builder: (controller) => Form(
        key: formKey,
        child: Column(
          children: [
            CustomTextField(
              hintText: MyStrings.currentPassword.tr,
              prefixIcon: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: Dimensions.space12,
                  end: Dimensions.space8,
                ),
                child: CustomSvgPicture(
                  image: MyIcons.password,
                  color: MyColor.primaryColor,
                  height: Dimensions.space30,
                ),
              ),
              onChanged: (value) {
                return;
              },
              validator: (value) {
                if (value.toString().isEmpty) {
                  return MyStrings.enterCurrentPass.tr;
                } else {
                  return null;
                }
              },
              controller: controller.currentPassController,
              isShowSuffixIcon: true,
              isPassword: true,
            ),
            const SizedBox(height: Dimensions.space20),
            CustomTextField(
              hintText: MyStrings.newPassword.tr,
              prefixIcon: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: Dimensions.space12,
                  end: Dimensions.space8,
                ),
                child: CustomSvgPicture(
                  image: MyIcons.password,
                  color: MyColor.primaryColor,
                  height: Dimensions.space30,
                ),
              ),
              onChanged: (value) {
                return;
              },
              validator: (value) {
                if (value.toString().isEmpty) {
                  return MyStrings.enterNewPass.tr;
                } else {
                  return null;
                }
              },
              controller: controller.passController,
              isShowSuffixIcon: true,
              isPassword: true,
            ),
            const SizedBox(height: Dimensions.space20),
            CustomTextField(
              hintText: MyStrings.confirmPassword.tr,
              prefixIcon: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: Dimensions.space12,
                  end: Dimensions.space8,
                ),
                child: CustomSvgPicture(
                  image: MyIcons.password,
                  color: MyColor.primaryColor,
                  height: Dimensions.space30,
                ),
              ),
              onChanged: (value) {
                return;
              },
              validator: (value) {
                if (controller.confirmPassController.text != controller.passController.text) {
                  return MyStrings.kMatchPassError.tr;
                } else {
                  return null;
                }
              },
              controller: controller.confirmPassController,
              isShowSuffixIcon: true,
              isPassword: true,
            ),
            const SizedBox(height: Dimensions.space25),
            RoundedButton(
              isLoading: controller.submitLoading,
              text: MyStrings.submit,
              press: () {
                if (formKey.currentState!.validate()) {
                  controller.changePassword();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
