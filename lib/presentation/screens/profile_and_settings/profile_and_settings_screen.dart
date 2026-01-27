import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/data/controller/account/profile_controller.dart';
import 'package:ovoride_driver/data/repo/account/profile_repo.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/shimmer/user_shimmer.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';
import 'package:ovoride_driver/presentation/screens/dashboard/dashboard_background.dart';
import 'package:ovoride_driver/presentation/screens/profile_and_settings/widgets/delete_account_bottom_sheet.dart';
import 'package:ovoride_driver/presentation/screens/profile_and_settings/widgets/profile_and_settings_app_bar.dart';
import '../../../core/route/route.dart';
import '../../../core/utils/dimensions.dart';
import '../../../core/utils/my_color.dart';
import '../../../core/utils/my_strings.dart';
import '../../../core/utils/style.dart';
import '../../../core/utils/util.dart';
import '../../components/bottom-sheet/custom_bottom_sheet.dart';
import '../../components/divider/custom_divider.dart';
import '../../components/image/my_network_image_widget.dart';
import 'widgets/account_user_card.dart';
import 'widgets/menu_row_widget.dart';

class ProfileAndSettingsScreen extends StatefulWidget {
  const ProfileAndSettingsScreen({super.key});

  @override
  State<ProfileAndSettingsScreen> createState() => _ProfileAndSettingsScreenState();
}

class _ProfileAndSettingsScreenState extends State<ProfileAndSettingsScreen> {
  double appBarSize = 90.0;
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
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ProfileController>(
      builder: (controller) {
        return DashboardBackground(
          child: Scaffold(
            extendBody: true,
            backgroundColor: MyColor.transparentColor,
            extendBodyBehindAppBar: false,
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(appBarSize),
              child: ProfileAndSettingsScreenAppBar(controller: controller),
            ),
            body: RefreshIndicator(
              color: MyColor.getPrimaryColor(),
              onRefresh: () async {
                controller.loadProfileInfo();
              },
              child: SingleChildScrollView(
                padding: Dimensions.screenPaddingHV,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    controller.isLoading
                        ? const UserShimmer()
                        : AccountUserBalanceCard(
                            balance: "${controller.profileRepo.apiClient.getCurrency(isSymbol: true)}${StringConverter.formatNumber(controller.driver.balance ?? '0')}",
                          ),
                    spaceDown(Dimensions.space20),
                    HeaderText(
                      text: MyStrings.account.tr.toUpperCase(),
                      style: boldDefault.copyWith(
                        color: MyColor.bodyMutedTextColor,
                      ),
                    ),
                    spaceDown(Dimensions.space10),
                    Container(
                      padding: const EdgeInsets.all(Dimensions.space15),
                      decoration: BoxDecoration(
                        color: MyColor.getCardBgColor(),
                        borderRadius: BorderRadius.circular(Dimensions.space12),
                        boxShadow: MyUtils.getCardShadow(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          MenuRowWidget(
                            image: MyIcons.profile,
                            label: MyStrings.profile,
                            onPressed: () => Get.toNamed(RouteHelper.profileScreen),
                          ),
                          const CustomDivider(space: Dimensions.space15),
                          MenuRowWidget(
                            image: MyIcons.review,
                            label: MyStrings.review,
                            onPressed: () => Get.toNamed(
                              RouteHelper.myReviewScreen,
                              arguments: '${controller.driver.avgRating}',
                            ),
                          ),
                          const CustomDivider(space: Dimensions.space15),
                          MenuRowWidget(
                            image: MyIcons.deposit,
                            label: MyStrings.deposit,
                            onPressed: () => Get.toNamed(RouteHelper.newDepositScreenScreen),
                          ),
                          const CustomDivider(space: Dimensions.space15),
                          MenuRowWidget(
                            image: MyIcons.passwordChange,
                            label: MyStrings.changePassword,
                            onPressed: () => Get.toNamed(RouteHelper.changePasswordScreen),
                          ),
                          const CustomDivider(space: Dimensions.space15),
                          MenuRowWidget(
                            image: MyIcons.twoFaIcon,
                            label: MyStrings.twoFactorAuth,
                            onPressed: () => Get.toNamed(RouteHelper.twoFactorSetupScreen),
                          ),
                          spaceDown(Dimensions.space10),
                        ],
                      ),
                    ),
                    spaceDown(Dimensions.space15),
                    HeaderText(
                      text: MyStrings.ridesHistory.tr.toUpperCase(),
                      style: boldDefault.copyWith(
                        color: MyColor.bodyMutedTextColor,
                      ),
                    ),
                    spaceDown(Dimensions.space10),
                    Container(
                      padding: const EdgeInsets.all(Dimensions.space15),
                      decoration: BoxDecoration(
                        color: MyColor.getCardBgColor(),
                        borderRadius: BorderRadius.circular(Dimensions.space12),
                        boxShadow: MyUtils.getCardShadow(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          MenuRowWidget(
                            image: MyIcons.city,
                            label: MyStrings.city,
                            onPressed: () => Get.toNamed(
                              RouteHelper.rideActivityScreen,
                              arguments: 1,
                            ),
                          ),
                          const CustomDivider(space: Dimensions.space15),
                          MenuRowWidget(
                            image: MyIcons.intercity,
                            label: MyStrings.interCity,
                            onPressed: () => Get.toNamed(
                              RouteHelper.rideActivityScreen,
                              arguments: 2,
                            ),
                          ),
                          spaceDown(Dimensions.space10),
                        ],
                      ),
                    ),
                    spaceDown(Dimensions.space15),
                    HeaderText(
                      text: MyStrings.history.tr.toUpperCase(),
                      style: boldDefault.copyWith(
                        color: MyColor.bodyMutedTextColor,
                      ),
                    ),
                    spaceDown(Dimensions.space10),
                    Container(
                      padding: const EdgeInsets.all(Dimensions.space15),
                      decoration: BoxDecoration(
                        color: MyColor.getCardBgColor(),
                        borderRadius: BorderRadius.circular(Dimensions.space12),
                        boxShadow: MyUtils.getCardShadow(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          MenuRowWidget(
                            image: MyIcons.payment,
                            label: MyStrings.paymentHistory,
                            onPressed: () => Get.toNamed(RouteHelper.paymentHistoryScreen),
                          ),
                          const CustomDivider(space: Dimensions.space15),
                          MenuRowWidget(
                            image: MyIcons.depositHistory,
                            label: MyStrings.depositHistory,
                            onPressed: () => Get.toNamed(RouteHelper.depositsScreen),
                          ),
                          const CustomDivider(space: Dimensions.space15),
                          MenuRowWidget(
                            image: MyIcons.withdrawHistory,
                            label: MyStrings.withdrawHistory,
                            onPressed: () => Get.toNamed(RouteHelper.withdrawScreen),
                          ),
                          const CustomDivider(space: Dimensions.space15),
                          MenuRowWidget(
                            image: MyIcons.transactionHistory,
                            label: MyStrings.transactionHistory,
                            onPressed: () => Get.toNamed(
                              RouteHelper.transactionHistoryScreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    spaceDown(Dimensions.space15),
                    HeaderText(
                      text: MyStrings.settingsAndSupport.tr.toUpperCase(),
                      style: boldDefault.copyWith(
                        color: MyColor.bodyMutedTextColor,
                      ),
                    ),
                    spaceDown(Dimensions.space10),
                    Container(
                      padding: const EdgeInsets.all(Dimensions.space15),
                      decoration: BoxDecoration(
                        color: MyColor.getCardBgColor(),
                        borderRadius: BorderRadius.circular(Dimensions.space12),
                        boxShadow: MyUtils.getShadow(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          if (controller.profileRepo.apiClient.isMultiLanguageEnabled()) ...[
                            MenuRowWidget(
                              image: MyIcons.language,
                              label: MyStrings.language,
                              onPressed: () => Get.toNamed(RouteHelper.languageScreen),
                            ),
                            const CustomDivider(space: Dimensions.space15),
                          ],
                          MenuRowWidget(
                            image: MyIcons.support,
                            label: MyStrings.supportTicket,
                            onPressed: () => Get.toNamed(RouteHelper.supportTicketScreen),
                          ),
                          const CustomDivider(space: Dimensions.space15),
                          MenuRowWidget(
                            image: controller.profileRepo.apiClient.isNotificationAudioEnable() ? MyIcons.volume : MyIcons.volumeMute,
                            label: MyStrings.audioNotification,
                            onPressed: () {},
                            endWidget: Switch(
                              activeTrackColor: MyColor.greenSuccessColor,
                              activeThumbColor: MyColor.colorWhite,
                              inactiveTrackColor: MyColor.redCancelTextColor,
                              inactiveThumbColor: MyColor.colorWhite,
                              trackOutlineColor: WidgetStateProperty.all(
                                MyColor.colorWhite,
                              ),
                              value: controller.profileRepo.apiClient.isNotificationAudioEnable(),
                              onChanged: (value) {
                                controller.profileRepo.apiClient.storeNotificationAudioEnable(value);
                                controller.update();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    spaceDown(Dimensions.space15),
                    HeaderText(
                      text: MyStrings.more.tr.toUpperCase(),
                      style: boldDefault.copyWith(
                        color: MyColor.bodyMutedTextColor,
                      ),
                    ),
                    spaceDown(Dimensions.space10),
                    Container(
                      padding: const EdgeInsets.all(Dimensions.space15),
                      decoration: BoxDecoration(
                        color: MyColor.getCardBgColor(),
                        borderRadius: BorderRadius.circular(Dimensions.space12),
                        boxShadow: MyUtils.getShadow(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          MenuRowWidget(
                            image: MyIcons.policy,
                            label: MyStrings.policies,
                            onPressed: () => Get.toNamed(RouteHelper.privacyScreen),
                          ),
                          const CustomDivider(space: Dimensions.space15),
                          MenuRowWidget(
                            image: MyIcons.infoIcon,
                            label: MyStrings.faq,
                            onPressed: () => Get.toNamed(RouteHelper.faqScreen),
                          ),
                          const CustomDivider(space: Dimensions.space15),
                          MenuRowWidget(
                            image: MyIcons.rateApp,
                            label: MyStrings.rateUs.tr,
                            onPressed: () async {
                              if (await controller.inAppReview.isAvailable()) {
                                controller.inAppReview.requestReview();
                              } else {
                                CustomSnackBar.error(
                                  errorList: [
                                    MyStrings.pleaseUploadYourAppOnPlayStore,
                                  ],
                                );
                              }
                            },
                          ),
                          const CustomDivider(space: Dimensions.space15),
                          MenuRowWidget(
                            image: MyIcons.deleteAccount,
                            label: controller.isDeleteBtnLoading ? "${MyStrings.loading}..." : MyStrings.deleteAccount,
                            onPressed: () {
                              CustomBottomSheet(
                                bgColor: MyColor.getScreenBgColor(),
                                child: DeleteAccountBottomSheetBody(
                                  controller: controller,
                                ),
                              ).customBottomSheet(context);
                            },
                          ),
                        ],
                      ),
                    ),
                    spaceDown(Dimensions.space20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.space15,
                        vertical: Dimensions.space15,
                      ),
                      decoration: BoxDecoration(
                        color: MyColor.redCancelTextColor.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(Dimensions.space12),
                        boxShadow: MyUtils.getShadow(),
                      ),
                      child: MenuRowWidget(
                        image: MyIcons.logout,
                        imgColor: MyColor.redCancelTextColor,
                        textColor: MyColor.redCancelTextColor,
                        label: controller.logoutLoading ? '${MyStrings.loggingOut}...' : MyStrings.logout,
                        textStyle: regularLarge.copyWith(
                          color: MyColor.redCancelTextColor,
                          fontSize: Dimensions.space20,
                        ),
                        onPressed: () {
                          if (controller.logoutLoading == false) {
                            controller.logout();
                          }
                        },
                        endWidget: MyImageWidget(
                          width: Dimensions.space30,
                          height: Dimensions.space30,
                          imageUrl: controller.imageUrl,
                          boxFit: BoxFit.cover,
                          isProfile: true,
                          radius: 100,
                        ),
                      ),
                    ),
                    spaceDown(Dimensions.space50 * 2),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
