import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class VisualizationComponent extends StatelessWidget {
  final List<dynamic> issues;
  final Map<String, Color> statusColors;

  const VisualizationComponent({super.key, required this.issues, required this.statusColors});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildDonutChart()),
        const SizedBox(width: 24),
        Expanded(child: _buildStackedBarChart()),
      ],
    );
  }

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
}