import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/data/model/kyc/kyc_response_model.dart';

import '../../../core/route/route.dart';
import '../../../core/utils/my_strings.dart';
import '../../../presentation/components/snack_bar/show_custom_snackbar.dart';
import '../../model/global/response_model/response_model.dart';
import '../../model/withdraw/withdraw_method_response_model.dart';
import '../../repo/withdraw/withdraw_repo.dart';

class AddNewWithdrawController extends GetxController {
  WithdrawRepo repo;
  AddNewWithdrawController({required this.repo});

  bool isLoading = true;
  String currency = '';
  String imagePath = '';

  List<WithdrawMethod> withdrawMethodList = [];
  TextEditingController amountController = TextEditingController();
  WithdrawMethod? withdrawMethod = WithdrawMethod();

  String withdrawLimit = '';
  String charge = '';
  String payableText = '';
  String conversionRate = '';
  String inLocal = '';

  List<String> authorizationList = [];
  String? selectedAuthorizationMode;

  void changeAuthorizationMode(String? value) {
    if (value != null) {
      selectedAuthorizationMode = value;
      update();
    }
  }

  double rate = 1;
  double mainAmount = 0;
  void setWithdrawMethod(WithdrawMethod? method) {
    withdrawMethod = method;
    withdrawLimit = '${MyStrings.depositLimit.tr}: ${StringConverter.formatNumber(method?.minLimit ?? '-1')} - ${StringConverter.formatNumber(method?.maxLimit?.toString() ?? '-1')} ${method?.currency}';
    charge = '${MyStrings.charge.tr}: ${StringConverter.formatNumber(method?.fixedCharge?.toString() ?? '0')} + ${StringConverter.formatNumber(method?.percentCharge?.toString() ?? '0')} %';
    update();

    String amt = amountController.text.toString();
    mainAmount = amt.isEmpty ? 0 : double.tryParse(amt) ?? 0;

    withdrawLimit = '${StringConverter.formatNumber(method?.minLimit?.toString() ?? '-1')} - ${StringConverter.formatNumber(method?.maxLimit?.toString() ?? '-1')} $currency';
    changeInfoWidgetValue(mainAmount);
    update();
  }

  void changeInfoWidgetValue(double amount) {
    mainAmount = amount;
    double percent = double.tryParse(withdrawMethod?.percentCharge ?? '0') ?? 0;
    double percentCharge = (amount * percent) / 100;
    double temCharge = double.tryParse(withdrawMethod?.fixedCharge ?? '0') ?? 0;
    double totalCharge = percentCharge + temCharge;
    double payable = amount - totalCharge;
    payableText = '$payable $currency';
    charge = '${StringConverter.formatNumber('$totalCharge')} $currency';

    rate = double.tryParse(withdrawMethod?.rate ?? '0') ?? 0;
    conversionRate = '1 $currency = $rate ${withdrawMethod?.currency ?? ''}';
    inLocal = StringConverter.formatNumber('${payable * rate}');

    update();

    return;
  }

  Future<void> loadDepositMethod() async {
    currency = repo.apiClient.getCurrency();
    clearPreviousValue();
    WithdrawMethod method1 = WithdrawMethod(
      id: -1,
      name: MyStrings.selectOne,
      currency: "",
      minLimit: "0",
      maxLimit: "0",
      percentCharge: "",
      fixedCharge: "",
      rate: "",
    );
    withdrawMethodList.insert(0, method1);
    setWithdrawMethod(withdrawMethodList[0]);

    isLoading = true;
    update();

    ResponseModel responseModel = await repo.getAllWithdrawMethod();

    if (responseModel.statusCode == 200) {
      WithdrawMethodResponseModel model = WithdrawMethodResponseModel.fromJson(
        (responseModel.responseJson),
      );

      if (model.status == 'success') {
        List<WithdrawMethod>? tempMethodList = model.data?.withdrawMethod;
        imagePath = model.data?.imagePath ?? '';
        if (tempMethodList != null && tempMethodList.isNotEmpty) {
          withdrawMethodList.addAll(tempMethodList);
        }
      } else {
        CustomSnackBar.error(
          errorList: model.message ?? [MyStrings.somethingWentWrong],
        );
      }
    } else {
      CustomSnackBar.error(errorList: [responseModel.message]);
    }
    isLoading = false;
    update();
  }

  bool submitLoading = false;
  Future<void> submitWithdrawRequest() async {
    String amount = amountController.text;
    String id = withdrawMethod?.id.toString() ?? '-1';

    if (amount.isEmpty) {
      CustomSnackBar.error(
        errorList: [
          '${MyStrings.please} ${MyStrings.enterAmount.toLowerCase()}',
        ],
      );
      return;
    }

    if (id == '-1') {
      CustomSnackBar.error(
        errorList: [
          '${MyStrings.please} ${MyStrings.selectPaymentMethod.toLowerCase()}',
        ],
      );
      return;
    }

    if (authorizationList.length > 1 && selectedAuthorizationMode?.toLowerCase() == MyStrings.selectOne) {
      CustomSnackBar.error(errorList: [MyStrings.selectAuthModeMsg]);
      return;
    }

    double amount1 = 0;
    double maxAmount = 0;

    try {
      amount1 = double.parse(amount);
      maxAmount = double.parse(withdrawMethod?.maxLimit ?? '0');
    } catch (e) {
      return;
    }

    if (maxAmount == 0 || amount1 == 0) {
      List<String> errorList = [MyStrings.invalidAmount];
      CustomSnackBar.error(errorList: errorList);
      return;
    }

    submitLoading = true;
    update();

    ResponseModel response = await repo.addWithdrawRequest(
      withdrawMethod?.id ?? -1,
      amount1,
      selectedAuthorizationMode,
    );

    if (response.statusCode == 200) {
      DriverKycResponseModel model = DriverKycResponseModel.fromJson(
        (response.responseJson),
      );
      if (model.status == MyStrings.success) {
        Get.offAndToNamed(
          RouteHelper.withdrawConfirmScreenScreen,
          arguments: [model, withdrawMethod?.name],
        );
      } else {
        CustomSnackBar.error(
          errorList: model.message ?? [MyStrings.requestFail],
        );
      }
    } else {
      CustomSnackBar.error(errorList: [response.message]);
    }

    submitLoading = false;
    update();
  }

  bool isShowRate() {
    if (rate > 1 && currency.toLowerCase() != withdrawMethod?.currency?.toLowerCase()) {
      return true;
    } else {
      return false;
    }
  }

  void clearPreviousValue() {
    withdrawMethodList.clear();
    amountController.text = '';
    rate = 1;
    submitLoading = false;
    withdrawMethod = WithdrawMethod();
  }
}
