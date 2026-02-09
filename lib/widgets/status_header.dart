import 'package:flutter/material.dart';

class StatusHeader extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onDisconnect;
  final String lang;

  const StatusHeader({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    required this.onDisconnect,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    // منطق متون و رنگ‌ها
    final String title = lang == 'fa' ? "وضعیت اتصال" : "Connection Status";
    final String statusText;
    final Color mainColor;
    final IconData statusIcon;

    if (isConnecting) {
      statusText = lang == 'fa' ? "در حال برقراری..." : "Connecting...";
      mainColor = Colors.amber;
      statusIcon = Icons.sync;
    } else if (isConnected) {
      statusText = lang == 'fa' ? "امنیت برقرار است" : "Secure Connection";
      mainColor = Colors.cyanAccent;
      statusIcon = Icons.shield;
    } else {
      statusText = lang == 'fa' ? "غیرفعال" : "Disconnected";
      mainColor = Colors.pinkAccent;
      statusIcon = Icons.shield_outlined;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        // استفاده از گرادینت برای ظاهر مدرن‌تر
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blueGrey.shade900,
            isConnected ? Colors.blue.shade900.withOpacity(0.8) : Colors.black87,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: mainColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: mainColor.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mainColor.withOpacity(0.1),
                ),
              ),
              isConnecting
                  ? SizedBox(
                width: 45,
                height: 45,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(mainColor),
                ),
              )
                  : Icon(statusIcon, size: 35, color: mainColor),
            ],
          ),
          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: mainColor,
                    shadows: [
                      Shadow(color: mainColor.withOpacity(0.5), blurRadius: 10)
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isConnected && !isConnecting)
            IconButton.filledTonal(
              onPressed: isConnecting ? null : onDisconnect,
              icon: const Icon(Icons.power_settings_new),
              style: IconButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.2),
                foregroundColor: Colors.redAccent,
              ),
            ),
        ],
      ),
    );
  }
}