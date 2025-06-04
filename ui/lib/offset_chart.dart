import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class OffsetChart extends StatelessWidget {
  const OffsetChart({
    super.key, 
    required this.rows,
  });

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    List<FlSpot> spots = [];
    
    for (Map<String, dynamic> row in rows) {
      num timestamp = row['timestamp'];
      num laneOffset = row['lane_offset_px'];
      
      FlSpot spot = FlSpot(
        timestamp.toDouble(),
        laneOffset.toDouble(),
      );
      
      spots.add(spot);
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            isCurved: false,
            spots: spots,
            dotData: FlDotData(
              show: false,
            ),
            barWidth: 2,
          ),
        ],
        titlesData: const FlTitlesData(
          show: false,
        ),
        gridData: const FlGridData(
          show: false,
        ),
        borderData: FlBorderData(
          show: false,
        ),
      ),
    );
  }
}
