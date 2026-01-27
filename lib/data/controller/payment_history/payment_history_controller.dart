import 'package:get/get.dart';
import 'package:ovoride_driver/data/model/payment_history/payment_history_response_model.dart';
import 'package:ovoride_driver/data/repo/payment_history/payment_history_repo.dart';

import '../../../core/utils/my_strings.dart';
import '../../../presentation/components/snack_bar/show_custom_snackbar.dart';
import '../../model/global/response_model/response_model.dart';

class PaymentHistoryController extends GetxController {
  PaymentHistoryRepo paymentHistoryRepo;
  PaymentHistoryController({required this.paymentHistoryRepo});

  bool isLoading = true;
  int page = 0;
  String? nextPageUrl;

  List<PaymentHistoryModel> paymentHistoryList = [];

  Future<void> loadPaymentHistory({int? p}) async {
    page = p ?? page + 1;

    if (page == 1) {
      isLoading = true;
      paymentHistoryList.clear();
      update();
    }

    ResponseModel responseModel = await paymentHistoryRepo.getPaymentHistory(
      page.toString(),
    );

    if (responseModel.statusCode == 200) {
      PaymentHistoryResponseModel model = PaymentHistoryResponseModel.fromJson(
        (responseModel.responseJson),
      );

      nextPageUrl = model.data?.payments?.nextPageUrl;

      if (model.status.toString().toLowerCase() == MyStrings.success.toLowerCase()) {
        if (model.status == MyStrings.success) {
          nextPageUrl = model.data?.payments?.nextPageUrl;
          paymentHistoryList.addAll(model.data?.payments?.data ?? []);
          update();
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

  bool hasNext() {
    return nextPageUrl != null && nextPageUrl!.isNotEmpty && nextPageUrl != 'null' ? true : false;
  }
}
