class RiderRule {
  String? id;
  String? name;
  String? status;
  String? createdAt;
  String? updatedAt;

  RiderRule({this.id, this.name, this.status, this.createdAt, this.updatedAt});

  factory RiderRule.fromJson(Map<String, dynamic> json) => RiderRule(
        id: json["id"].toString(),
        name: json["name"],
        status: json["status"].toString(),
        createdAt: json["created_at"]?.toString(),
        updatedAt: json["updated_at"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "status": status,
        "created_at": createdAt,
        "updated_at": updatedAt,
      };
}
