import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/service.dart';

class HistoryChart extends StatelessWidget {
  final List<ServiceStatus> history;
  const HistoryChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const Text('No data');

    final times = history
        .map((h) => DateTime.tryParse(h.checkedAt)?.toLocal() ?? DateTime.now())
        .toList();

    final spots = <FlSpot>[];
    final failDots = <FlSpot>[];
    int minY = 1 << 30, maxY = 0, sum = 0, n = 0;

    for (var i = 0; i < history.length; i++) {
      final ms = history[i].responseMs;
      if (ms < minY) minY = ms;
      if (ms > maxY) maxY = ms;
      sum += ms;
      n++;
      final spot = FlSpot(i.toDouble(), ms.toDouble());
      spots.add(spot);
      if (history[i].status != 'OK') failDots.add(spot);
    }

    final avg = n == 0 ? 0.0 : sum / n;

    if (minY == maxY) {
      minY = (minY - 5).clamp(0, 1 << 30);
      maxY = maxY + 5;
    }

    final padding = ((maxY - minY) * 0.15).clamp(8, 200).toDouble();
    final minYd = (minY - padding).clamp(0, double.infinity).toDouble();
    final maxYd = (maxY + padding).toDouble();

    String fmtTime(DateTime dt) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          minY: minYd,
          maxY: maxYd,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => touchedSpots.map((ts) {
                final idx = ts.x.round();
                final dt = (idx >= 0 && idx < times.length) ? times[idx] : null;
                final timeStr = dt == null
                    ? ''
                    : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
                return LineTooltipItem(
                  '${ts.y.toStringAsFixed(0)} ms\n$timeStr',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  // show ~3 ticks max
                  final range = (maxYd - minYd).clamp(1.0, double.infinity);
                  final step = (range / 3).clamp(10.0, 100000.0);
                  final mod = ((value - minYd) % step);
                  if (mod > step / 2) return const SizedBox.shrink();
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= times.length)
                    return const SizedBox.shrink();
                  final interval = (times.length / 6).ceil().clamp(1, 9999);
                  if (i % interval != 0 && i != times.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      fmtTime(times[i]),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: Colors.white12, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: avg.toDouble(),
                color: Colors.amber,
                strokeWidth: 1.5,
                dashArray: const [6, 4],
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              color: const Color(0xFFB287F8),
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: const LinearGradient(
                  colors: [Color(0x55B287F8), Color(0x105C3A99)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            if (failDots.isNotEmpty)
              LineChartBarData(
                spots: failDots,
                isCurved: false,
                barWidth: 0,
                color: Colors.redAccent,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, p, bar, i) =>
                      FlDotCirclePainter(radius: 3.6, color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
