class KycPendingData {
  String? name;
  String? type;
  String? value;

  KycPendingData({this.name, this.type, this.value});

  factory KycPendingData.fromJson(Map<String, dynamic> json) => KycPendingData(
        name: json["name"],
        type: json["type"],
        value: json["value"] != null ? json["value"].toString() : "",
      );

  Map<String, dynamic> toJson() => {"name": name, "type": type, "value": value};
}
