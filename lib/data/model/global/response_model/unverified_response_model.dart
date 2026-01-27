import 'dart:convert';

UnVerifiedUserResponseModel unVarifiedUserResponseModelFromJson(String str) => UnVerifiedUserResponseModel.fromJson(json.decode(str));

class UnVerifiedUserResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  Data? data;

  UnVerifiedUserResponseModel({
    this.remark,
    this.status,
    this.message,
    this.data,
  });

  factory UnVerifiedUserResponseModel.fromJson(Map<String, dynamic> json) => UnVerifiedUserResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null ? [] : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
      );
}

class Data {
  String? isBan;
  String? emailVerified;
  String? mobileVerified;

  Data({this.isBan, this.emailVerified, this.mobileVerified});

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        isBan: json["is_ban"].toString(),
        emailVerified: json["email_verified"].toString(),
        mobileVerified: json["mobile_verified"].toString(),
      );

  Map<String, dynamic> toJson() => {
        "is_ban": isBan,
        "email_verified": emailVerified,
        "mobile_verified": mobileVerified,
      };
}
