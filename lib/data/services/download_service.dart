import 'dart:io';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:ovoride_driver/core/helper/shared_preference_helper.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/data/services/api_client.dart';
import 'package:ovoride_driver/environment.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  static String? extractFileExtension(String value) {
    RegExp regExp = RegExp(r'\.([a-zA-Z0-9]+)$');
    Match? match = regExp.firstMatch(value);
    return match?.group(1);
  }

  static Future<bool> downloadPDF({
    required String url,
    required String fileName,
  }) async {
    printX("Download PDF Service call $url");
    String accessToken = Get.find<ApiClient>().sharedPreferences.getString(
              SharedPreferenceHelper.accessTokenKey,
            ) ??
        "";
    Dio dio = Dio();

    Directory directory;

    // ✅ Detect platform and use correct directory
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      throw UnsupportedError("Unsupported platform");
    }

    String filePath = "${directory.path}/$fileName";

    try {
      await dio.download(
        url,
        filePath,
        options: Options(
          headers: {
            "Authorization": "Bearer $accessToken",
            "dev-token": Environment.devToken,
            "Accept": "application/pdf",
          },
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            printX(
              "Download Progress: \${(received / total * 100).toStringAsFixed(2)}%",
            );
          }
        },
      );
      printX('✅ PDF downloaded successfully: \$filePath');
      CustomSnackBar.success(successList: [MyStrings.fileDownloadedSuccess]);
      openDownloadedFile(filePath);

      return true;
    } catch (e) {
      printX('❌ Download failed: $e');
      CustomSnackBar.error(errorList: ["Download failed. Please try again."]);
      return false;
    }
  }

  static Future<void> openDownloadedFile(String filePath) async {
    try {
      await OpenFile.open(filePath);
    } catch (e) {
      printX("ERROR: ${e.toString()}");
    }
  }
}
