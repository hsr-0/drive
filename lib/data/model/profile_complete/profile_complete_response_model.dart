import 'package:ovoride_driver/data/model/global/user/global_driver_model.dart';

class ProfileCompleteResponseModel {
  ProfileCompleteResponseModel({
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

  ProfileCompleteResponseModel.fromJson(dynamic json) {
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

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['remark'] = _remark;
    map['status'] = _status;
    if (_message != null) {
      map['message'] = message == null ? [] : List<dynamic>.from(message!.map((x) => x));
    }
    if (_data != null) {
      map['data'] = _data?.toJson();
    }
    return map;
  }
}

class Data {
  Data({GlobalDriverInfoModel? user}) {
    _user = user;
  }

  Data.fromJson(dynamic json) {
    _user = json['driver'] != null ? GlobalDriverInfoModel.fromJson(json['driver']) : null;
  }
  GlobalDriverInfoModel? _user;

  GlobalDriverInfoModel? get user => _user;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (_user != null) {
      map['driver'] = _user?.toJson();
    }
    return map;
  }
}
