import 'package:flutter/material.dart';

class MetricsComponent extends StatelessWidget {
  final List<dynamic> issues;

  const MetricsComponent({super.key, required this.issues});

  @override
  Widget build(BuildContext context) {
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
}