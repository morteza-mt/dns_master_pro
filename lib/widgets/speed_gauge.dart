import 'package:flutter/material.dart';

class SpeedGauge extends StatelessWidget {
  final String title;
  final double value;
  final Color color;

  const SpeedGauge({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  @override
  Widget build(BuildContext context) {

    final String displayValue = value > 0 ? value.toStringAsFixed(1) : "--";

    final double progressValue = (value / 500).clamp(0.01, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
                ),
              ),
            ),

            SizedBox(
              width: 100,
              height: 100,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progressValue),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, animValue, child) {
                  return CircularProgressIndicator(
                    value: animValue,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        value == 0 ? color.withOpacity(0.3) : color
                    ),
                  );
                },
              ),
            ),
            // نمایش عدد در مرکز
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    shadows: [
                      if (value > 0) Shadow(color: color.withOpacity(0.6), blurRadius: 12),
                    ],
                  ),
                ),
                Text(
                  "Mbps",
                  style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                      fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).textTheme.bodySmall?.color,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}