import 'dart:convert';
import 'package:ovoride_driver/data/model/global/formdata/global_kyc_form_data.dart';
import 'package:ovoride_driver/data/model/kyc/kyc_pending_data_model.dart';

DriverKycResponseModel kycResponseModelFromJson(String str) => DriverKycResponseModel.fromJson(json.decode(str));

class DriverKycResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  Data? data;

  DriverKycResponseModel({this.remark, this.status, this.message, this.data});

  factory DriverKycResponseModel.fromJson(Map<String, dynamic> json) => DriverKycResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null ? [] : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
      );
}

class Data {
  String? trx;
  WithdrawData? withdrawData;
  GlobalKYCForm? form;
  List<KycPendingData>? driverData;
  String? path;

  Data({this.trx, this.withdrawData, this.form, this.driverData, this.path});

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        trx: json["trx"],
        withdrawData: json["withdraw_data"] == null ? null : WithdrawData.fromJson(json["withdraw_data"]),
        form: json["form"] == null ? null : GlobalKYCForm.fromJson(json["form"]),
        driverData: json["driver_data"] == null
            ? []
            : List<KycPendingData>.from(
                json["driver_data"]!.map((x) => KycPendingData.fromJson(x)),
              ),
        path: json["file_path"].toString(),
      );

  Map<String, dynamic> toJson() => {};
}

class WithdrawData {
  String? methodId;
  String? driverId;
  String? amount;
  String? currency;
  String? rate;
  String? charge;
  String? finalAmount;
  String? afterCharge;
  String? trx;
  String? updatedAt;
  String? createdAt;
  String? id;

  WithdrawData({
    this.methodId,
    this.driverId,
    this.amount,
    this.currency,
    this.rate,
    this.charge,
    this.finalAmount,
    this.afterCharge,
    this.trx,
    this.updatedAt,
    this.createdAt,
    this.id,
  });

  factory WithdrawData.fromJson(Map<String, dynamic> json) => WithdrawData(
        methodId: json["method_id"] != null ? json["method_id"].toString() : "",
        driverId: json["driver_id"] != null ? json["driver_id"].toString() : "",
        amount: json["amount"] != null ? json["amount"].toString() : "",
        currency: json["currency"] != null ? json["currency"].toString() : "",
        rate: json["rate"] != null ? json["rate"].toString() : "",
        charge: json["charge"] != null ? json["charge"].toString() : "",
        finalAmount: json["final_amount"] != null ? json["final_amount"].toString() : "",
        afterCharge: json["after_charge"] != null ? json["after_charge"].toString() : "",
        trx: json["trx"] != null ? json["trx"].toString() : "",
        updatedAt: json["updated_at"] != null ? json["updated_at"].toString() : "",
        createdAt: json["created_at"] != null ? json["created_at"].toString() : "",
        id: json["id"] != null ? json["id"].toString() : "",
      );

  Map<String, dynamic> toJson() => {
        "method_id": methodId,
        "driver_id": driverId,
        "amount": amount,
        "currency": currency,
        "rate": rate,
        "charge": charge,
        "final_amount": finalAmount,
        "after_charge": afterCharge,
        "trx": trx,
        "updated_at": updatedAt,
        "created_at": createdAt,
        "id": id,
      };
}
