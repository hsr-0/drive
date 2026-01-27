import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:ovoride_driver/environment.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../../core/utils/my_color.dart';
import '../../../core/utils/my_strings.dart';
import '../../../core/utils/style.dart';
import '../snack_bar/show_custom_snackbar.dart';

class DownloadingDialog extends StatefulWidget {
  final String url;
  final String fileName;

  const DownloadingDialog({
    super.key,
    required this.url,
    required this.fileName,
  });

  @override
  DownloadingDialogState createState() => DownloadingDialogState();
}

class DownloadingDialogState extends State<DownloadingDialog> {
  int _total = 0, _received = 0;
  bool _isImage = false;

  bool _detectIfImage(String url) {
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    String extension = url.split('.').last.toLowerCase();
    return imageExtensions.contains(extension);
  }

  String _getTimestamp() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  String _getFileExtension(String url) {
    final extension = url.split('.').last;
    return extension.contains('/') ? 'png' : extension;
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    } else {
      return await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }
  }

  Future<void> _downloadFile() async {
    try {
      Dio dio = Dio();
      String fileExtension = _getFileExtension(widget.url);
      String dynamicFileName = '${widget.fileName}_${_getTimestamp()}.$fileExtension';
      Directory dir = await _getDownloadDirectory();
      String fullPath = '${dir.path}/$dynamicFileName';

      await dio.download(
        widget.url,
        fullPath,
        onReceiveProgress: (received, total) {
          setState(() {
            _received = received;
            _total = total;
          });
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      Get.back();
      CustomSnackBar.success(
        successList: ['${MyStrings.fileDownloadedSuccess}: $fullPath'],
      );
      setState(() {});
    } catch (e) {
      Get.back();
      CustomSnackBar.error(errorList: [MyStrings.requestFail]);
    }
  }

  Future<void> _saveImage() async {
    try {
      Dio dio = Dio();
      final response = await dio.get<List<int>>(
        widget.url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {"dev-token": Environment.devToken},
        ),
      );

      if (response.statusCode == 200) {
        String fileExtension = _getFileExtension(widget.url);
        String dynamicFileName = '${widget.fileName}_${_getTimestamp()}.$fileExtension';

        final result = await ImageGallerySaverPlus.saveImage(
          Uint8List.fromList(response.data!),
          quality: 60,
          name: dynamicFileName,
        );

        dynamic value = result['isSuccess'];
        if (value.toString() == 'true') {
          Get.back();
          CustomSnackBar.success(
            successList: [(MyStrings.fileDownloadedSuccess)],
          );
        } else {
          Get.back();
          CustomSnackBar.error(
            errorList: [result['errorMessage'] ?? MyStrings.requestFail],
          );
        }
      } else {
        Get.back();
        CustomSnackBar.error(errorList: [MyStrings.requestFail]);
      }
    } catch (e) {
      Get.back();
      CustomSnackBar.error(errorList: [MyStrings.requestFail]);
    }
  }

  @override
  void initState() {
    super.initState();
    _isImage = _detectIfImage(widget.url);
    if (_isImage) {
      _saveImage();
    } else {
      _downloadFile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: MyColor.getCardBgColor(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(
            child: Padding(
              padding: EdgeInsets.all(10),
              child: SpinKitThreeBounce(
                color: MyColor.primaryColor,
                size: 20.0,
              ),
            ),
          ),
          Visibility(
            visible: !_isImage,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  '${MyStrings.downloading.tr} ${_received ~/ 1024}/${_total ~/ 1024} ${'KB'.tr}',
                  style: regularDefault,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
