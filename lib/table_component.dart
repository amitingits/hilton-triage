import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class TableComponent extends StatefulWidget {
  final List<dynamic> filteredIssues;
  final String? filterStatus;
  final Function(String?) onFilterChanged;
  final Set<String> selectedIssueKeys;
  final Function(Set<String>) onSelectionChanged;
  final String jiraUrl;
  final Map<String, Color> statusColors;
  final int? sortColumnIndex;
  final bool sortAscending;
  final Function(int, bool) onSort;

  const TableComponent({
    super.key,
    required this.filteredIssues,
    required this.filterStatus,
    required this.onFilterChanged,
    required this.selectedIssueKeys,
    required this.onSelectionChanged,
    required this.jiraUrl,
    required this.statusColors,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
  });

  @override
  State<TableComponent> createState() => _TableComponentState();
}

class _TableComponentState extends State<TableComponent> {
  void _copySelectedData() {
    List<String> lines = ['Issue Key\tSummary\tStatus\tAssignee\tDate Added'];
    for (String key in widget.selectedIssueKeys) {
      var i = widget.filteredIssues.firstWhere((issue) => issue['key'] == key);
      DateTime createdDate = DateTime.parse(i['fields']['created']);
      String formattedDate = DateFormat('MMM dd, yyyy').format(createdDate);
      String statusName = i['fields']['status']['name'];
      lines.add('$key\t${i['fields']['summary']}\t$statusName\t${i['fields']['assignee']?['displayName'] ?? "Unassigned"}\t$formattedDate');
    }
    String data = lines.join('\n');
    Clipboard.setData(ClipboardData(text: data));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected data copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: widget.filterStatus,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Status',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("All")),
                      ...widget.statusColors.keys.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                    ],
                    onChanged: widget.onFilterChanged,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: widget.selectedIssueKeys.isEmpty ? null : _copySelectedData,
                  icon: const Icon(Icons.copy),
                  label: const Text("Copy Selected"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: DataTable(
              showCheckboxColumn: true,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columnSpacing: 20,
              sortColumnIndex: widget.sortColumnIndex,
              sortAscending: widget.sortAscending,
              columns: [
                DataColumn(
                  label: const Text("ISSUE KEY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onSort: (columnIndex, ascending) => widget.onSort(columnIndex, ascending),
                ),
                DataColumn(
                  label: const Text("SUMMARY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onSort: (columnIndex, ascending) => widget.onSort(columnIndex, ascending),
                ),
                DataColumn(
                  label: const Text("STATUS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onSort: (columnIndex, ascending) => widget.onSort(columnIndex, ascending),
                ),
                DataColumn(
                  label: const Text("ASSIGNEE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onSort: (columnIndex, ascending) => widget.onSort(columnIndex, ascending),
                ),
                DataColumn(
                  label: const Text("DATE ADDED", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onSort: (columnIndex, ascending) => widget.onSort(columnIndex, ascending),
                ),
              ],
              rows: widget.filteredIssues.map((i) {
                DateTime createdDate = DateTime.parse(i['fields']['created']);
                String formattedDate = DateFormat('MMM dd, yyyy').format(createdDate);
                String statusName = i['fields']['status']['name'];
                return DataRow(
                  selected: widget.selectedIssueKeys.contains(i['key']),
                  onSelectChanged: (selected) {
                    if (selected == true) {
                      widget.selectedIssueKeys.add(i['key']);
                    } else {
                      widget.selectedIssueKeys.remove(i['key']);
                    }
                    widget.onSelectionChanged(widget.selectedIssueKeys);
                  },
                  cells: [
                    DataCell(Text(i['key'], style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)), onTap: () => launchUrl(Uri.parse("${widget.jiraUrl}/browse/${i['key']}"))),
                    DataCell(SizedBox(width: 400, child: Text(i['fields']['summary'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))),
                    DataCell(Text(statusName, style: TextStyle(color: widget.statusColors[statusName] ?? Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 13))),
                    DataCell(Text(i['fields']['assignee']?['displayName'] ?? "Unassigned", style: const TextStyle(fontSize: 13))),
                    DataCell(Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 13))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}