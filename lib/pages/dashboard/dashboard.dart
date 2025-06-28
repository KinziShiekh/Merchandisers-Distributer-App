import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// Fixed typo
import 'package:merchandiser_app/contant/colors.dart';
import 'package:merchandiser_app/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _dataFuture;
  DateTime? _selectedSingleDate;
  DateTimeRange? _selectedDateRange;
  bool _isRangeMode = false;

  @override
  void initState() {
    super.initState();
    _selectedSingleDate = DateTime.now(); // Default to current day
    _dataFuture = _fetchDashboardData();
  }

  Future<Map<String, dynamic>> _fetchDashboardData() async {
    final userProvider = context.read<UserProvider>();
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) throw Exception('User not logged in');

    try {
      var merchandiserSnapshot = await FirebaseFirestore.instance
          .collection('Merchandiser')
          .where('authId', isEqualTo: uid) // Updated to authId for consistency
          .limit(1)
          .get();

      var shopsSnapshot = await FirebaseFirestore.instance
          .collection('Shops')
          .where('assignedMerchandisers',
              isEqualTo: userProvider.merchandiserName)
          .get();

      var goalsSnapshot = await FirebaseFirestore.instance
          .collection('MerchandiserGoal')
          .where('merchandiserId', isEqualTo: uid)
          .get();

      return {
        'merchandiserSnapshot': merchandiserSnapshot,
        'shopsSnapshot': shopsSnapshot,
        'goalsSnapshot': goalsSnapshot,
      };
    } catch (e) {
      debugPrint("Firestore Error: $e");
      rethrow;
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> filterShopsByDate(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> shops) {
    if (_selectedSingleDate != null) {
      String selectedDateStr =
          DateFormat('yyyy-MM-dd').format(_selectedSingleDate!);
      return shops
          .where((shop) => shop.data()['scheduledDate'] == selectedDateStr)
          .toList();
    } else if (_selectedDateRange != null) {
      DateTime start = _selectedDateRange!.start;
      DateTime end = _selectedDateRange!.end;
      return shops.where((shop) {
        DateTime scheduledDate =
            DateTime.parse(shop.data()['scheduledDate'] as String);
        return scheduledDate.isAfter(start.subtract(const Duration(days: 1))) &&
            scheduledDate.isBefore(end.add(const Duration(days: 1)));
      }).toList();
    }
    return shops; // No filter applied
  }

  Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getFilteredDayShops(
          List<QueryDocumentSnapshot<Map<String, dynamic>>> shops) {
    var filteredShops = filterShopsByDate(shops);
    return {
      'Sunday': filterShopsByDay(filteredShops, 'Sunday'),
      'Monday': filterShopsByDay(filteredShops, 'Monday'),
      'Tuesday': filterShopsByDay(filteredShops, 'Tuesday'),
      'Wednesday': filterShopsByDay(filteredShops, 'Wednesday'),
      'Thursday': filterShopsByDay(filteredShops, 'Thursday'),
      'Friday': filterShopsByDay(filteredShops, 'Friday'),
      'Saturday': filterShopsByDay(filteredShops, 'Saturday'),
    };
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> filterShopsByDay(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> shops, String day) {
    return shops.where((shop) => shop.data()['day'] == day).toList();
  }

  double calculateStrikeRate(int totalCount, int visitedCount) {
    return totalCount == 0 ? 0.0 : (visitedCount / totalCount) * 100;
  }

  int countVisitedShops(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> shops) {
    return shops.where((shop) => shop.data()['visited'] == true).length;
  }

  double calculateTotalStrikeRate(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> shops) {
    int totalShops = shops.length;
    int totalVisited = countVisitedShops(shops);
    return calculateStrikeRate(totalShops, totalVisited);
  }

  Future<void> _refreshData() async {
    setState(() {
      _dataFuture = _fetchDashboardData();
    });
  }

  void _showDatePicker(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    bool isRangeModeLocal = _isRangeMode;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Container(
            width: screenWidth > 600 ? screenWidth * 0.5 : screenWidth * 0.9,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  isRangeModeLocal ? 'Select Date Range' : 'Select Date',
                  style: GoogleFonts.poppins(
                    fontSize: screenWidth > 800
                        ? 24
                        : screenWidth > 600
                            ? 20
                            : 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.MainColor,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: screenWidth > 800
                      ? 400
                      : screenWidth > 600
                          ? 350
                          : 300,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SfDateRangePicker(
                    onSelectionChanged:
                        (DateRangePickerSelectionChangedArgs args) {
                      setState(() {
                        if (isRangeModeLocal && args.value is PickerDateRange) {
                          _selectedDateRange = DateTimeRange(
                            start: args.value.startDate,
                            end: args.value.endDate ?? args.value.startDate,
                          );
                          _selectedSingleDate = null;
                        } else if (!isRangeModeLocal &&
                            args.value is DateTime) {
                          _selectedSingleDate = args.value;
                          _selectedDateRange = null;
                        }
                        _isRangeMode = isRangeModeLocal;
                      });
                    },
                    selectionMode: isRangeModeLocal
                        ? DateRangePickerSelectionMode.range
                        : DateRangePickerSelectionMode.single,
                    initialSelectedDate: _selectedSingleDate ?? DateTime.now(),
                    initialSelectedRange: isRangeModeLocal
                        ? PickerDateRange(
                            _selectedDateRange?.start ??
                                DateTime.now()
                                    .subtract(const Duration(days: 7)),
                            _selectedDateRange?.end ?? DateTime.now())
                        : null,
                    backgroundColor: Colors.transparent,
                    todayHighlightColor: AppColors.MainColor,
                    selectionColor: AppColors.MainColor.withOpacity(0.3),
                    rangeSelectionColor: AppColors.MainColor.withOpacity(0.2),
                    startRangeSelectionColor: AppColors.MainColor,
                    endRangeSelectionColor: AppColors.MainColor,
                    headerStyle: DateRangePickerHeaderStyle(
                      textAlign: TextAlign.center,
                      textStyle: GoogleFonts.poppins(
                        fontSize: screenWidth > 800 ? 18 : 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.MainColor,
                      ),
                    ),
                    monthCellStyle: DateRangePickerMonthCellStyle(
                      textStyle: GoogleFonts.poppins(
                        fontSize: screenWidth > 800
                            ? 16
                            : screenWidth > 600
                                ? 14
                                : 12,
                        color: AppColors.MainColor,
                      ),
                      todayTextStyle: GoogleFonts.poppins(
                        fontSize: screenWidth > 800
                            ? 16
                            : screenWidth > 600
                                ? 14
                                : 12,
                        color: AppColors.MainColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedSingleDate = DateTime.now();
                          _selectedDateRange = null;
                          _isRangeMode = false;
                        });
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Reset to Today',
                        style: GoogleFonts.poppins(
                          fontSize: screenWidth > 800 ? 16 : 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setDialogState(() {
                          isRangeModeLocal = !isRangeModeLocal;
                        });
                        setState(() {
                          _isRangeMode = isRangeModeLocal;
                          _selectedSingleDate = null;
                          _selectedDateRange = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.MainColor.withOpacity(0.1),
                        foregroundColor: AppColors.MainColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isRangeModeLocal
                                ? Icons.calendar_today
                                : Icons.date_range,
                            size: screenWidth > 800 ? 20 : 18,
                            color: AppColors.MainColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isRangeModeLocal ? 'Single Date' : 'Date Range',
                            style: GoogleFonts.poppins(
                              fontSize: screenWidth > 800 ? 16 : 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.MainColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.MainColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: Text(
                        'OK',
                        style: GoogleFonts.poppins(
                          fontSize: screenWidth > 800 ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Dashboard',
            style: GoogleFonts.poppins(
              color: AppColors.MainColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          foregroundColor: AppColors.MainColor,
          elevation: 2,
        ),
        body: const Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Dashboard',
          style: GoogleFonts.poppins(
            color: AppColors.MainColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        foregroundColor: AppColors.MainColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Filter by Date',
            onPressed: () => _showDatePicker(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.MainColor,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.MainColor)));
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.red),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: Text('No data found'));
            }

            var merchandiserSnapshot = snapshot.data!['merchandiserSnapshot']
                as QuerySnapshot<Map<String, dynamic>>;
            var shopsSnapshot = snapshot.data!['shopsSnapshot']
                as QuerySnapshot<Map<String, dynamic>>;
            var goalsSnapshot = snapshot.data!['goalsSnapshot']
                as QuerySnapshot<Map<String, dynamic>>;

            if (merchandiserSnapshot.docs.isEmpty &&
                shopsSnapshot.docs.isEmpty) {
              return const Center(child: Text('No data found for this user'));
            }

            var filteredShops = filterShopsByDate(shopsSnapshot.docs);
            var dayShops = getFilteredDayShops(shopsSnapshot.docs);
            double totalStrikeRate = calculateTotalStrikeRate(filteredShops);
            String currentDay = DateFormat('EEEE')
                .format(_selectedSingleDate ?? DateTime.now());

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display current filter status
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedSingleDate != null
                                ? 'Showing: ${DateFormat('MMM d, yyyy').format(_selectedSingleDate!)}'
                                : _selectedDateRange != null
                                    ? 'Showing: ${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, yyyy').format(_selectedDateRange!.end)}'
                                    : 'Showing: Today (${DateFormat('MMM d, yyyy').format(DateTime.now())})',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.MainColor,
                            ),
                          ),
                          if (_selectedSingleDate != null ||
                              _selectedDateRange != null)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedSingleDate = DateTime.now();
                                  _selectedDateRange = null;
                                  _isRangeMode = false;
                                });
                              },
                              child: Text(
                                'Reset to Today',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.grey[100]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        color: Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.trending_up,
                                      color: AppColors.MainColor, size: 28),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Total Strike Rate",
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.MainColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularPercentIndicator(
                                    radius: 80.0,
                                    lineWidth: 14.0,
                                    animation: true,
                                    animationDuration: 1000,
                                    percent: totalStrikeRate / 100,
                                    center: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "${totalStrikeRate.toStringAsFixed(1)}%",
                                          style: GoogleFonts.poppins(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.MainColor,
                                          ),
                                        ),
                                        Text(
                                          totalStrikeRate == 100.0
                                              ? "Perfect!"
                                              : "Keep Going!",
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: AppColors.MainColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    progressColor: AppColors.MainColor,
                                    backgroundColor: Colors.grey[300]!,
                                    circularStrokeCap: CircularStrokeCap.round,
                                    footer: Padding(
                                      padding: const EdgeInsets.only(top: 12.0),
                                      child: Text(
                                        _selectedSingleDate != null
                                            ? "$currentDay's Performance"
                                            : _selectedDateRange != null
                                                ? "Range Performance"
                                                : "Today's Performance",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: AppColors.MainColor,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (totalStrikeRate == 100.0)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.9),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          "Goal Achieved",
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(
                      _selectedSingleDate != null
                          ? "$currentDay's Performance"
                          : _selectedDateRange != null
                              ? "Performance in Range"
                              : "Today's Performance",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.MainColor,
                      ),
                    ),
                    const SizedBox(height: 15),
                    if (dayShops.isNotEmpty)
                      ...dayShops.entries
                          .where((entry) => entry.value.isNotEmpty)
                          .map((entry) => _buildDaySummary(
                              entry.key,
                              entry.value.length,
                              countVisitedShops(entry.value))),
                    if (dayShops.values.every((shops) => shops.isEmpty))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          "No shops scheduled for this period",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: AppColors.MainColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    if (goalsSnapshot.docs.isNotEmpty) ...[
                      const SizedBox(height: 25),
                      Text(
                        "Your Goals",
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.MainColor,
                        ),
                      ),
                      const SizedBox(height: 15),
                      ...goalsSnapshot.docs.map((goal) {
                        var goalData = goal.data();
                        return Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: const Icon(Icons.flag_rounded,
                                color: AppColors.MainColor, size: 28),
                            title: Text(
                              goalData['goalDescription'] ?? 'No Description',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.MainColor,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                "Target: ${goalData['targetStrikeRate']?.toString() ?? 'N/A'}%",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.MainColor,
                                ),
                              ),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.grey[400]),
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDaySummary(String day, int totalCount, int visitedCount) {
    double strikeRate = calculateStrikeRate(totalCount, visitedCount);
    bool isGoalAchieved = strikeRate == 100.0;

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 22, color: AppColors.MainColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          day,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.MainColor,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              "${strikeRate.toStringAsFixed(1)}%",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.MainColor,
                              ),
                            ),
                            if (isGoalAchieved) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "Goal Achieved",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          "Visited: $visitedCount/$totalCount",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.MainColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: strikeRate / 100,
                      backgroundColor: Colors.grey[300],
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.MainColor),
                      minHeight: 5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
