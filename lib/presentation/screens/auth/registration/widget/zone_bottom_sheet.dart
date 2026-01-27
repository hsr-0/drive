import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/debouncer.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/account/profile_complete_controller.dart';
import 'package:ovoride_driver/presentation/components/bottom-sheet/bottom_sheet_header_row.dart';
import 'package:ovoride_driver/presentation/components/bottom-sheet/custom_bottom_sheet.dart';
import 'package:ovoride_driver/presentation/components/custom_loader/custom_loader.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/no_data.dart';

class ZoneBottomSheet {
  static void bottomSheet(
    BuildContext context,
    ProfileCompleteController controller,
  ) {
    final ScrollController scrollController = ScrollController();

    // 🔹 Listen for scroll end to trigger pagination
    scrollController.addListener(() {
      if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
        if (controller.hasNext()) {
          controller.getZoneData();
        }
      }
    });
    final MyDebouncer deBouncer = MyDebouncer(
      delay: const Duration(milliseconds: 600),
    );
    CustomBottomSheet(
      child: GetBuilder<ProfileCompleteController>(initState: (state) {
        WidgetsBinding.instance.addPostFrameCallback((v) {
          controller.initZoneData(shouldLoad: true);
        });
      }, builder: (controller) {
        return Container(
          height: MediaQuery.of(context).size.height * .9,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          decoration: BoxDecoration(
            color: MyColor.getCardBgColor(),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BottomSheetHeaderRow(
                header: MyStrings.selectYourZone,
                bottomSpace: 15,
              ),
              TextField(
                controller: controller.searchZoneController,
                onChanged: (v) {
                  deBouncer.run(() {
                    controller.initZoneData(shouldLoad: false);
                  });
                },
                decoration: InputDecoration(
                  hintStyle: regularDefault.copyWith(),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.grey,
                    size: 20, // smaller icon
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12), // ✅ centers text & icon
                  hintText: MyStrings.searchYourZone,

                  border: const UnderlineInputBorder(
                    borderSide: BorderSide(color: MyColor.borderColor),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: MyColor.primaryColor),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: MyColor.borderColor),
                  ),
                ),
                cursorColor: MyColor.getPrimaryColor(),
              ),
              const SizedBox(height: 15),
              Flexible(
                child: controller.zoneLoading
                    ? CustomLoader(
                        isFullScreen: true,
                      )
                    : (controller.zoneLoading == false && controller.zoneList.isEmpty)
                        ? NoDataWidget(
                            text: MyStrings.noZoneFound.tr,
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: controller.zoneList.length + 1,
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              if (controller.zoneList.length == index) {
                                return controller.hasNext()
                                    ? Container(
                                        height: 40,
                                        width: MediaQuery.of(
                                          context,
                                        ).size.width,
                                        margin: const EdgeInsets.all(5),
                                        child: const CustomLoader(),
                                      )
                                    : const SizedBox();
                              }
                              var zoneItem = controller.zoneList[index];
                              var isLastIndex = index == controller.zoneList.length - 1;
                              return GestureDetector(
                                onTap: () {
                                  controller.selectZone(zoneItem);
                                  Navigator.pop(context);
                                  FocusScopeNode currentFocus = FocusScope.of(context);
                                  if (!currentFocus.hasPrimaryFocus) {
                                    currentFocus.unfocus();
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.all(Dimensions.space10),
                                  decoration: BoxDecoration(
                                    color: MyColor.transparentColor,
                                    border: !isLastIndex
                                        ? Border(
                                            bottom: BorderSide(
                                              color: MyColor.borderColor,
                                              width: 0.5,
                                            ),
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.location,
                                        color: MyColor.getPrimaryColor().withValues(alpha: 0.5),
                                      ),
                                      spaceSide(Dimensions.space10),
                                      Text(
                                        '${zoneItem.name}',
                                        style: boldDefault.copyWith(
                                          color: MyColor.getHeadingTextColor(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      }),
    ).customBottomSheet(context);
  }
}
