import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryPage extends StatefulWidget {
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime? selectedDate;
  late final String uid;
  String? searchQuery; // To store the search query
  final TextEditingController _searchController =
      TextEditingController(); // Controller for search bar

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
    selectedDate = DateTime.now(); // Initialize to today's date
  }

  @override
  void dispose() {
    _searchController.dispose(); // Dispose the controller when done
    super.dispose();
  }

  String formatDate(Timestamp ts) => DateFormat('M/d/yyyy').format(ts.toDate());

  // Helper to format the displayed date for the header
  String _formatDisplayDate(DateTime date) {
    if (date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day) {
      return 'Today\'s Bills';
    } else if (date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day - 1) {
      return 'Yesterday\'s Bills';
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ), // Allow picking up to a year in future
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
        selectedDate = picked;
      });
    }
  }

  bool sameDay(Timestamp ts, DateTime? dateFilter) {
    if (dateFilter == null) return true; // No date filter applied
    final d = ts.toDate();
    return d.year == dateFilter.year &&
        d.month == dateFilter.month &&
        d.day == dateFilter.day;
  }

  bool matchesSearch(DocumentSnapshot bill) {
    if (searchQuery == null || searchQuery!.isEmpty) {
      return true;
    }
    final query = searchQuery!.toLowerCase();
    final name = bill['name']?.toString().toLowerCase() ?? '';
    final phone = bill['phone']?.toString().toLowerCase() ?? '';
    final services = List.from(
      bill['services'] ?? [],
    ).map((s) => s['name']?.toString().toLowerCase() ?? '').join(' ');
    return name.contains(query) ||
        phone.contains(query) ||
        services.contains(query);
  }

  void _navigateToPreviousDay() {
    setState(() {
      selectedDate = selectedDate?.subtract(const Duration(days: 1));
    });
  }

  void _navigateToNextDay() {
    setState(() {
      selectedDate = selectedDate?.add(const Duration(days: 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background for the entire page
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: MediaQuery.of(context).padding.top,
            ), // For status bar clear
            const SizedBox(height: 20),

            // Combined Search Bar and Filter Button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: const Color(0xFF2C2C2C),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by name, phone, or service...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  suffixIcon:
                      selectedDate != null
                          ? IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              setState(() {
                                selectedDate = null; // Clear date filter
                              });
                            },
                          )
                          : IconButton(
                            icon: const Icon(
                              Icons.calendar_today,
                              color: Colors.white70,
                            ),
                            onPressed: pickDate,
                          ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date Navigation and Daily Earnings
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('bills')
                      .where('uid', isEqualTo: uid)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final dailyBills =
                    snapshot.data!.docs
                        .where((doc) => sameDay(doc['timestamp'], selectedDate))
                        .toList();

                double dailyEarnings = 0.0;
                for (var bill in dailyBills) {
                  dailyEarnings += (bill['total'] as num?)?.toDouble() ?? 0.0;
                }

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white70,
                          ),
                          onPressed: _navigateToPreviousDay,
                        ),
                        Text(
                          _formatDisplayDate(selectedDate ?? DateTime.now()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white70,
                          ),
                          onPressed: _navigateToNextDay,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFE53935,
                        ).withOpacity(0.2), // Light red background
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.attach_money,
                            color: Color(0xFFE53935),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Daily Earnings: Rs. ${dailyEarnings.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFFE53935), // Red text
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('bills')
                        .where('uid', isEqualTo: uid)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        'Error loading data: ${snap.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs =
                      snap.data!.docs
                          .where(
                            (d) =>
                                sameDay(d['timestamp'], selectedDate) &&
                                matchesSearch(d),
                          )
                          .toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        selectedDate == null
                            ? 'No bills found.'
                            : 'No bills found for ${_formatDisplayDate(selectedDate!)}',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final b = docs[i];
                      final services =
                          List.from(
                            b['services'] ?? [],
                          ).map((s) => s['name'].toString()).toList();
                      final total = b['total']?.toDouble();

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        color: const Color(0xFF2C2C2C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 5,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    b['name']?.toString() ?? 'N/A',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.phone,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    b['phone']?.toString() ?? 'N/A',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatDate(b['timestamp']),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Rs. ${total?.toStringAsFixed(2) ?? '0.00'}',
                                    style: const TextStyle(
                                      color: Color(0xFFE53935),
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Divider(color: Colors.white.withOpacity(0.2)),
                              ...services.map((serviceName) {
                                final serviceData = List.from(
                                  b['services'] ?? [],
                                ).firstWhere(
                                  (s) => s['name'] == serviceName,
                                  orElse: () => {'price': 0.0},
                                );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.chevron_right,
                                        color: Colors.white54,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          serviceName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Rs. ${serviceData['price']?.toStringAsFixed(2) ?? '0.00'}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
