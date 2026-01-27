import 'dart:convert';

import 'package:ovoride_driver/data/model/global/ride/ride_model.dart';

RideDetailsResponseModel rideDetailsResponseModelFromJson(String str) => RideDetailsResponseModel.fromJson(json.decode(str));

String rideDetailsResponseModelToJson(RideDetailsResponseModel data) => json.encode(data.toJson());

class RideDetailsResponseModel {
  String? remark;
  String? status;
  Data? data;
  List<String>? message;

  RideDetailsResponseModel({this.remark, this.status, this.message, this.data});

  factory RideDetailsResponseModel.fromJson(Map<String, dynamic> json) => RideDetailsResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null ? [] : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "remark": remark,
        "status": status,
        "data": data?.toJson(),
      };
}

class Data {
  RideModel? ride;
  String? userImagePath;

  Data({this.ride, this.userImagePath});

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        ride: json["ride"] == null ? null : RideModel.fromJson(json["ride"]),
        userImagePath: json["user_image_path"],
      );

  Map<String, dynamic> toJson() => {
        "ride": ride?.toJson(),
        "user_image_path": userImagePath,
      };
}
