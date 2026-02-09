import 'package:flutter/material.dart';
import '../models/dns_server.dart';

class DnsCard extends StatelessWidget {
  final DnsServer server;
  final bool isSelected;
  final bool isConnected;
  final bool isConnecting;
  final String? ping;
  final VoidCallback onConnect;
  final String lang;

  const DnsCard({
    super.key,
    required this.server,
    required this.isSelected,
    required this.isConnected,
    required this.isConnecting,
    this.ping,
    required this.onConnect,
    required this.lang,
  });

  Color _getPingColor(String? ping) {
    if (ping == null || ping == "Error") return Colors.redAccent;
    try {
      int value = int.parse(ping.replaceAll("ms", ""));
      if (value < 100) return Colors.greenAccent;
      if (value < 200) return Colors.orangeAccent;
    } catch (_) {}
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    bool isActive = isSelected && isConnected;

    final String buttonText = isActive
        ? (lang == 'fa' ? "فعال" : "Active")
        : (lang == 'fa' ? "انتخاب" : "Select");

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isSelected ? Colors.blue.withOpacity(0.1) : null,
      child: ListTile(
        title: Text(server.name),
        subtitle: Row(
          children: [
            Text(server.dns),
            const SizedBox(width: 10),
            if (ping != null)
              Text(
                "Ping: $ping",
                style: TextStyle(
                  color: _getPingColor(ping),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: isConnecting ? null : onConnect,
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? Colors.green : (isSelected ? Colors.blue : null),
          ),
          child: Text(buttonText),
        ),
      ),
    );
  }
}