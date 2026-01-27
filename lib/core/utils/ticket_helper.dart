import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'my_color.dart';
import 'my_strings.dart';

class TicketHelper {
  static Color getStatusColor(String status) {
    late Color statusColor;
    statusColor = status == '1'
        ? MyColor.getTextFieldDisableBorder()
        : status == '2'
            ? MyColor.highPriorityPurpleColor
            : status == '3'
                ? MyColor.redCancelTextColor
                : MyColor.greenSuccessColor;

    return statusColor;
  }

  static Color getPriorityColor(String priority) {
    late Color priorityColor;

    priorityColor = priority == '1'
        ? MyColor.pendingColor
        : priority == '2'
            ? MyColor.greenSuccessColor
            : priority == '3'
                ? MyColor.redCancelTextColor
                : MyColor.pendingColor;

    return priorityColor;
  }

  static String getPriorityText(String priority) {
    String priorityText = '';
    priorityText = priority == '1'
        ? MyStrings.low.tr
        : priority == '2'
            ? MyStrings.medium.tr
            : priority == '3'
                ? MyStrings.high.tr
                : '';
    return priorityText;
  }

  static String getStatusText(String status) {
    String statusText = '';
    statusText = status == '0'
        ? MyStrings.open.tr
        : status == '1'
            ? MyStrings.answered.tr
            : status == '2'
                ? MyStrings.replied.tr
                : status == '3'
                    ? MyStrings.closed.tr
                    : '';
    return statusText;
  }
}
