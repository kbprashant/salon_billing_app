import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String uid = FirebaseAuth.instance.currentUser!.uid;
  String selectedFilter = 'Today'; // Default to Today
  DateTimeRange? customRange;

  List<QueryDocumentSnapshot> bills = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() async {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now; // Initialize endDate for the query

    if (selectedFilter == 'Today') {
      startDate = DateTime(now.year, now.month, now.day); // Start of today
      endDate = DateTime(now.year, now.month, now.day); // End of today
    } else if (selectedFilter == '7 Days') {
      startDate = now.subtract(const Duration(days: 6)); // Includes today
    } else if (selectedFilter == '30 Days') {
      startDate = now.subtract(const Duration(days: 29)); // Includes today
    } else if (selectedFilter == 'Custom' && customRange != null) {
      startDate = customRange!.start;
      endDate = customRange!.end;
    } else {
      // Default case if selectedFilter somehow gets an unexpected value
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day);
    }

    // Adjust endDate to include the full last day of the selected period
    // by setting it just before the start of the *next* day.
    endDate = endDate
        .add(const Duration(days: 1))
        .subtract(const Duration(microseconds: 1));

    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('bills')
              .where('uid', isEqualTo: uid)
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
              )
              .where(
                'timestamp',
                isLessThanOrEqualTo: Timestamp.fromDate(endDate),
              )
              .orderBy(
                'timestamp',
              ) // Still ordering by timestamp for daily display
              .get();

      setState(() {
        bills = snap.docs;
      });
    } catch (e) {
      // It's good practice to log or show an error to the user
      debugPrint('Error loading bills: $e');
      if (e.toString().contains('requires an index')) {
        // Provide the user with guidance to create the index
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Analytics data needs a Firestore index. Please check your console for details."
              "\n${e.toString().split('create it here: ')[1].split(', cause=null')[0]}", // Extract URL
            ),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  void selectCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023), // Adjust as needed
      lastDate: DateTime.now().add(
        const Duration(days: 1),
      ), // Allow picking today
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE53935), // Red primary color for date picker
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A), // Dark surface for date picker
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(
              0xFF1A1A1A,
            ), // Background of the date picker dialog
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        customRange = picked;
        selectedFilter = 'Custom';
      });
      loadData();
    }
  }

  int get totalRevenue => bills.fold(0, (sum, b) => sum + (b['total'] as int));
  double get avgBill => bills.isEmpty ? 0 : totalRevenue / bills.length;

  Map<String, int> get serviceCounts {
    final map = <String, int>{};
    for (var bill in bills) {
      final services = List.from(bill['services']);
      for (var s in services) {
        final name = s['name'];
        map[name] = (map[name] ?? 0) + 1;
      }
    }
    return map;
  }

  // This method provides daily aggregated spots for the line chart
  List<FlSpot> getDailySpots() {
    final grouped = <String, int>{};

    for (var bill in bills) {
      final date = DateFormat(
        'yyyy-MM-dd',
      ).format((bill['timestamp'] as Timestamp).toDate());
      grouped[date] = (grouped[date] ?? 0) + (bill['total'] as int);
    }

    final sortedKeys = grouped.keys.toList()..sort();
    return List.generate(
      sortedKeys.length,
      (i) => FlSpot(i.toDouble(), grouped[sortedKeys[i]]!.toDouble()),
    );
  }

  // Helper to get sorted labels for chart x-axis based on the current filter
  List<String> _getSortedLabelsForChart() {
    if (selectedFilter == 'Today') {
      return [DateFormat('yyyy-MM-dd').format(DateTime.now())];
    } else {
      final groupedDates = <String, int>{};
      for (var bill in bills) {
        final date = (bill['timestamp'] as Timestamp).toDate();
        groupedDates[DateFormat('yyyy-MM-dd').format(date)] = 0;
      }
      return groupedDates.keys.toList()..sort();
    }
  }

  // Define pieColors globally or as a constant list
  final List<Color> pieColors = [
    const Color(0xFFE53935), // Red from HistoryPage
    Colors.pinkAccent,
    Colors.deepOrange,
    Colors.teal,
    Colors.amber,
    Colors.blue,
    Colors.purple,
    Colors.green,
  ];

  List<PieChartSectionData> getPieData() {
    final total = serviceCounts.values.fold(0, (sum, v) => sum + v);
    int i = 0;

    return serviceCounts.entries.map((e) {
      final value = (e.value / total) * 100;
      final color = pieColors[i++ % pieColors.length];
      return PieChartSectionData(
        // Set title to empty or just percentage for better clarity when legend is used
        title:
            value.toStringAsFixed(1) == '0.0'
                ? ''
                : "${value.toStringAsFixed(1)}%",
        value: value,
        color: color,
        radius: 70, // Keep this fairly large for visual impact
        titleStyle: const TextStyle(
          fontSize: 12, // Slightly smaller since the full text is in legend
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();
  }

  Widget buildThemedCard(Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C), // Dark background from HistoryPage
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget filterChips() {
    final filters = ['Today', '7 Days', '30 Days', 'Custom'];
    return Wrap(
      spacing: 8,
      children:
          filters.map((f) {
            final selected = f == selectedFilter;
            return ChoiceChip(
              label: Text(f),
              selected: selected,
              onSelected: (_) {
                if (f == 'Custom') {
                  selectCustomRange();
                } else {
                  setState(() {
                    selectedFilter = f;
                    customRange = null;
                  });
                  loadData();
                }
              },
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.white70,
              ),
              selectedColor: const Color(0xFFE53935),
              backgroundColor: const Color(0xFF2C2C2C),
            );
          }).toList(),
    );
  }

  String _getGraphTitle() {
    switch (selectedFilter) {
      case 'Today':
        return 'Today\'s Revenue';
      case '7 Days':
        return 'Revenue for the Last 7 Days';
      case '30 Days':
        return 'Revenue for the Last 30 Days';
      case 'Custom':
        if (customRange != null) {
          final startDateFormatted = DateFormat(
            'dd MMM',
          ).format(customRange!.start);
          final endDateFormatted = DateFormat(
            'dd MMM',
          ).format(customRange!.end);
          return 'Revenue from $startDateFormatted to $endDateFormatted';
        }
        return 'Custom Range Revenue';
      default:
        return 'Daily Revenue';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Solid black background, like HistoryPage
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Analytics',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            filterChips(),
            const SizedBox(height: 16),
            buildThemedCard(
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statTile('Revenue', '₹$totalRevenue'),
                  _statTile('Bills', '${bills.length}'),
                  _statTile('Avg', '₹${avgBill.toStringAsFixed(1)}'),
                ],
              ),
            ),
            if (bills.isNotEmpty) ...[
              const SizedBox(height: 24),
              buildThemedCard(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic Graph Title
                    Text(
                      _getGraphTitle(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18, // Bigger
                        fontWeight: FontWeight.bold, // Bold
                      ),
                    ),
                    SizedBox(
                      height: 200,
                      child: _LineChart(
                        dailySpots: getDailySpots(),
                        chartType: selectedFilter,
                        sortedDatesOrLabels: _getSortedLabelsForChart(),
                        lineColor: const Color(0xFFE53935),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              buildThemedCard(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Services Text Bigger and Bold
                    const Text(
                      'Top Services',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18, // Bigger
                        fontWeight: FontWeight.bold, // Bold
                      ),
                    ),
                    SizedBox(
                      height: 200, // Adjust height if needed
                      child: PieChart(
                        PieChartData(
                          sections: getPieData(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          // You can remove the touch functions if not needed,
                          // as interaction might be less relevant without labels on slices
                          // If you want tooltips on touch, you'll need to implement that
                        ),
                      ),
                    ),
                    // Add the legend below the pie chart
                    _buildServiceLegend(),
                  ],
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  "No data for this range.",
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // New method to build the legend
  Widget _buildServiceLegend() {
    if (serviceCounts.isEmpty) {
      return const SizedBox.shrink(); // Don't show legend if no services
    }

    final total = serviceCounts.values.fold(0, (sum, v) => sum + v);
    int colorIndex = 0;

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            serviceCounts.entries.map((entry) {
              final serviceName = entry.key;
              final count = entry.value;
              final percentage = (count / total) * 100;
              final color = pieColors[colorIndex++ % pieColors.length];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$serviceName (${percentage.toStringAsFixed(1)}%)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<FlSpot> dailySpots;
  final String chartType;
  final List<String> sortedDatesOrLabels;
  final Color lineColor;

  const _LineChart({
    super.key,
    required this.dailySpots,
    required this.chartType,
    required this.sortedDatesOrLabels,
    this.lineColor = Colors.redAccent,
  });

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: dailySpots,
            isCurved: true,
            color: lineColor,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: lineColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
          ),
        ],
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 ||
                    value.toInt() >= sortedDatesOrLabels.length) {
                  return const Text('');
                }
                String labelText = sortedDatesOrLabels[value.toInt()];

                if (chartType == 'Today') {
                  // If chartType is 'Today', we want to show the specific time if a bill exists
                  // The dailySpots list will only have one element for 'Today'
                  // We need to get the timestamp from the actual bill for that spot
                  // This is a bit tricky with current getDailySpots aggregating by day.
                  // For a single day, if you want specific time on X-axis, you'd need hourly spots.
                  // For now, it will show "08 PM" as per your original request,
                  // but if multiple bills existed today, this logic wouldn't show multiple times.
                  // For simplicity, keeping it to show a generic time if it's 'Today' filter.
                  return Text(
                    DateFormat(
                      'hh a',
                    ).format(DateTime.now()), // Example: "08 PM"
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  );
                } else {
                  final date = DateTime.parse(labelText);
                  return Text(
                    DateFormat('dd MMM').format(date),
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  );
                }
              },
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '₹${value.toInt()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                );
              },
              reservedSize: 40,
              interval:
                  dailySpots.isNotEmpty
                      ? (dailySpots
                                  .map((e) => e.y)
                                  .reduce((a, b) => a > b ? a : b) /
                              4)
                          .ceilToDouble()
                      : 1,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Colors.white12, strokeWidth: 1);
          },
          getDrawingVerticalLine: (value) {
            return const FlLine(color: Colors.white12, strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: const Color(0xFFE53935).withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
    );
  }
}
