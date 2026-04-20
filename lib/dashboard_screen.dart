import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'metrics_component.dart';
import 'visualization_component.dart';
import 'table_component.dart';
import 'hilton_api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final HiltonApiService _apiService = HiltonApiService();
  String? token;
  String? epicId;
  List<dynamic> issues = [];
  bool isLoading = true;
  String lastSyncTime = "--:--:--";
  Timer? _syncTimer;

  final Map<String, Color> statusColors = {
    "Done": const Color(0xFF3B82F6),
    "In Triage": const Color(0xFFF59E0B),
    "Ready for EQAC": const Color(0xFF10B981),
    "Failed": const Color(0xFFEF4444),
    "Ready for Dev": const Color(0xFF8B5CF6),
    "Backlog": const Color(0xFF64748B),
    "In Stg": const Color(0xFF06B6D4),
  };

  String? filterStatus;
  int? sortColumnIndex;
  bool sortAscending = true;
  Set<String> selectedIssueKeys = {};

  @override
  void initState() {
    super.initState();
    _checkInitialState();
    _startAutoSync();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  List<dynamic> get filteredIssues => filterStatus == null ? issues : issues.where((i) => i['fields']['status']['name'] == filterStatus).toList();

  void _sortIssues() {
    issues.sort((a, b) {
      dynamic aVal, bVal;
      switch (sortColumnIndex) {
        case 0:
          aVal = a['key'];
          bVal = b['key'];
          break;
        case 1:
          aVal = a['fields']['summary'];
          bVal = b['fields']['summary'];
          break;
        case 2:
          aVal = a['fields']['status']['name'];
          bVal = b['fields']['status']['name'];
          break;
        case 3:
          aVal = a['fields']['assignee']?['displayName'] ?? "Unassigned";
          bVal = b['fields']['assignee']?['displayName'] ?? "Unassigned";
          break;
        case 4:
          aVal = DateTime.parse(a['fields']['created']);
          bVal = DateTime.parse(b['fields']['created']);
          break;
        default:
          return 0;
      }
      if (aVal is DateTime && bVal is DateTime) {
        return sortAscending ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
      } else {
        String aStr = aVal.toString();
        String bStr = bVal.toString();
        return sortAscending ? aStr.compareTo(bStr) : bStr.compareTo(aStr);
      }
    });
  }

  // --- 5-MINUTE AUTO SYNC LOGIC ---
  void _startAutoSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (!isLoading && token != null && epicId != null) {
        fetchJiraData();
      }
    });
  }

  Future<void> _checkInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('jira_token');
    epicId = prefs.getString('last_epic_id');

    if (token == null || token!.isEmpty) {
      _showTokenDialog(title: "Hilton Jira Setup", message: "Enter your PAT to begin.");
    } else {
      _validateAndFetch();
    }
  }

  Future<void> _validateAndFetch() async {
    setState(() => isLoading = true);
    try {
      bool isValid = await _apiService.validateToken(token!);
      if (isValid) {
        if (epicId == null || epicId!.isEmpty) {
          _showEpicDialog();
        } else {
          fetchJiraData();
        }
      } else {
        _showTokenDialog(title: "Token Expired", message: "Please update your Jira PAT.");
      }
    } catch (e) {
      _showErrorDialog("Error", e.toString());
    }
  }

  // --- DIALOGS ---
  void _showTokenDialog({required String title, required String message}) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: "PAT Token", hintText: message),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('jira_token', controller.text);
              setState(() => token = controller.text);
              Navigator.pop(context);
              _validateAndFetch();
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  void _showEpicDialog() {
    TextEditingController controller = TextEditingController(text: epicId);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text("Enter Epic Key"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "e.g., PEPR-11144", border: OutlineInputBorder()),
          onSubmitted: (val) => _saveEpic(val),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => _saveEpic(controller.text), child: const Text("Load")),
        ],
      ),
    );
  }

  void _saveEpic(String input) async {
    if (input.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      String cleanEpic = input.trim().toUpperCase();
      await prefs.setString('last_epic_id', cleanEpic);
      setState(() {
        epicId = cleanEpic;
        isLoading = true;
      });
      Navigator.pop(context);
      fetchJiraData();
    }
  }

  void _showErrorDialog(String title, String message) {
    setState(() => isLoading = false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  Future<void> fetchJiraData() async {
    if (epicId == null || token == null) return;
    try {
      final fetchedIssues = await _apiService.fetchIssues(token!, epicId!);
      setState(() {
        issues = fetchedIssues;
        lastSyncTime = DateFormat('HH:mm:ss').format(DateTime.now());
        isLoading = false;
      });
    } catch (e) {
      _showErrorDialog("Fetch Error", e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Epic Insights: $epicId", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showEpicDialog(),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text("Switch EPIC"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        side: const BorderSide(color: Colors.blueAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text("Last Sync: $lastSyncTime", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            MetricsComponent(issues: issues),
            const SizedBox(height: 32),
            VisualizationComponent(issues: issues, statusColors: statusColors),
            const SizedBox(height: 40),
            const Text("Issues Table", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 16),
            TableComponent(
              filteredIssues: filteredIssues,
              filterStatus: filterStatus,
              onFilterChanged: (status) => setState(() {
                filterStatus = status;
                selectedIssueKeys.clear();
              }),
              selectedIssueKeys: selectedIssueKeys,
              onSelectionChanged: (keys) => setState(() => selectedIssueKeys = keys),
              jiraUrl: _apiService.jiraUrl,
              statusColors: statusColors,
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
              onSort: (columnIndex, ascending) {
                setState(() {
                  sortColumnIndex = columnIndex;
                  sortAscending = ascending;
                  _sortIssues();
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}