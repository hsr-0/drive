import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';
import 'package:ovoride_driver/data/model/support/support_ticket_response_model.dart';
import 'package:ovoride_driver/data/repo/support/support_repo.dart';
import 'package:get/get.dart';

import '../../../presentation/components/snack_bar/show_custom_snackbar.dart';

class SupportController extends GetxController {
  SupportRepo repo;
  SupportController({required this.repo});

  List<FileChooserModel> attachmentList = [
    FileChooserModel(fileName: MyStrings.noFileChosen),
  ];

  String noFileChosen = MyStrings.noFileChosen;
  String chooseFile = MyStrings.chooseFile;

  final TextEditingController replyController = TextEditingController();

  bool submitLoading = false;
  bool isLoading = false;

  int page = 0;
  String? nextPageUrl;
  List<TicketData> ticketList = [];
  String imagePath = '';
  Future<void> loadData({bool shouldLoad = true}) async {
    page = 0;
    isLoading = shouldLoad;
    update();
    await getSupportTicket(shouldLoad: shouldLoad);
    isLoading = false;
    update();
  }

  Future<void> getSupportTicket({bool shouldLoad = true}) async {
    page = page + 1;

    isLoading = shouldLoad;
    update();

    ResponseModel responseModel = await repo.getSupportTicketList(
      page.toString(),
    );
    if (responseModel.statusCode == 200) {
      SupportTicketListResponseModel model = SupportTicketListResponseModel.fromJson((responseModel.responseJson));
      if (model.status == MyStrings.success) {
        nextPageUrl = model.data?.tickets?.nextPageUrl;
        if (page == 1) {
          ticketList.clear();
          update();
        }
        List<TicketData>? tempList = model.data?.tickets?.data ?? [];
        imagePath = model.data?.tickets?.path.toString() ?? '';
        if (tempList.isNotEmpty) {
          ticketList.addAll(tempList);
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
    return nextPageUrl != null && nextPageUrl!.isNotEmpty ? true : false;
  }
}

class FileChooserModel {
  late String fileName;
  late File? choosenFile;
  FileChooserModel({required this.fileName, this.choosenFile});
}
