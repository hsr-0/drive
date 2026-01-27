import 'package:ovoride_driver/data/model/global/user/global_driver_model.dart';

class ProfileResponseModel {
  ProfileResponseModel({
    String? remark,
    String? status,
    List<String>? message,
    Data? data,
  }) {
    _remark = remark;
    _status = status;
    _message = message;
    _data = data;
  }

  ProfileResponseModel.fromJson(dynamic json) {
    _remark = json['remark'];
    _status = json['status'];
    _message = json["message"] == null ? [] : List<String>.from(json["message"]!.map((x) => x));
    _data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  String? _remark;
  String? _status;
  List<String>? _message;
  Data? _data;

  String? get remark => _remark;
  String? get status => _status;
  List<String>? get message => _message;
  Data? get data => _data;
}

class Data {
  Data({GlobalDriverInfoModel? driver, String? driverImagePath}) {
    _driver = driver;
    _driverImagePath = driverImagePath;
  }

  Data.fromJson(dynamic json) {
    _driver = json['driver'] != null ? GlobalDriverInfoModel.fromJson(json['driver']) : null;
    _driverImagePath = json["driver_image_path"]?.toString();
  }
  GlobalDriverInfoModel? _driver;
  String? _driverImagePath;

  GlobalDriverInfoModel? get driver => _driver;
  String? get driverImagePath => _driverImagePath;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (_driver != null) {
      map['driver'] = _driver?.toJson();
    }
    return map;
  }
}
