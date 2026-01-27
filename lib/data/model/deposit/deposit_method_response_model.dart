import 'package:ovoride_driver/data/model/global/payment_method/app_payment_gateway.dart';

class DepositMethodResponseModel {
  DepositMethodResponseModel({
    String? remark,
    List<String>? message,
    Data? data,
  }) {
    _remark = remark;
    _message = message;
    _data = data;
  }

  DepositMethodResponseModel.fromJson(dynamic json) {
    _remark = json['remark'];
    _message = json["message"] == null ? [] : List<String>.from(json["message"]!.map((x) => x));
    _data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  String? _remark;
  List<String>? _message;
  Data? _data;

  String? get remark => _remark;
  List<String>? get message => _message;
  Data? get data => _data;
}

class Data {
  List<AppPaymentGateway>? gatewayCurrency;
  String? gatewayImage;
  Data({this.gatewayCurrency, this.gatewayImage});

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        gatewayCurrency: json["methods"] != null
            ? List<AppPaymentGateway>.from(
                json["methods"]!.map((x) => AppPaymentGateway.fromJson(x)),
              )
            : [],
        gatewayImage: json["image_path"],
      );

  Map<String, dynamic> toJson() => {
        "methods": gatewayCurrency?.map((x) => x.toJson()).toList(),
        "image_path": gatewayImage,
      };
}
