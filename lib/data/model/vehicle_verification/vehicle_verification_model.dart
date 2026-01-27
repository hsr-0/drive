// To parse this JSON data, do
//
//     final kycResponseModel = kycResponseModelFromJson(jsonString);

import 'dart:convert';

import 'package:ovoride_driver/data/model/global/formdata/global_kyc_form_data.dart';
import 'package:ovoride_driver/data/model/global/ride/app_service_model.dart';
import 'package:ovoride_driver/data/model/global/ride/ride_rulse_model.dart';
import 'package:ovoride_driver/data/model/kyc/kyc_pending_data_model.dart';

VehicleKycResponseModel kycResponseModelFromJson(String str) => VehicleKycResponseModel.fromJson(json.decode(str));

class VehicleKycResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  Data? data;

  VehicleKycResponseModel({this.remark, this.status, this.message, this.data});

  factory VehicleKycResponseModel.fromJson(Map<String, dynamic> json) => VehicleKycResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null ? [] : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
      );
}

class Data {
  GlobalKYCForm? form;
  List<AppService>? services;
  PendingVehicleData? pendingVehicleData;
  List<Brand>? brands;
  List<RiderRule>? riderRules;
  //pending data
  List<KycPendingData>? vehicleData;
  AppService? selectedServices;
  List<VerifyElement>? colors;
  List<VerifyElement>? years;

  String? path;
  String? serviceImagePath;
  String? brandImagePath;

  Data({
    this.form,
    this.services,
    this.pendingVehicleData,
    this.brands,
    this.riderRules,
    this.vehicleData,
    this.selectedServices,
    this.path,
    this.serviceImagePath,
    this.brandImagePath,
    this.colors,
    this.years,
  });

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        form: json["form"] == null ? null : GlobalKYCForm.fromJson(json["form"]),
        pendingVehicleData: json["vehicle"] == null ? null : PendingVehicleData.fromJson(json["vehicle"]),
        services: json["services"] == null
            ? []
            : List<AppService>.from(
                json["services"]!.map((x) => AppService.fromJson(x)),
              ),
        brands: json["brands"] == null ? [] : List<Brand>.from(json["brands"]!.map((x) => Brand.fromJson(x))),
        riderRules: json["rider_rules"] == null
            ? []
            : List<RiderRule>.from(
                json["rider_rules"]!.map((x) => RiderRule.fromJson(x)),
              ),
        selectedServices: json["service"] == null ? null : AppService.fromJson(json["service"]),
        vehicleData: json["vehicle_data"] == null
            ? []
            : List<KycPendingData>.from(
                json["vehicle_data"]!.map((x) => KycPendingData.fromJson(x)),
              ),
        colors: json["colors"] == null
            ? []
            : List<VerifyElement>.from(
                json["colors"]!.map((x) => VerifyElement.fromJson(x)),
              ),
        years: json["years"] == null
            ? []
            : List<VerifyElement>.from(
                json["years"]!.map((x) => VerifyElement.fromJson(x)),
              ),
        path: json["file_path"].toString(),
        serviceImagePath: json["service_image_path"].toString(),
        brandImagePath: json["brand_image_path"].toString(),
      );

  Map<String, dynamic> toJson() => {
        "services": services == null ? [] : List<dynamic>.from(services!.map((x) => x.toJson())),
        "brands": brands == null ? [] : List<dynamic>.from(brands!.map((x) => x.toJson())),
        "rider_rules": riderRules == null ? [] : List<dynamic>.from(riderRules!.map((x) => x.toJson())),
      };
}

class Brand {
  String? id;
  String? name;
  String? image;
  String? createdAt;
  String? updatedAt;
  String? imageWithPath;
  List<VerifyElement>? models;

  Brand({
    this.id,
    this.name,
    this.image,
    this.createdAt,
    this.updatedAt,
    this.imageWithPath,
    this.models,
  });

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
        id: json["id"].toString(),
        name: json["name"],
        image: json["image"],
        createdAt: json["created_at"]?.toString(),
        updatedAt: json["updated_at"]?.toString(),
        imageWithPath: json["image_with_path"],
        models: json["models"] == null
            ? []
            : List<VerifyElement>.from(
                json["models"].map((x) => VerifyElement.fromJson(x)),
              ),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "image": image,
        "created_at": createdAt,
        "updated_at": updatedAt,
        "image_with_path": imageWithPath,
        "models": models == null ? [] : List<dynamic>.from(models!.map((x) => x.toJson())),
      };
}

class VerifyElement {
  final String? id;
  final String? name;
  final String? status;
  final String? brandId;
  final String? createdAt;
  final String? updatedAt;

  VerifyElement({
    this.id,
    this.name,
    this.status,
    this.brandId,
    this.createdAt,
    this.updatedAt,
  });

  factory VerifyElement.fromJson(Map<String, dynamic> json) => VerifyElement(
        id: json["id"].toString(),
        name: json["name"].toString(),
        status: json["status"].toString(),
        brandId: json["brand_id"].toString(),
        createdAt: json["created_at"]?.toString(),
        updatedAt: json["updated_at"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "status": status,
        "brand_id": brandId,
        "created_at": createdAt?.toString(),
        "updated_at": updatedAt?.toString(),
      };
}

class PendingVehicleData {
  VerifyElement? color;
  VerifyElement? year;
  Brand? brand;
  VerifyElement? model;
  String? imageSrc;

  PendingVehicleData({
    this.color,
    this.year,
    this.brand,
    this.model,
    this.imageSrc,
  });

  factory PendingVehicleData.fromJson(
    Map<String, dynamic> json,
  ) =>
      PendingVehicleData(
        color: json["color"] == null ? null : VerifyElement.fromJson(json["color"]),
        year: json["year"] == null ? null : VerifyElement.fromJson(json["year"]),
        brand: json["brand"] == null ? null : Brand.fromJson(json["brand"]),
        model: json["model"] == null ? null : VerifyElement.fromJson(json["model"]),
        imageSrc: json["image_src"]?.toString(),
      );
}
