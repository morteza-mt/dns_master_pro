import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/dns_storage_service.dart';
import '../services/network_manager.dart';
import '../models/dns_server.dart';

class DnsFinderPage extends StatefulWidget {
  final String lang;
  const DnsFinderPage({super.key, required this.lang});

  @override
  State<DnsFinderPage> createState() => _DnsFinderPageState();
}

class _DnsFinderPageState extends State<DnsFinderPage> {
  String selectedCountry = 'ir';
  int searchLimit = 20;
  bool isSearching = false;
  List<Map<String, dynamic>> foundServers = [];
  static final Set<String> _seenIps = {};

  final Map<String, String> popularCountries = {
    'ir': 'Iran 🇮🇷',
    'de': 'Germany 🇩🇪',
    'us': 'USA 🇺🇸',
    'gb': 'UK 🇬🇧',
    'tr': 'Turkey 🇹🇷',
    'nl': 'Netherlands 🇳🇱',
    'fr': 'France 🇫🇷',
    'ca': 'Canada 🇨🇦',
    'sg': 'Singapore 🇸🇬',
    'jp': 'Japan 🇯🇵',
  };


  Future<void> _startSearch({bool clearCache = false}) async {
    if (clearCache) {
      _seenIps.clear();
    }
    setState(() {
      isSearching = true;
      foundServers = [];
    });

    try {

      final existingServers = await DnsStorageService.getAllServers();
      final existingIps = existingServers.map((s) => s.dns).toSet();

      final url = 'http://public-dns.info/nameserver/$selectedCountry.json';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        List<dynamic> allData = jsonDecode(response.body);
        List<Map<String, dynamic>> tempResults = [];

        for (var item in allData) {
          String ip = item['ip'];
          if (!existingIps.contains(ip) && !_seenIps.contains(ip)) {
            tempResults.add({
              'dns': ip,
              'name': item['as_org'] ?? 'Unknown Provider',
              'location': "${item['city'] ?? ''} ${item['country_id']}",
              'ping': null,
            });
            _seenIps.add(ip);
          }
          if (tempResults.length >= searchLimit) break;
        }

        if (tempResults.isEmpty) {
          setState(() => isSearching = false);
          _showNoNewResultsDialog();
        } else {
          await Future.wait(tempResults.map((server) async {
            final p = await NetworkManager.getPing(server['dns'])
                .timeout(const Duration(seconds: 3), onTimeout: () => null);
            server['ping'] = p;
          }));

          tempResults.removeWhere((server) => server['ping'] == null);

          if (tempResults.isEmpty) {
            setState(() => isSearching = false);
            _showNoNewResultsDialog();
          } else {
            tempResults.sort((a, b) => (a['ping'] ?? 999).compareTo(b['ping'] ?? 999));
            setState(() => foundServers = tempResults);
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isSearching = false);
    }
  }

  void _showSaveDialog(Map<String, dynamic> server) {
    TextEditingController nameController = TextEditingController(text: server['name']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Save DNS", style: TextStyle(fontFamily: 'Vazir')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("IP: ${server['dns']}", style: const TextStyle(color: Colors.cyanAccent)),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Unique Nickname"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newServer = DnsServer(
                name: nameController.text,
                dns: server['dns'],
                category: 'Private',
                isCustom: true,
              );
              await DnsStorageService.addServer(newServer);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added to your list!")));
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showNoNewResultsDialog() {
    bool isFa = widget.lang == 'fa';

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(
            popularCountries[selectedCountry] ?? "",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            isFa
                ? "تمامی دی‌ان‌اس‌های جدید این کشور اسکن شده‌اند. آیا می‌خواهید حافظه موقت پاک شود و دوباره از ابتدا جستجو کنید؟"
                : "All new DNS servers for this country have been scanned. Would you like to clear the cache and search from scratch?",
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isFa ? "انصراف" : "Cancel")
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _startSearch(clearCache: true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
              child: Text(isFa ? "پاکسازی و جستجوی مجدد" : "Clear & Rescan"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isFa = widget.lang == 'fa';
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF0F111A) : Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            isFa ? "جستجوگر هوشمند" : "Smart DNS Explorer",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          foregroundColor: isDarkMode ? Colors.cyanAccent : Theme.of(context).colorScheme.onSurface,
          backgroundColor: Colors.transparent,
        ),
        body: Column(
          children: [
            _buildFilterBar(isFa, isDarkMode),

            Divider(color: Colors.cyanAccent.withOpacity(0.1), height: 1),

            Expanded(
              child: isSearching
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: isDarkMode ? Colors.cyanAccent : Theme.of(context).primaryColor),
                    const SizedBox(height: 15),
                    Text(
                      isFa ? "در حال جستجو و پینگ..." : "Searching & Ping...",
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              )
                  : _buildListView(isFa, isDarkMode),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(bool isFa, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,

      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedCountry,
                  items: popularCountries.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) => setState(() => selectedCountry = v!),
                  decoration: const InputDecoration(labelText: "Country", border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<int>(
                  value: searchLimit,
                  items: [10, 20, 50].map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
                  onChanged: (v) => setState(() => searchLimit = v!),
                  decoration: const InputDecoration(labelText: "Limit", border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isSearching ? null : () => _startSearch(),
            icon: const Icon(Icons.travel_explore, size: 22),
            label: Text(isFa ? "شروع جستجوی هوشمند" : "Start Smart Discovery"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent.withOpacity(0.8), // رنگ ملایم‌تر
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 0,
              minimumSize: const Size(double.infinity, 55),
            ),
          ),

          TextButton.icon(
            onPressed: () {
              setState(() {
                _seenIps.clear();
                foundServers = [];
              });
              _showSnackBar("Cache cleared! Ready to search from scratch.");
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text("Reset Seen Filter"),
          )
        ],
      ),
    );
  }

  Widget _buildListView(bool isFa, bool isDarkMode) {
    if (foundServers.isEmpty) {
      return Center(
        child: Text(
          isFa ? "موردی یافت نشد. جستجو را شروع کنید" : "No servers found. Start a scan!",
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
        ),
      );
    }
    return ListView.builder(
      itemCount: foundServers.length,
      itemBuilder: (context, index) {
        final s = foundServers[index];
        return ListTile(
          leading: const Icon(Icons.dns, color: Colors.cyanAccent),
          title: Text(s['dns'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("${s['name']}\n${s['location']}", style: const TextStyle(fontSize: 11)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s['ping'] != null ? "${s['ping']}ms" : "--", style: TextStyle(color: (s['ping'] ?? 999) < 100 ? Colors.green : Colors.orange)),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent), onPressed: () => _showSaveDialog(s)),
            ],
          ),
        );
      },
    );
  }
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(15),
      ),
    );
  }
}