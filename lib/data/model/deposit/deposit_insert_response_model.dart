class DepositInsertResponseModel {
  DepositInsertResponseModel({
    String? remark,
    String? status,
    List<String>? message,
    DepositInsertData? data,
  }) {
    _remark = remark;
    _status = status;
    _message = message;
    _data = data;
  }

  DepositInsertResponseModel.fromJson(dynamic json) {
    _remark = json['remark'];
    _status = json['status'];
    _message = json["message"] == null ? [] : List<String>.from(json["message"]!.map((x) => x));
    _data = json['data'] != null ? DepositInsertData.fromJson(json['data']) : null;
  }

  String? _remark;
  String? _status;
  List<String>? _message;
  DepositInsertData? _data;

  String? get remark => _remark;
  String? get status => _status;
  List<String>? get message => _message;
  DepositInsertData? get data => _data;
}

class DepositInsertData {
  Deposit? deposit;
  String? redirectUrl;

  DepositInsertData({this.deposit, this.redirectUrl});

  factory DepositInsertData.fromJson(Map<String, dynamic> json) => DepositInsertData(
        deposit: json["deposit"] == null ? null : Deposit.fromJson(json["deposit"]),
        redirectUrl: json["redirect_url"],
      );

  Map<String, dynamic> toJson() => {
        "deposit": deposit?.toJson(),
        "redirect_url": redirectUrl,
      };
}

class Deposit {
  String? successUrl;
  String? failedUrl;

  Deposit({this.successUrl, this.failedUrl});

  factory Deposit.fromJson(Map<String, dynamic> json) => Deposit(successUrl: json["success_url"], failedUrl: json["failed_url"]);

  Map<String, dynamic> toJson() => {
        "success_url": successUrl,
        "failed_url": failedUrl,
      };
}
