import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/data/controller/localization/localization_controller.dart';
import 'package:ovoride_driver/data/controller/my_language_controller/my_language_controller.dart';
import 'package:ovoride_driver/data/repo/auth/general_setting_repo.dart';
import 'package:ovoride_driver/presentation/components/annotated_region/annotated_region_widget.dart';
import 'package:ovoride_driver/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/custom_loader/custom_loader.dart';
import 'package:ovoride_driver/presentation/components/no_data.dart';
import 'package:ovoride_driver/presentation/screens/language/widget/language_card.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String comeFrom = '';

  @override
  void initState() {
    Get.put(GeneralSettingRepo(apiClient: Get.find()));
    Get.put(LocalizationController(sharedPreferences: Get.find()));
    final controller = Get.put(
      MyLanguageController(
        repo: Get.find(),
        localizationController: Get.find(),
      ),
    );

    comeFrom = Get.arguments ?? '';

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controller.loadLanguage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MyLanguageController>(
      builder: (controller) => AnnotatedRegionWidget(
        child: Scaffold(
          backgroundColor: MyColor.getScreenBgColor(),
          appBar: CustomAppBar(
            isShowBackBtn: true,
            title: MyStrings.language.tr,
          ),
          body: controller.isLoading
              ? const CustomLoader()
              : controller.langList.isEmpty
                  ? const NoDataWidget()
                  : CustomAppCard(
                      margin: EdgeInsets.all(Dimensions.space16),
                      child: ListView.separated(
                        addAutomaticKeepAlives: true,
                        padding: EdgeInsets.zero,
                        scrollDirection: Axis.vertical,
                        itemCount: controller.langList.length,
                        separatorBuilder: (context, index) => Divider(color: MyColor.neutral100, height: 1),
                        itemBuilder: (context, index) => InkWell(
                          onTap: () {
                            controller.changeSelectedIndex(index);
                          },
                          child: LanguageCard(
                            index: index,
                            selectedIndex: controller.selectedIndex,
                            langName: controller.langList[index].languageName,
                            flag: '${controller.languageImagePath}/${controller.langList[index].imageUrl}',
                          ),
                        ),
                      ),
                    ),
          bottomNavigationBar: controller.langList.isEmpty
              ? SizedBox.shrink()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: Dimensions.space15,
                      ),
                      child: SizedBox(
                        height: 60,
                        child: RoundedButton(
                          text: MyStrings.confirm.tr,
                          isLoading: controller.isChangeLangLoading,
                          press: () {
                            controller.changeLanguage(controller.selectedIndex);
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
