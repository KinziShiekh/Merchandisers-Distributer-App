import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:merchandiser_app/contant/colors.dart';
import 'package:merchandiser_app/contant/images.dart';
import 'package:merchandiser_app/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:intl/intl.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _dataFuture;
  DateTime? _selectedSingleDate;
  DateTimeRange? _selectedDateRange;
  bool _isRangeMode = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _selectedSingleDate = DateTime.now();
    _dataFuture = getMerchandiserAndShopsData();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> getMerchandiserAndShopsData() async {
    final userProvider = context.read<UserProvider>();
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw Exception('User not logged in');
    }

    try {
      var merchandiserSnapshot = await FirebaseFirestore.instance
          .collection('Merchandiser')
          .where('authId', isEqualTo: uid)
          .limit(1)
          .get();

      var shopsSnapshot = await FirebaseFirestore.instance
          .collection('Shops')
          .where('assignedMerchandisers',
              isEqualTo: userProvider.merchandiserName)
          .get();

      return {
        'merchandiserSnapshot': merchandiserSnapshot,
        'shopsSnapshot': shopsSnapshot,
      };
    } catch (e) {
      debugPrint("Firestore Error: $e");
      rethrow;
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> filterShopsByDay(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> shops, String day) {
    return shops.where((shop) => shop.data()['day'] == day).toList();
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
    return shops;
  }

  Map<String, List<Map<String, dynamic>>> filterAchievedGoals(
      Map<String, List<Map<String, dynamic>>> achievedGoals) {
    if (_selectedSingleDate != null) {
      String selectedDateStr =
          DateFormat('yyyy-MM-dd').format(_selectedSingleDate!);
      return {selectedDateStr: achievedGoals[selectedDateStr] ?? []};
    } else if (_selectedDateRange != null) {
      DateTime start = _selectedDateRange!.start;
      DateTime end = _selectedDateRange!.end;
      return Map.fromEntries(
        achievedGoals.entries.where((entry) {
          DateTime goalDate = DateTime.parse(entry.key);
          return goalDate.isAfter(start.subtract(const Duration(days: 1))) &&
              goalDate.isBefore(end.add(const Duration(days: 1)));
        }),
      );
    }
    return achievedGoals;
  }

  double calculateStrikeRate(int totalCount, int visitedCount) {
    return totalCount == 0 ? 0.0 : (visitedCount / totalCount) * 100;
  }

  int countVisitedShops(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> shops) {
    return shops.where((shop) => shop.data()['visited'] == true).length;
  }

  bool isDateFullyAchieved(List<Map<String, dynamic>> goals) {
    if (goals.isEmpty) return false;
    return goals.every((goal) => goal['status'] == true);
  }

  Future<void> _refreshData() async {
    setState(() {
      _dataFuture = getMerchandiserAndShopsData();
      _animationController.reset();
      _animationController.forward();
    });
  }

  void _showDatePicker(BuildContext context) {
    bool isRangeModeLocal = _isRangeMode;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(16),
            width: MediaQuery.of(context).size.width * 0.9,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isRangeModeLocal ? 'Select Date Range' : 'Select Date',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.MainColor),
                ),
                const SizedBox(height: 12),
                SfDateRangePicker(
                  onSelectionChanged:
                      (DateRangePickerSelectionChangedArgs args) {
                    setState(() {
                      if (isRangeModeLocal && args.value is PickerDateRange) {
                        _selectedDateRange = DateTimeRange(
                          start: args.value.startDate,
                          end: args.value.endDate ?? args.value.startDate,
                        );
                        _selectedSingleDate = null;
                      } else if (!isRangeModeLocal && args.value is DateTime) {
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
                              DateTime.now().subtract(const Duration(days: 7)),
                          _selectedDateRange?.end ?? DateTime.now())
                      : null,
                  backgroundColor: Colors.grey[50],
                  todayHighlightColor: AppColors.MainColor,
                  selectionColor: AppColors.MainColor.withOpacity(0.4),
                  rangeSelectionColor: AppColors.MainColor.withOpacity(0.2),
                  headerStyle: DateRangePickerHeaderStyle(
                    textStyle: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.MainColor),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedSingleDate = DateTime.now();
                          _selectedDateRange = null;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Clear',
                          style: TextStyle(color: Colors.redAccent)),
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
                          backgroundColor:
                              AppColors.MainColor.withOpacity(0.1)),
                      child: Text(
                          isRangeModeLocal ? 'Single Date' : 'Date Range',
                          style: const TextStyle(color: AppColors.MainColor)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.MainColor),
                      child: const Text('OK',
                          style: TextStyle(color: Colors.white)),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Merchandiser Report')),
        body: const Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_sharp, color: AppColors.MainColor)),
        centerTitle: true,
        title: Text(
          'Merchandiser Report',
          style: GoogleFonts.poppins(
              fontSize: isTablet ? 20 : 20,
              fontWeight: FontWeight.bold,
              color: AppColors.MainColor),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: AppColors.MainColor),
            onPressed: () => _showDatePicker(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshData,
        backgroundColor: AppColors.MainColor,
        elevation: 0,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) => Transform.scale(
            scale: 1 + (_animationController.value * 0.1),
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.MainColor,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: FutureBuilder<Map<String, dynamic>>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.MainColor),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 40),
                      const SizedBox(height: 8),
                      Text('Error: ${snapshot.error}',
                          style: GoogleFonts.poppins(
                              fontSize: 16, color: Colors.red)),
                    ],
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
              if (merchandiserSnapshot.docs.isEmpty &&
                  shopsSnapshot.docs.isEmpty) {
                return const Center(child: Text('No data found for this user'));
              }

              Map<String, dynamic>? merchandiserData =
                  merchandiserSnapshot.docs.isNotEmpty
                      ? merchandiserSnapshot.docs.first.data()
                      : null;
              var filteredShops = filterShopsByDate(shopsSnapshot.docs);
              var sundayShops = filterShopsByDay(filteredShops, 'Sunday');
              var mondayShops = filterShopsByDay(filteredShops, 'Monday');

              var tuesdayShops = filterShopsByDay(filteredShops, 'Tuesday');
              var wednesdayShops = filterShopsByDay(filteredShops, 'Wednesday');
              var thursdayShops = filterShopsByDay(filteredShops, 'Thursday');
              var fridayShops = filterShopsByDay(filteredShops, 'Friday');
              var saturdayShops = filterShopsByDay(filteredShops, 'Saturday');

              int sundayVisited = countVisitedShops(sundayShops);
              int mondayVisited = countVisitedShops(mondayShops);
              int tuesdayVisited = countVisitedShops(tuesdayShops);
              int wednesdayVisited = countVisitedShops(wednesdayShops);
              int thursdayVisited = countVisitedShops(thursdayShops);
              int fridayVisited = countVisitedShops(fridayShops);
              int saturdayVisited = countVisitedShops(saturdayShops);

              Map<String, List<Map<String, dynamic>>> achievedGoals = {};
              if (merchandiserData != null &&
                  merchandiserData['achievedGoals'] != null) {
                try {
                  achievedGoals = Map<String, List<Map<String, dynamic>>>.from(
                    (merchandiserData['achievedGoals'] as Map).map(
                      (key, value) => MapEntry(
                        key.toString(),
                        value is List
                            ? List<Map<String, dynamic>>.from(value.map(
                                (item) =>
                                    Map<String, dynamic>.from(item as Map)))
                            : [],
                      ),
                    ),
                  );
                } catch (e) {
                  debugPrint("Error parsing achievedGoals in build: $e");
                }
              }

              var filteredAchievedGoals = filterAchievedGoals(achievedGoals);

              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 32 : 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (merchandiserData != null)
                        _buildMerchandiserInfo(merchandiserData, isTablet),
                      const SizedBox(height: 16),
                      if (_selectedSingleDate != null ||
                          _selectedDateRange != null)
                        _buildDateFilterChip(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Achieved Goals',
                          filteredAchievedGoals.length, Icons.star, isTablet),
                      const SizedBox(height: 12),
                      filteredAchievedGoals.isNotEmpty
                          ? _buildGoalsList(filteredAchievedGoals, isTablet)
                          : _buildEmptyState(
                              'No goals achieved yet', Icons.star_border),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Assigned Shops', filteredShops.length,
                          Icons.store, isTablet),
                      const SizedBox(height: 12),
                      filteredShops.isEmpty
                          ? _buildEmptyState(
                              'No shops assigned', Icons.store_outlined)
                          : _buildShopsList(
                              sundayShops,
                              mondayShops,
                              tuesdayShops,
                              wednesdayShops,
                              thursdayShops,
                              fridayShops,
                              saturdayShops,
                              sundayVisited,
                              mondayVisited,
                              tuesdayVisited,
                              wednesdayVisited,
                              thursdayVisited,
                              fridayVisited,
                              saturdayVisited,
                              isTablet,
                            ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMerchandiserInfo(Map<String, dynamic> data, bool isTablet) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: isTablet ? 30 : 24,
            backgroundColor: AppColors.Background,
            child:
                Image.asset(AppImages.merchandiser, color: AppColors.MainColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['Name'] ?? 'N/A',
                  style: GoogleFonts.poppins(
                      fontSize: isTablet ? 22 : 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.MainColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Email: ${data['Email'] ?? 'N/A'}',
                  style: GoogleFonts.poppins(
                      fontSize: isTablet ? 16 : 14, color: AppColors.MainColor),
                ),
                Text(
                  'Contact: ${data['ContactNo'] ?? 'N/A'}',
                  style: GoogleFonts.poppins(
                      fontSize: isTablet ? 16 : 14, color: AppColors.MainColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChip() {
    return Chip(
      avatar: const Icon(Icons.calendar_today,
          size: 18, color: AppColors.MainColor),
      label: Text(
        _selectedSingleDate != null
            ? 'Selected: ${DateFormat('MMM d, yyyy').format(_selectedSingleDate!)}'
            : 'Range: ${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, yyyy').format(_selectedDateRange!.end)}',
        style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.MainColor,
            fontWeight: FontWeight.w500),
      ),
      backgroundColor: AppColors.Background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildSectionTitle(
      String title, int count, IconData icon, bool isTablet) {
    return Row(
      children: [
        Icon(icon, color: AppColors.MainColor, size: isTablet ? 28 : 24),
        const SizedBox(width: 8),
        Text(
          '$title ($count)',
          style: GoogleFonts.poppins(
              fontSize: isTablet ? 18 : 18,
              fontWeight: FontWeight.bold,
              color: AppColors.MainColor),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppColors.MainColor,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsList(
      Map<String, List<Map<String, dynamic>>> goals, bool isTablet) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: goals.entries.length,
      itemBuilder: (context, index) {
        String dateKey = goals.keys.elementAt(index);
        List<Map<String, dynamic>> dateGoals = goals[dateKey]!;
        bool isFullyAchieved = isDateFullyAchieved(dateGoals);

        // Parse the dateKey (assuming it's in 'yyyy-MM-dd' format) and format it to 'EEEE'
        DateTime parsedDate = DateTime.parse(dateKey); // Parse the date string
        String formattedDate =
            DateFormat('EEEE').format(parsedDate); // e.g., "Monday"

        return AnimatedOpacity(
          opacity:
              1.0, // Assuming _fadeAnimation is defined elsewhere; set to 1.0 if not
          duration: const Duration(milliseconds: 300),
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: isFullyAchieved
                      ? Colors.green.withOpacity(0.2)
                      : Colors.redAccent.withOpacity(0.2),
                  child: Icon(
                    isFullyAchieved ? Icons.check : Icons.close,
                    color: isFullyAchieved ? Colors.green : Colors.redAccent,
                  ),
                ),
                title: Text(
                  formattedDate, // Use the reformatted date (e.g., "Monday")
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.MainColor,
                  ),
                ),
                subtitle: Text(
                  'Shops: ${dateGoals.length}',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 14 : 12,
                    color: AppColors.MainColor,
                  ),
                ),
                trailing: Chip(
                  label: Text(
                    isFullyAchieved ? 'Achieved' : 'Pending',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  backgroundColor:
                      isFullyAchieved ? Colors.green : Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                children: dateGoals.map((goal) {
                  String shopName = goal['Shop Name'] ?? 'Unknown';
                  bool status = goal['status'] == true;

                  return ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Icon(
                      status ? Icons.check_circle : Icons.cancel,
                      color: status ? Colors.green : Colors.redAccent,
                    ),
                    title: Text(
                      shopName,
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.MainColor,
                      ),
                    ),
                    trailing: Text(
                      status ? 'Completed' : 'Pending',
                      style: GoogleFonts.poppins(
                        color: status ? Colors.green : Colors.redAccent,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShopsList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sundayShops,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> mondayShops,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tuesdayShops,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> wednesdayShops,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> thursdayShops,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> fridayShops,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> saturdayShops,
    int sundayVisited,
    int mondayVisited,
    int tuesdayVisited,
    int wednesdayVisited,
    int thursdayVisited,
    int fridayVisited,
    int saturdayVisited,
    bool isTablet,
  ) {
    return Column(
      children: [
        if (sundayShops.isNotEmpty)
          _buildDayTile('Sunday', sundayShops, sundayVisited, isTablet),
        if (mondayShops.isNotEmpty)
          _buildDayTile('Monday', mondayShops, mondayVisited, isTablet),
        if (tuesdayShops.isNotEmpty)
          _buildDayTile('Tuesday', tuesdayShops, tuesdayVisited, isTablet),
        if (wednesdayShops.isNotEmpty)
          _buildDayTile(
              'Wednesday', wednesdayShops, wednesdayVisited, isTablet),
        if (thursdayShops.isNotEmpty)
          _buildDayTile('Thursday', thursdayShops, thursdayVisited, isTablet),
        if (fridayShops.isNotEmpty)
          _buildDayTile('Friday', fridayShops, fridayVisited, isTablet),
        if (saturdayShops.isNotEmpty)
          _buildDayTile('Saturday', saturdayShops, saturdayVisited, isTablet),
      ],
    );
  }

  Widget _buildDayTile(
      String day,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> shops,
      int visitedCount,
      bool isTablet) {
    int totalCount = shops.length;
    double strikeRate = calculateStrikeRate(totalCount, visitedCount);

    return AnimatedOpacity(
      opacity: _fadeAnimation.value,
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: AppColors.MainColor.withOpacity(0.1),
            child: const Icon(Icons.store, color: AppColors.MainColor),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$day ($totalCount)',
                style: GoogleFonts.poppins(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.MainColor),
              ),
              Chip(
                label: Text(
                  '${strikeRate.toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: strikeRate > 50 ? Colors.green : Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ],
          ),
          subtitle: Text(
            'Visited: $visitedCount/$totalCount',
            style: GoogleFonts.poppins(
                fontSize: isTablet ? 14 : 12, color: AppColors.MainColor),
          ),
          children: shops.map((shop) {
            var shopData = shop.data();
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(8),
                leading: Icon(
                  shopData['visited'] == true
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: shopData['visited'] == true
                      ? Colors.green
                      : Colors.redAccent,
                ),
                title: Text(
                  shopData['Shop Name'] ?? 'Unnamed Shop',
                  style: GoogleFonts.poppins(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.MainColor),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visited: ${shopData['visited'] == true ? 'Yes' : 'No'}',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.MainColor),
                    ),
                    if (shopData['Shop ID'] != null)
                      Text('ID: ${shopData['Shop ID']}',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.MainColor)),
                    if (shopData['scheduledDate'] != null)
                      Text('Date: ${shopData['scheduledDate']}',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.MainColor)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
