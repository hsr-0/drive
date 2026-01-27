import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';

class GlobalKYCForm {
  GlobalKYCForm({List<GlobalFormModel>? list}) {
    _list = list;
  }

  List<GlobalFormModel>? _list = [];
  List<GlobalFormModel>? get list => _list;

  GlobalKYCForm.fromJson(dynamic json) {
    try {
      _list = [];

      if (json is List<dynamic>) {
        for (var e in json) {
          _list?.add(
            GlobalFormModel(
              e.value['name'],
              e.value['label'],
              e.value['instruction'],
              e.value['is_required'],
              e.value['extensions'],
              (e.value['options'] as List).map((e) => e as String).toList(),
              e.value['type'],
              '',
            ),
          );
        }
        _list;
      } else {
        var map = Map.from(json).map((k, v) => MapEntry<String, dynamic>(k, v));
        List<GlobalFormModel>? list = map.entries
            .map(
              (e) => GlobalFormModel(
                e.value['name'],
                e.value['label'],
                e.value['instruction'],
                e.value['is_required'],
                e.value['extensions'],
                (e.value['options'] as List).map((e) => e as String).toList(),
                e.value['type'],
                '',
              ),
            )
            .toList();
        if (list.isNotEmpty) {
          list.removeWhere((element) => element.toString().isEmpty);
          _list?.addAll(list);
        }
        _list;
      }
    } catch (e) {
      printX(e.toString());
    }
  }
}

class GlobalFormModel {
  String? name;
  String? label;
  String? instruction;
  String? isRequired;
  String? extensions;
  List<String>? options;
  String? type;
  dynamic selectedValue;
  File? imageFile;
  List<String>? cbSelected;
  TextEditingController? textEditingController;

  GlobalFormModel(
    this.name,
    this.label,
    this.instruction,
    this.isRequired,
    this.extensions,
    this.options,
    this.type,
    this.selectedValue, {
    this.cbSelected,
    this.imageFile,
  }) {
    textEditingController ??= TextEditingController();
  }
}
