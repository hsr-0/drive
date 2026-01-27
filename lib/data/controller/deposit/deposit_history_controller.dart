import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/route/route.dart';
import '../../../core/utils/my_color.dart';
import '../../../core/utils/my_strings.dart';
import '../../../presentation/components/snack_bar/show_custom_snackbar.dart';
import '../../model/deposit/deposit_history_response_model.dart';
import '../../model/global/response_model/response_model.dart';
import '../../repo/deposit/deposit_repo.dart';

class DepositController extends GetxController {
  DepositRepo depositRepo;
  DepositController({required this.depositRepo});
  bool isLoading = false;

  String currency = '';
  String curSymbol = '';
  List<DepositHistoryListModel> depositList = [];
  String? nextPageUrl = '';
  String trx = '';

  int page = 1;
  Future<void> beforeInitLoadData() async {
    currency = depositRepo.apiClient.getCurrency();
    curSymbol = depositRepo.apiClient.getCurrency(isSymbol: true);
    isLoading = true;

    update();
    page = 1;
    depositList.clear();

    ResponseModel response = await depositRepo.getDepositHistory(page: page);

    if (response.statusCode == 200) {
      DepositHistoryResponseModel model = DepositHistoryResponseModel.fromJson(
        (response.responseJson),
      );
      if (model.status?.toLowerCase() == 'success') {
        List<DepositHistoryListModel>? tempDepositList = model.data?.deposits?.data;
        nextPageUrl = model.data?.deposits?.nextPageUrl ?? '';
        if (tempDepositList != null && !(tempDepositList == [])) {
          depositList.addAll(tempDepositList);
        }
      } else {
        CustomSnackBar.error(
          errorList: model.message ?? [MyStrings.somethingWentWrong],
        );
      }
    } else {
      CustomSnackBar.error(errorList: [response.message]);
    }
    isLoading = false;
    update();
  }

  int totalPage = 0;
  void fetchNewList() async {
    page = page + 1;
    trx = searchController.text;
    ResponseModel response = await depositRepo.getDepositHistory(
      page: page,
      searchText: trx,
    );
    if (response.statusCode == 200) {
      DepositHistoryResponseModel model = DepositHistoryResponseModel.fromJson(
        (response.responseJson),
      );
      if (model.status?.toLowerCase() == 'success') {
        List<DepositHistoryListModel>? tempDepositList = model.data?.deposits?.data;
        nextPageUrl = model.data?.deposits?.nextPageUrl ?? '';
        if (tempDepositList != null && !(tempDepositList == [])) {
          depositList.addAll(tempDepositList);
        }
      } else {
        CustomSnackBar.error(
          errorList: model.message ?? [MyStrings.somethingWentWrong],
        );
      }
    } else {
      CustomSnackBar.error(errorList: [response.message]);
    }

    update();
  }

  bool searchLoading = false;
  TextEditingController searchController = TextEditingController();
  void searchDepositTrx() async {
    trx = searchController.text;
    page = 1;
    searchLoading = true;
    update();
    depositList.clear();

    ResponseModel response = await depositRepo.getDepositHistory(
      page: page,
      searchText: trx,
    );
    if (response.statusCode == 200) {
      DepositHistoryResponseModel model = DepositHistoryResponseModel.fromJson(
        (response.responseJson),
      );
      if (model.status?.toLowerCase() == 'success') {
        List<DepositHistoryListModel>? tempDepositList = model.data?.deposits?.data;
        nextPageUrl = model.data?.deposits?.nextPageUrl ?? '';
        if (tempDepositList != null && !(tempDepositList == [])) {
          depositList.addAll(tempDepositList);
        }
      } else {
        CustomSnackBar.error(
          errorList: model.message ?? [MyStrings.somethingWentWrong],
        );
      }
    } else {
      CustomSnackBar.error(errorList: [response.message]);
    }

    page = 1;
    searchLoading = false;
    update();
  }

  bool hasNext() {
    if (nextPageUrl != null && nextPageUrl!.isNotEmpty) {
      return true;
    } else {
      return false;
    }
  }

  void clearFilter() {
    searchController.text = '';
    trx = '';
    beforeInitLoadData();
  }

  int expandedIndex = -1;
  void changeExpandedIndex(int index) {
    if (expandedIndex == index) {
      expandedIndex = -1;
    } else {
      expandedIndex = index;
    }
    update();
  }

  bool isSearch = false;
  void changeIsPress() {
    isSearch = !isSearch;
    if (!isSearch) {
      searchController.text = '';
      clearFilter();
    }
    update();
  }

  String getStatus(int index) {
    String status = depositList[index].status ?? '';
    String methodCode = depositList[index].methodCode ?? '1';
    if (status == '1') {
      double code = double.tryParse(methodCode) ?? 1;
      return code >= 1000 ? MyStrings.approved : MyStrings.succeed;
    } else {
      return status == '2'
          ? MyStrings.pending
          : status == '3'
              ? MyStrings.rejected
              : MyStrings.initiated;
    }
  }

  Color getStatusColor(int index) {
    String status = depositList[index].status ?? '';
    String methodCode = depositList[index].methodCode ?? '1';

    if (status == '1') {
      double code = double.tryParse(methodCode) ?? 1;
      return code >= 1000 ? MyColor.highPriorityPurpleColor : MyColor.greenSuccessColor;
    } else {
      return status == '2'
          ? MyColor.pendingColor
          : status == '3'
              ? MyColor.redCancelTextColor
              : MyColor.colorGrey;
    }
  }

  bool isGoHome() {
    String previousRoute = Get.previousRoute;

    if (previousRoute == RouteHelper.notificationScreen) {
      return false;
    } else {
      return true;
    }
  }
}
