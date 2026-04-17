import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';

void main() => runApp(const HiltonJiraApp());

class HiltonJiraApp extends StatelessWidget {
  const HiltonJiraApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: const CardThemeData(color: Colors.white, elevation: 2),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String jiraUrl = "https://jira.hilton.com";
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
      final response = await http.get(
        Uri.parse("$jiraUrl/rest/api/2/myself"),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (epicId == null || epicId!.isEmpty) {
          _showEpicDialog();
        } else {
          fetchJiraData();
        }
      } else {
        _showTokenDialog(title: "Token Expired", message: "Please update your Jira PAT.");
      }
    } on SocketException {
      _showErrorDialog("VPN Error", "Please connect to Hilton GlobalProtect VPN.");
    } catch (e) {
      _showErrorDialog("Error", "Check your connection: $e");
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
    final jql = 'parent = "$epicId" OR "Epic Link" = "$epicId"';
    final url = "$jiraUrl/rest/api/2/search?jql=${Uri.encodeComponent(jql)}&maxResults=100";
    try {
      final response = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        setState(() {
          issues = json.decode(response.body)['issues'];
          lastSyncTime = DateFormat('HH:mm:ss').format(DateTime.now());
          isLoading = false;
        });
      }
    } catch (e) {
      _showErrorDialog("Fetch Error", "Check the Epic ID and try again.");
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
            _buildMetricsBar(),
            const SizedBox(height: 32),
            // --- CHARTS ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildDonutChart()),
                const SizedBox(width: 24),
                Expanded(child: _buildStackedBarChart()),
              ],
            ),
            const SizedBox(height: 40),
            const Text("Issues Table", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 16),
            _buildTable(),
          ],
        ),
      ),
    );
  }

  // --- DONUT CHART: RESTORED TO ORIGINAL SHARED VERSION ---
  Widget _buildDonutChart() {
    Map<String, double> counts = {};
    for (var i in issues) {
      String s = i['fields']['status']['name'];
      counts[s] = (counts[s] ?? 0) + 1;
    }

    return Card(
      child: Container(
        height: 450,
        padding: const EdgeInsets.all(16),
        child: SfCircularChart(
          title: ChartTitle(text: 'Status Distribution', textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap, textStyle: TextStyle(fontSize: 11)),
          series: <CircularSeries>[
            DoughnutSeries<MapEntry<String, double>, String>(
              dataSource: counts.entries.toList(),
              xValueMapper: (entry, _) => entry.key,
              yValueMapper: (entry, _) => entry.value,
              pointColorMapper: (entry, _) => statusColors[entry.key] ?? Colors.grey,
              dataLabelMapper: (entry, _) => "${entry.key}: ${entry.value.toInt()}",
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                labelPosition: ChartDataLabelPosition.outside,
                connectorLineSettings: ConnectorLineSettings(type: ConnectorType.curve, length: '10%'),
                textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              innerRadius: '35%', 
              radius: '80%', 
              explode: true,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStackedBarChart() {
    Map<String, Map<String, int>> dataMap = {};
    Set<String> allStatuses = {};

    for (var i in issues) {
      String name = i['fields']['assignee']?['displayName'] ?? "Unassigned";
      String status = i['fields']['status']['name'];
      allStatuses.add(status);
      dataMap.putIfAbsent(name, () => {});
      dataMap[name]![status] = (dataMap[name]![status] ?? 0) + 1;
    }

    return Card(
      child: Container(
        height: 450,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Workload by Assignee", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Expanded(
              child: SfCartesianChart(
                margin: EdgeInsets.zero,
                primaryXAxis: const CategoryAxis(labelRotation: -90, interval: 1, labelStyle: TextStyle(fontSize: 9), labelIntersectAction: AxisLabelIntersectAction.none),
                primaryYAxis: const NumericAxis(interval: 5, majorGridLines: MajorGridLines(width: 0.5, dashArray: [5, 5])),
                legend: const Legend(isVisible: true, position: LegendPosition.top),
                series: allStatuses.map((status) {
                  return StackedColumnSeries<String, String>(
                    name: status,
                    dataSource: dataMap.keys.toList(),
                    xValueMapper: (name, _) => name,
                    yValueMapper: (name, _) => dataMap[name]![status] ?? 0,
                    color: statusColors[status] ?? Colors.grey,
                    width: 0.85, spacing: 0.05,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsBar() {
    return Row(
      children: [
        _metricTile("Total Tasks", issues.length.toString(), Colors.blue),
        _metricTile("Done", issues.where((i) => i['fields']['status']['name'] == "Done").length.toString(), Colors.green),
        _metricTile("In Triage", issues.where((i) => i['fields']['status']['name'] == "In Triage").length.toString(), Colors.orange),
        _metricTile("EQAC Ready", issues.where((i) => i['fields']['status']['name'] == "Ready for EQAC").length.toString(), Colors.teal),
      ].map((e) => Expanded(child: e)).toList(),
    );
  }

  Widget _metricTile(String label, String val, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(children: [
          Text(label, style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(val, style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: color))
        ]),
      ),
    );
  }

  Widget _buildTable() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text("ISSUE KEY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text("SUMMARY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text("STATUS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text("ASSIGNEE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text("DATE ADDED", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ],
          rows: issues.map((i) {
            DateTime createdDate = DateTime.parse(i['fields']['created']);
            String formattedDate = DateFormat('MMM dd, yyyy').format(createdDate);
            String statusName = i['fields']['status']['name'];
            return DataRow(cells: [
              DataCell(Text(i['key'], style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)), onTap: () => launchUrl(Uri.parse("$jiraUrl/browse/${i['key']}"))),
              DataCell(SizedBox(width: 250, child: Text(i['fields']['summary'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))),
              DataCell(Text(statusName, style: TextStyle(color: statusColors[statusName] ?? Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 13))),
              DataCell(Text(i['fields']['assignee']?['displayName'] ?? "Unassigned", style: const TextStyle(fontSize: 13))),
              DataCell(Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 13))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}