import 'package:flutter/material.dart';

class DnsServer {
  final String name;
  final String dns;
  final bool isCustom;
  final String category;

  DnsServer({
    required this.name,
    required this.dns,
    this.isCustom = false,
    this.category = 'General',
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'dns': dns,
    'isCustom': isCustom,
    'category': category,
  };

  factory DnsServer.fromJson(Map<String, dynamic> json) => DnsServer(
    name: json['name'] ?? 'Unknown',
    dns: json['dns'] ?? '0.0.0.0',
    isCustom: json['isCustom'] is bool ? json['isCustom'] : true,
    category: json['category'] ?? 'General',
  );

  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'Gaming':
        return Icons.sports_esports_rounded;
      case 'Security':
        return Icons.verified_user_rounded;
      case 'Family':
        return Icons.family_restroom_rounded;
      case 'Private':
        return Icons.lock_person_rounded;
      case 'Custom':
        return Icons.edit_location_alt_rounded;
      default:
        return Icons.language_rounded;
    }
  }
}

List<DnsServer> defaultDnsServers = [
  DnsServer(name: "Google Public DNS", dns: "8.8.8.8", category: "General"),
  DnsServer(name: "Cloudflare", dns: "1.1.1.1", category: "General"),
  DnsServer(name: "Quad9 (Secure)", dns: "9.9.9.9", category: "Security"),
  DnsServer(name: "OpenDNS", dns: "208.67.222.222", category: "General"),

  DnsServer(name: "Shecan (تحریم‌شکن)", dns: "178.22.122.100", category: "Gaming"),
  DnsServer(name: "Electro (الکترو)", dns: "78.157.42.101", category: "Gaming"),
  DnsServer(name: "Radar Game (رادار)", dns: "10.202.10.10", category: "Gaming"),
  DnsServer(name: "403.online", dns: "10.202.10.202", category: "Gaming"),
  DnsServer(name: "Begzar (بگذر)", dns: "185.55.226.26", category: "Gaming"),

  DnsServer(name: "AdGuard DNS", dns: "94.140.14.14", category: "Security"),
  DnsServer(name: "Comodo Secure", dns: "8.26.56.26", category: "Security"),
  DnsServer(name: "CleanBrowsing", dns: "185.228.168.9", category: "Security"),

  DnsServer(name: "Cloudflare Family", dns: "1.1.1.3", category: "Family"),
  DnsServer(name: "Google Family", dns: "8.8.4.4", category: "Family"),
];