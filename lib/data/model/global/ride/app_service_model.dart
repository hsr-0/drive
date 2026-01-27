class AppService {
  String? id;
  String? name;
  String? code;
  String? image;
  String? imageWithPath;

  AppService({this.id, this.name, this.code, this.image, this.imageWithPath});

  factory AppService.fromJson(Map<String, dynamic> json) => AppService(
        id: json["id"].toString(),
        name: json["name"],
        code: json["code"],
        image: json["image"],
        imageWithPath: json["image_with_path"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "code": code,
        "image": image,
        "image_with_path": imageWithPath,
      };
}
