import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/presentation/components/shimmer/faq_shimmer.dart';

import '../../../core/utils/dimensions.dart';
import '../../../core/utils/my_color.dart';
import '../../../core/utils/my_strings.dart';
import '../../../data/controller/faq_controller/faq_controller.dart';
import '../../../data/repo/faq_repo/faq_repo.dart';
import '../../components/app-bar/custom_appbar.dart';
import 'faq_widget.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  @override
  void initState() {
    Get.put(FaqRepo(apiClient: Get.find()));
    final controller = Get.put(FaqController(faqRepo: Get.find()));
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controller.loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColor.getScreenBgColor(),
      appBar: CustomAppBar(isShowBackBtn: true, title: MyStrings.faq.tr),
      body: GetBuilder<FaqController>(
        builder: (controller) => controller.isLoading
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListView.builder(
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    return FaqCardShimmer();
                  },
                ),
              )
            : SingleChildScrollView(
                padding: Dimensions.screenPadding,
                physics: const BouncingScrollPhysics(),
                child: ListView.separated(
                  shrinkWrap: true,
                  scrollDirection: Axis.vertical,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.faqList.length,
                  separatorBuilder: (context, index) => const SizedBox(height: Dimensions.space10),
                  itemBuilder: (context, index) => FaqListItem(
                    answer: (controller.faqList[index].dataValues?.answer ?? '').tr,
                    question: (controller.faqList[index].dataValues?.question ?? '').tr,
                    index: index,
                    press: () {
                      controller.changeSelectedIndex(index);
                    },
                    selectedIndex: controller.selectedIndex,
                  ),
                ),
              ),
      ),
    );
  }
}
