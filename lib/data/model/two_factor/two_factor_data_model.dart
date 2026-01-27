import 'dart:convert';

TwoFactorCodeModel twoFactorCodeModelFromJson(String str) => TwoFactorCodeModel.fromJson(json.decode(str));

String twoFactorCodeModelToJson(TwoFactorCodeModel data) => json.encode(data.toJson());

class TwoFactorCodeModel {
  String? the0;
  String? remark;
  String? status;
  List<String>? message;
  Data? data;

  TwoFactorCodeModel({
    this.the0,
    this.remark,
    this.status,
    this.message,
    this.data,
  });

  factory TwoFactorCodeModel.fromJson(Map<String, dynamic> json) => TwoFactorCodeModel(
        the0: json["0"],
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null ? null : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "0": the0,
        "remark": remark,
        "status": status,
        "message": message == null ? [] : List<dynamic>.from(message!.map((x) => x)),
        "data": data?.toJson(),
      };
}

class Data {
  String? qrCodeUrl;
  String? secret;

  Data({this.qrCodeUrl, this.secret});

  factory Data.fromJson(Map<String, dynamic> json) => Data(qrCodeUrl: json["qr_code_url"], secret: json["secret"]);

  Map<String, dynamic> toJson() => {"qr_code_url": qrCodeUrl, "secret": secret};
}
