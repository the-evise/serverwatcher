import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/service.dart';

class HistoryChart extends StatelessWidget {
  final List<ServiceStatus> history;
  const HistoryChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const Text('No data');
    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.responseMs.toDouble()))
        .toList();

    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              dotData: FlDotData(show: false),
              color: const Color(0xFFB287F8), // soft purple
              barWidth: 3,
            ),
          ],
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: false),
        ),
      ),
    );
  }
}
