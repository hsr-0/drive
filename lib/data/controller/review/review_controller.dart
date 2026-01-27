import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/data/model/global/user/global_driver_model.dart';
import 'package:ovoride_driver/data/model/global/user/global_user_model.dart';
import 'package:ovoride_driver/data/model/review/review_history_response_model.dart';
import 'package:ovoride_driver/data/repo/review/review_repo.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';

class ReviewController extends GetxController {
  ReviewRepo repo;
  ReviewController({required this.repo});

  bool isLoading = true;
  List<Review> reviews = [];
  String userImagePath = "";
  String driverImagePath = "";
  GlobalDriverInfoModel? driver;
  GlobalUser? rider;

  Future<void> getReview() async {
    isLoading = true;
    update();
    try {
      final responseModel = await repo.getReviews();
      if (responseModel.statusCode == 200) {
        ReviewHistoryResponseModel model = ReviewHistoryResponseModel.fromJson(
          (responseModel.responseJson),
        );
        if (model.status == "success") {
          reviews.addAll(model.data?.reviews ?? []);
          userImagePath = "${UrlContainer.domainUrl}/${model.data?.userImagePath}";
          driverImagePath = "${UrlContainer.domainUrl}/${model.data?.driverImagePath}";
          rider = model.data?.rider;
          driver = model.data?.driver;
          printX(driverImagePath);
        } else {
          CustomSnackBar.error(
            errorList: model.message ?? [MyStrings.somethingWentWrong],
          );
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      CustomSnackBar.error(errorList: [MyStrings.somethingWentWrong]);
    } finally {
      isLoading = false;
      update();
    }
  }

  // get review by user id
  Future<void> getReviewByUserId(String userId) async {
    isLoading = true;
    update();
    try {
      final responseModel = await repo.getReviewByUserId(userId);
      if (responseModel.statusCode == 200) {
        ReviewHistoryResponseModel model = ReviewHistoryResponseModel.fromJson(
          (responseModel.responseJson),
        );
        if (model.status == "success") {
          reviews.addAll(model.data?.reviews ?? []);
          userImagePath = "${UrlContainer.domainUrl}/${model.data?.userImagePath}";
          driverImagePath = "${UrlContainer.domainUrl}/${model.data?.driverImagePath}";
          rider = model.data?.rider;
          driver = model.data?.driver;
          printX(driverImagePath);
        } else {
          CustomSnackBar.error(
            errorList: model.message ?? [MyStrings.somethingWentWrong],
          );
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      CustomSnackBar.error(errorList: [MyStrings.somethingWentWrong]);
    } finally {
      isLoading = false;
      update();
    }
  }

  //
  bool isVerified({
    bool isEmail = false,
    bool isMobile = false,
    bool isKYC = false,
  }) {
    if (rider?.id == null) {
      return false;
    }
    if (isEmail) {
      return rider?.ev == '1' ? true : false;
    }
    if (isMobile) {
      return rider?.sv == '1' ? true : false;
    }
    if (isKYC) {
      return rider?.kv == '1' ? true : false;
    }

    return false;
  }
}
