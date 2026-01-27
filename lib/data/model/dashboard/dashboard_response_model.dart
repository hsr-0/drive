import 'dart:convert';

import 'package:ovoride_driver/data/model/global/ride/ride_model.dart';
import 'package:ovoride_driver/data/model/global/user/global_driver_model.dart';

DashBoardRideResponseModel newRideResponseModelFromJson(String str) => DashBoardRideResponseModel.fromJson(json.decode(str));

class DashBoardRideResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  Data? data;

  DashBoardRideResponseModel({
    this.remark,
    this.status,
    this.message,
    this.data,
  });

  factory DashBoardRideResponseModel.fromJson(Map<String, dynamic> json) => DashBoardRideResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null ? [] : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
      );
}

class Data {
  RideMainDataList? ride;
  GlobalDriverInfoModel? driverInfo;
  RideModel? runningRide;
  List<RideModel>? pendingRides;
  String? driverImagePath;
  String? userImagePath;

  Data({
    this.ride,
    this.driverInfo,
    this.runningRide,
    this.pendingRides,
    this.driverImagePath,
    this.userImagePath,
  });

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        ride: json["rides"] == null ? null : RideMainDataList.fromJson(json["rides"]),
        driverInfo: json["driver"] == null ? null : GlobalDriverInfoModel.fromJson(json["driver"]),
        runningRide: json["running_rides"] == null ? null : RideModel.fromJson(json["running_rides"]),
        driverImagePath: json["driver_image_path"].toString(),
        userImagePath: json["user_image_path"].toString(),
        pendingRides: json["pendingRides"] == null
            ? []
            : List<RideModel>.from(
                json["pendingRides"]!.map((x) => RideModel.fromJson(x)),
              ),
      );

  Map<String, dynamic> toJson() => {
        "rides": ride?.toJson(),
        "driver_info": driverInfo?.toJson(),
      };
}

class RideMainDataList {
  List<RideModel>? data;
  dynamic nextPageUrl;

  RideMainDataList({this.data, this.nextPageUrl});

  factory RideMainDataList.fromJson(Map<String, dynamic> json) => RideMainDataList(
        data: json["data"] == null
            ? []
            : List<RideModel>.from(
                json["data"]!.map((x) => RideModel.fromJson(x)),
              ),
        nextPageUrl: json["next_page_url"],
      );

  Map<String, dynamic> toJson() => {
        "data": data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
        "next_page_url": nextPageUrl,
      };
}
