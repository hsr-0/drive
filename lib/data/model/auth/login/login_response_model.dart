import 'dart:convert';

import 'package:ovoride_driver/data/model/global/user/global_driver_model.dart';

LoginResponseModel loginResponseModelFromJson(String str) => LoginResponseModel.fromJson(json.decode(str));

String loginResponseModelToJson(LoginResponseModel data) => json.encode(data.toJson());

class LoginResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  Data? data;

  LoginResponseModel({this.remark, this.status, this.message, this.data});

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) => LoginResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null ? [] : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "remark": remark,
        "status": status,
        "message": message == null ? [] : List<dynamic>.from(message!.map((x) => x)),
        "data": data?.toJson(),
      };
}

class Data {
  String? accessToken;
  GlobalDriverInfoModel? user;
  String? tokenType;

  Data({this.accessToken, this.user, this.tokenType});

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        accessToken: json["access_token"],
        user: json["driver"] == null ? null : GlobalDriverInfoModel.fromJson(json["driver"]),
        tokenType: json["token_type"],
      );

  Map<String, dynamic> toJson() => {
        "access_token": accessToken,
        "driver": user?.toJson(),
        "token_type": tokenType,
      };
}
