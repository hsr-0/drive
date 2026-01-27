import 'package:flutter/material.dart';

import '../bubble_type.dart';

class ChatBubbleClipper5 extends CustomClipper<Path> {
  ///The values assigned to the clipper types [BubbleType.sendBubble] and
  ///[BubbleType.receiverBubble] are distinct.
  final BubbleType? type;

  final double radius;

  final double secondRadius;

  ChatBubbleClipper5({this.type, this.radius = 15, this.secondRadius = 2});

  @override
  Path getClip(Size size) {
    var path = Path();

    if (type == BubbleType.sendBubble) {
      path.addRRect(
        RRect.fromLTRBR(0, 0, size.width, size.height, Radius.circular(radius)),
      );
      var path2 = Path();
      path2.addRRect(
        RRect.fromLTRBAndCorners(
          0,
          0,
          radius,
          radius,
          bottomRight: Radius.circular(secondRadius),
        ),
      );
      path.addPath(path2, Offset(size.width - radius, size.height - radius));
    } else {
      path.addRRect(
        RRect.fromLTRBR(0, 0, size.width, size.height, Radius.circular(radius)),
      );
      var path2 = Path();
      path2.addRRect(
        RRect.fromLTRBAndCorners(
          0,
          0,
          radius,
          radius,
          topLeft: Radius.circular(secondRadius),
        ),
      );
      path.addPath(path2, const Offset(0, 0));
    }

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}
