import 'package:flutter/material.dart';
import 'package:gojo/theme.dart';

class HoursDisplay extends StatelessWidget {
  final String? hours;
  const HoursDisplay({super.key, required this.hours});

  @override
  Widget build(BuildContext context) {
    if (hours == null || hours!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final commaIdx = hours!.indexOf(',');
    final timePart =
        commaIdx == -1 ? hours! : hours!.substring(0, commaIdx).trim();
    final daysPart =
        commaIdx == -1 ? null : hours!.substring(commaIdx + 1).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timePart,
          style: TextStyle(
            color: context.primary,
            fontSize: 13,
           // fontWeight: FontWeight.w600,
          ),
        ),
        if (daysPart != null && daysPart.isNotEmpty)
          Text(
            daysPart,
            style: TextStyle(
              color: context.secondary,
              fontSize: 11,
            ),
          ),
      ],
    );
  }
}