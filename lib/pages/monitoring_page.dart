import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key});

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  List<Map<String, dynamic>> historicalData = [];
  late TabController _tabController;
  List<String> availableMetrics = [];
  List<String> selectedMetrics = [];

  // Define the allowed metrics - only these will be shown
  static const List<String> allowedMetrics = [
    'Tair_f_tavg',
    'Wind_f_tavg',
    'Psurf_f_tavg',
    'Qair_f_tavg',
    'Rainf_f_tavg',
    'SWdown_f_tavg',
    'temperature',
    'humidity',
    'soil_moisture',
  ];

  // Available chart types
  String selectedChartType = 'line';
  final List<Map<String, String>> chartTypes = [
    {'key': 'line', 'name': 'Line Chart', 'icon': 'Icons.show_chart'},
    {'key': 'bar', 'name': 'Bar Chart', 'icon': 'Icons.bar_chart'},
    {'key': 'pie', 'name': 'Pie Chart', 'icon': 'Icons.pie_chart'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistoricalData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadHistoricalData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final dbRef = FirebaseDatabase.instance.ref('Data/${user.uid}/');

      dbRef.onValue.listen((event) {
        if (event.snapshot.exists) {
          final dataMap = Map<String, dynamic>.from(
            event.snapshot.value as Map,
          );

          List<Map<String, dynamic>> tempData = [];
          Set<String> metrics = {};

          dataMap.forEach((key, value) {
            final dataEntry = Map<String, dynamic>.from(value);
            tempData.add({'timestamp': key, 'data': dataEntry});
            // Only add metrics that are in our allowed list
            metrics.addAll(dataEntry.keys.where((key) => allowedMetrics.contains(key)));
          });

          tempData.sort(
            (a, b) => parseKeyToDateTime(
              b['timestamp'],
            ).compareTo(parseKeyToDateTime(a['timestamp'])),
          );

          setState(() {
            historicalData = tempData;
            // Filter available metrics to only include allowed ones that have numeric data
            availableMetrics = metrics
                .where((metric) => allowedMetrics.contains(metric) && _isNumericMetric(tempData, metric))
                .toList();
            
            // Initialize selected metrics with available ones from our allowed list
            if (availableMetrics.isNotEmpty && selectedMetrics.isEmpty) {
              selectedMetrics = availableMetrics.take(3).toList(); // Start with first 3 available metrics
            }

            isLoading = false;
          });
        } else {
          setState(() {
            historicalData = [];
            availableMetrics = [];
            isLoading = false;
          });
        }
      });
    }
  }

  bool _isNumericMetric(List<Map<String, dynamic>> data, String metric) {
    for (var item in data) {
      final value = item['data'][metric];
      if (value != null) {
        final numValue = double.tryParse(value.toString());
        if (numValue != null) return true;
      }
    }
    return false;
  }

  DateTime parseKeyToDateTime(String key) {
    try {
      String isoLikeKey = key.replaceAll('_', ':');
      int lastColon = isoLikeKey.lastIndexOf(':');
      if (lastColon != -1) {
        isoLikeKey = isoLikeKey.replaceRange(lastColon, lastColon + 1, '.');
      }
      return DateTime.parse(isoLikeKey).toLocal();
    } catch (_) {
      return DateTime(1900);
    }
  }

  String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  // Helper method to get a user-friendly name for metrics
  String getMetricDisplayName(String metric) {
    const Map<String, String> metricNames = {
      'Tair_f_tavg': 'Air Temperature',
      'Wind_f_tavg': 'Wind Speed',
      'Psurf_f_tavg': 'Surface Pressure',
      'Qair_f_tavg': 'Air Humidity',
      'Rainf_f_tavg': 'Rainfall',
      'SWdown_f_tavg': 'Solar Radiation',
      'temperature': 'Temperature',
      'humidity': 'Humidity',
      'soil_moisture': 'Soil Moisture',
    };
    return metricNames[metric] ?? metric;
  }

  Map<String, List<FlSpot>> _getChartDataPerMetric() {
    final Map<String, List<FlSpot>> dataMap = {};
    final dataToShow =
        historicalData.reversed.take(20).toList().reversed.toList();

    for (var metric in selectedMetrics) {
      List<FlSpot> spots = [];
      for (int i = 0; i < dataToShow.length; i++) {
        final item = dataToShow[i];
        final value = item['data'][metric];
        if (value != null) {
          final numValue = double.tryParse(value.toString());
          if (numValue != null) {
            spots.add(FlSpot(i.toDouble(), numValue));
          }
        }
      }
      if (spots.isNotEmpty) {
        dataMap[metric] = spots;
      }
    }

    return dataMap;
  }

  List<BarChartGroupData> _getBarChartData() {
    List<BarChartGroupData> barGroups = [];
    final dataToShow =
        historicalData.reversed.take(10).toList().reversed.toList();

    for (int i = 0; i < dataToShow.length; i++) {
      List<BarChartRodData> rods = [];
      for (int j = 0; j < selectedMetrics.length; j++) {
        final metric = selectedMetrics[j];
        final value = dataToShow[i]['data'][metric];
        if (value != null) {
          final numValue = double.tryParse(value.toString()) ?? 0;
          rods.add(
            BarChartRodData(
              toY: numValue,
              color: _colorForMetric(metric),
              width: 8,
            ),
          );
        }
      }
      barGroups.add(BarChartGroupData(x: i, barRods: rods));
    }

    return barGroups;
  }

  List<PieChartSectionData> _getPieChartData() {
    List<PieChartSectionData> sections = [];

    // Use latest values for pie chart
    if (historicalData.isNotEmpty) {
      final latestData = historicalData.first['data'] as Map<String, dynamic>;

      double total = 0;
      Map<String, double> metricValues = {};

      for (var metric in selectedMetrics) {
        final value = latestData[metric];
        if (value != null) {
          final numValue = double.tryParse(value.toString()) ?? 0;
          if (numValue > 0) {
            metricValues[metric] = numValue;
            total += numValue;
          }
        }
      }

      int index = 0;
      metricValues.forEach((metric, value) {
        final percentage = (value / total) * 100;
        sections.add(
          PieChartSectionData(
            color: _colorForMetric(metric),
            value: value,
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
        index++;
      });
    }

    return sections;
  }

  Color _colorForMetric(String metric) {
    const Map<String, Color> metricColors = {
      'Tair_f_tavg': Colors.red,
      'Wind_f_tavg': Colors.blue,
      'Psurf_f_tavg': Colors.green,
      'Qair_f_tavg': Colors.orange,
      'Rainf_f_tavg': Colors.purple,
      'SWdown_f_tavg': Colors.amber,
      'temperature': Colors.deepOrange,
      'humidity': Colors.cyan,
      'soil_moisture': Colors.brown,
    };
    return metricColors[metric] ?? Colors.grey;
  }

  Widget _buildChartTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chart Type:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  chartTypes.map((type) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(type['name']!),
                        selected: selectedChartType == type['key'],
                        onSelected: (bool selected) {
                          if (selected) {
                            setState(() {
                              selectedChartType = type['key']!;
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Metrics to Display:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableMetrics.map((metric) {
              return FilterChip(
                label: Text(
                  getMetricDisplayName(metric),
                  style: const TextStyle(fontSize: 12),
                ),
                selected: selectedMetrics.contains(metric),
                selectedColor: _colorForMetric(metric).withOpacity(0.3),
                checkmarkColor: _colorForMetric(metric),
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      selectedMetrics.add(metric);
                    } else {
                      selectedMetrics.remove(metric);
                      if (selectedMetrics.isEmpty && availableMetrics.isNotEmpty) {
                        selectedMetrics.add(availableMetrics.first);
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
          if (selectedMetrics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '${selectedMetrics.length} metric(s) selected',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (selectedMetrics.isEmpty) {
      return const Center(child: Text('No metrics selected'));
    }

    switch (selectedChartType) {
      case 'line':
        return _buildLineChart();
      case 'bar':
        return _buildBarChart();
      case 'pie':
        return _buildPieChart();
      default:
        return _buildLineChart();
    }
  }

  Widget _buildLineChart() {
    final chartData = _getChartDataPerMetric();
    if (chartData.isEmpty) {
      return const Center(
        child: Text('No valid data for selected metrics'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < historicalData.length) {
                    final item =
                        historicalData.reversed
                            .take(20)
                            .toList()
                            .reversed
                            .toList()[index];
                    final date = parseKeyToDateTime(item['timestamp']);
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        DateFormat('HH:mm').format(date),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget:
                    (value, meta) => Text(
                      value.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 10),
                    ),
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData:
              chartData.entries.map((entry) {
                return LineChartBarData(
                  spots: entry.value,
                  isCurved: true,
                  color: _colorForMetric(entry.key),
                  barWidth: 3,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    final barData = _getBarChartData();
    if (barData.isEmpty) {
      return const Center(
        child: Text('No valid data for selected metrics'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      height: 300,
      child: BarChart(
        BarChartData(
          barGroups: barData,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < historicalData.length) {
                    final item =
                        historicalData.reversed
                            .take(10)
                            .toList()
                            .reversed
                            .toList()[index];
                    final date = parseKeyToDateTime(item['timestamp']);
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        DateFormat('HH:mm').format(date),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget:
                    (value, meta) => Text(
                      value.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 10),
                    ),
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          // borderData: FlBorderdata(show: true),
          gridData: FlGridData(show: true),
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final pieData = _getPieChartData();
    if (pieData.isEmpty) {
      return const Center(
        child: Text('No valid data for selected metrics'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      height: 300,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sections: pieData,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  selectedMetrics.map((metric) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            color: _colorForMetric(metric),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              getMetricDisplayName(metric),
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildChartTypeSelector(),
          _buildMetricSelector(),
          const SizedBox(height: 20),
          _buildChart(),
        ],
      ),
    );
  }

  Widget _buildDataList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: historicalData.length,
      itemBuilder: (context, index) {
        final item = historicalData[index];
        final timestamp = item['timestamp'] as String;
        final data = item['data'] as Map<String, dynamic>;
        final dateTime = parseKeyToDateTime(timestamp);

        // Filter data to only show allowed metrics
        final filteredData = Map<String, dynamic>.fromEntries(
          data.entries.where((entry) => allowedMetrics.contains(entry.key))
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with date and badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF009688).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.schedule,
                            color: Color(0xFF009688),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formatDateTime(dateTime),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF009688),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${filteredData.length} items',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Styled divider
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.grey.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Enhanced data table
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(3),
                    },
                    children: [
                      // Table header
                      TableRow(
                        decoration: BoxDecoration(
                          color: const Color(0xFF009688).withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Parameter',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: const Color(0xFF009688),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Value',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: const Color(0xFF009688),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Data rows (only filtered data)
                      ...filteredData.entries.map((entry) {
                        final isNumeric =
                            double.tryParse(entry.value.toString()) != null;
                        return TableRow(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color:
                                          isNumeric
                                              ? const Color(0xFF009688)
                                              : Colors.grey.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      getMetricDisplayName(entry.key),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isNumeric
                                          ? const Color(
                                            0xFF009688,
                                          ).withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        isNumeric
                                            ? const Color(
                                              0xFF009688,
                                            ).withOpacity(0.2)
                                            : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${entry.value}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color:
                                              isNumeric
                                                  ? const Color(0xFF009688)
                                                  : const Color(0xFF2C3E50),
                                        ),
                                      ),
                                    ),
                                    if (isNumeric)
                                      Icon(
                                        Icons.trending_up,
                                        size: 16,
                                        color: const Color(0xFF009688),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF009688),
        elevation: 0,
        title: const Text(
          'Monitoring',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Charts'),
            Tab(icon: Icon(Icons.list), text: 'Data'),
          ],
        ),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : historicalData.isEmpty
              ? const Center(child: Text('No historical data available'))
              : TabBarView(
                controller: _tabController,
                children: [_buildChartsView(), _buildDataList()],
              ),
    );
  }
}