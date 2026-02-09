import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/dns_server.dart';
import '../services/dns_storage_service.dart';
import '../services/network_manager.dart';

import 'dns_finder_page.dart';

class ManageDnsPage extends StatefulWidget {
  final String lang;
  const ManageDnsPage({super.key, required this.lang});

  @override
  State<ManageDnsPage> createState() => _ManageDnsPageState();
}

class _ManageDnsPageState extends State<ManageDnsPage> {


  List<DnsServer> customServers = [];

  final List<Map<String, dynamic>> categories = [
    {'id': 'General', 'en': 'General', 'fa': 'عمومی', 'icon': Icons.language_rounded},
    {'id': 'Gaming', 'en': 'Gaming', 'fa': 'مخصوص بازی', 'icon': Icons.sports_esports_rounded},
    {'id': 'Security', 'en': 'Security', 'fa': 'امنیت', 'icon': Icons.verified_user_rounded},
    {'id': 'Family', 'en': 'Family', 'fa': 'خانواده', 'icon': Icons.family_restroom_rounded},
    {'id': 'Private', 'en': 'Private', 'fa': 'شخصی', 'icon': Icons.lock_person_rounded},
  ];


  @override
  void initState() {
    super.initState();
    _loadCustomServers();
  }

  Future<void> _loadCustomServers() async {
    final all = await DnsStorageService.getAllServers();
    if (mounted) {
      setState(() {
        customServers = all.where((s) => s.isCustom).toList();
      });
    }
  }

  void _navigateToFinder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DnsFinderPage(lang: widget.lang), // ارسال زبان به صفحه بعد
      ),
    ).then((_) {
      _loadCustomServers();
    });
  }

  Future<void> _exportData() async {
    try {
      final jsonStr = jsonEncode(customServers.map((e) => e.toJson()).toList());
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/dns_backup.json');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles([XFile(file.path)], text: 'My DNS Backup');
    } catch (e) {
      _showSnackBar("Export failed: $e");
    }
  }

  Future<void> _importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        List decoded = jsonDecode(content);
        List<DnsServer> imported = decoded.map((e) => DnsServer.fromJson(e)).toList();

        for (var item in imported) {
          if (!customServers.any((element) => element.dns == item.dns)) {
            customServers.add(item);
          }
        }
        await DnsStorageService.saveCustomServers(customServers);
        _loadCustomServers();
        _showSnackBar(widget.lang == 'fa' ? "ایمپورت با موفقیت انجام شد" : "Import successful");
      }
    } catch (e) {
      _showSnackBar("Import failed: $e");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Row(
          children: [
            const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _showDnsDialog({DnsServer? server, int? index}) {
    final nameController = TextEditingController(text: server?.name);
    final dnsController = TextEditingController(text: server?.dns);
    String selectedCat = server?.category ?? 'General';
    final ipRegex = RegExp(r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(widget.lang == 'fa' ? (server == null ? "افزودن DNS" : "ویرایش") : (server == null ? "Add DNS" : "Edit")),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: InputDecoration(labelText: widget.lang == 'fa' ? "نام" : "Name")),
                TextField(
                  controller: dnsController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: "IP (e.g. 8.8.8.8)"),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedCat,
                  decoration: InputDecoration(
                    labelText: widget.lang == 'fa' ? "کاربرد DNS" : "DNS Usage",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat['id'],
                      child: Row(
                        children: [
                          Icon(cat['icon'], size: 20, color: Colors.cyanAccent),
                          const SizedBox(width: 10),
                          Text(widget.lang == 'fa' ? cat['fa'] : cat['en']),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedCat = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.lang == 'fa' ? "لغو" : "Cancel")),
            ElevatedButton(
              onPressed: () async {
                String name = nameController.text.trim();
                String dns = dnsController.text.trim();

                if (name.isEmpty || !ipRegex.hasMatch(dns)) {
                  _showSnackBar(widget.lang == 'fa' ? "اطلاعات نامعتبر است" : "Invalid Info");
                  return;
                }

                _showLoadingDialog(widget.lang == 'fa' ? "تست اتصال..." : "Testing IP...");
                final pingResult = await NetworkManager.getPing(dns);
                if (!mounted) return;
                Navigator.pop(context);

                if (pingResult == null) {
                  _showSnackBar(widget.lang == 'fa' ? "IP پاسخگو نیست" : "IP not responding");
                  return;
                }

                final newS = DnsServer(name: name, dns: dns, isCustom: true, category: selectedCat);
                if (index == null) customServers.add(newS);
                else customServers[index] = newS;

                await DnsStorageService.saveCustomServers(customServers);
                _loadCustomServers();
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: Text(widget.lang == 'fa' ? "ذخیره" : "Save"),
            )
          ],
        ),
      ),
    );
  }

  String _getCategoryName(String id) {
    final cat = categories.firstWhere((e) => e['id'] == id, orElse: () => categories[0]);
    return widget.lang == 'fa' ? cat['fa'] : cat['en'];
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.lang == 'fa' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.lang == 'fa' ? "مدیریت DNSها" : "Manage DNS"),
          actions: [
            IconButton(icon: const Icon(Icons.share), onPressed: _exportData),
            IconButton(icon: const Icon(Icons.file_open), onPressed: _importData),
          ],
        ),
        body: customServers.isEmpty
            ? Center(child: Text(widget.lang == 'fa' ? "لیست خالی است" : "List is empty"))
            : ListView.builder(
          itemCount: customServers.length,
          itemBuilder: (context, index) {
            final item = customServers[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFF1C1F2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: Icon(DnsServer.getCategoryIcon(item.category), color: Colors.cyanAccent),
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                subtitle: Text("${item.dns} • ${_getCategoryName(item.category)}", style: const TextStyle(color: Colors.white38)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showDnsDialog(server: item, index: index)),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                      onPressed: () async {
                        setState(() => customServers.removeAt(index));
                        await DnsStorageService.saveCustomServers(customServers);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // دکمه جستجوی هوشمند
            FloatingActionButton.extended(
              heroTag: 'finder',
              onPressed: () => _navigateToFinder(), // <--- اتصال به متد
              backgroundColor: const Color(0xFF2C2F3E), // رنگ تیره هماهنگ با تم
              label: Text(
                widget.lang == 'fa' ? "جستجوی هوشمند" : "Smart Finder",
                style: const TextStyle(color: Colors.cyanAccent),
              ),
              icon: const Icon(Icons.travel_explore, color: Colors.cyanAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
            ),
            const SizedBox(height: 12),
            // دکمه افزودن دستی
            FloatingActionButton.extended(
              heroTag: 'addManual',
              onPressed: () => _showDnsDialog(),
              backgroundColor: Colors.cyanAccent,
              label: Text(
                widget.lang == 'fa' ? "افزودن دستی" : "Manual Add",
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.add, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}