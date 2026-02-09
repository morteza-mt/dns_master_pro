import 'package:flutter/material.dart';

class SpeedTestButton extends StatelessWidget {
  final bool isTesting;
  final VoidCallback onPressed;
  final String lang;

  const SpeedTestButton({
    super.key,
    required this.isTesting,
    required this.onPressed,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final String loadingText = lang == 'fa' ? "در حال تست شبکه..." : "Testing Network...";
    final String idleText = lang == 'fa' ? "شروع تست کامل سرعت" : "Start Full Speed Test";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // کمی پدینگ عمودی کمتر
      child: ElevatedButton.icon(
        onPressed: isTesting ? null : onPressed,
        icon: isTesting
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Icon(Icons.speed, color: Colors.white),
        label: Text(
          isTesting ? loadingText : idleText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          disabledBackgroundColor: Colors.blueAccent.withOpacity(0.6),
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: isTesting ? 0 : 4,
        ),
      ),
    );
  }
}