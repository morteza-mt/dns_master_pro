import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dns_server.dart';

class DnsStorageService {
  static const String _key = 'custom_dns_list';

  static Future<List<DnsServer>> getAllServers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? customJson = prefs.getString(_key);

    List<DnsServer> allServers = List.from(defaultDnsServers);

    if (customJson != null) {
      Iterable decoded = jsonDecode(customJson);
      List<DnsServer> customServers = decoded.map((model) => DnsServer.fromJson(model)).toList();
      allServers.addAll(customServers);
    }

    return allServers;
  }

  static Future<void> addServer(DnsServer server) async {

    final List<DnsServer> allServers = await getAllServers();

    allServers.add(server);

    final customOnly = allServers.where((s) => s.isCustom).toList();
    await saveCustomServers(customOnly);
  }

  static Future<void> saveCustomServers(List<DnsServer> customList) async {
    final prefs = await SharedPreferences.getInstance();
    List<DnsServer> onlyCustom = customList.where((s) => s.isCustom).toList();
    String encoded = jsonEncode(onlyCustom.map((s) => s.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}