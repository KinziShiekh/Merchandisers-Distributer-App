import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:merchandiser_app/contant/colors.dart';
import 'package:merchandiser_app/pages/Gallery/shopdetail.dart';
import 'package:merchandiser_app/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:intl/intl.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<DocumentSnapshot> shops = [];
  List<DocumentSnapshot> filteredShops = [];
  bool isLoading = true;
  DateTime? _selectedSingleDate = DateTime.now(); // Default to current date
  DateTimeRange? _selectedDateRange;
  bool _isRangeMode = false;

  @override
  void initState() {
    super.initState();
    _fetchShops();
  }

  Future<void> _fetchShops() async {
    final userProvider = context.read<UserProvider>();

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('Shops')
          .where('visited', isEqualTo: true)
          .where('assignedMerchandisers',
              isEqualTo: userProvider.merchandiserName)
          .get();

      setState(() {
        shops = querySnapshot.docs;
        _filterShops(); // Apply initial filter for current date
        isLoading = false;
      });
    } catch (e) {
      print("Error loading shops: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterShops() {
    setState(() {
      if (_selectedSingleDate != null) {
        String selectedDateStr =
            DateFormat('yyyy-MM-dd').format(_selectedSingleDate!);
        filteredShops = shops.where((shop) {
          String visitedTime =
              (shop.data() as Map<String, dynamic>)['scheduledDate'] ?? '';
          return visitedTime.startsWith(selectedDateStr);
        }).toList();
      } else if (_selectedDateRange != null) {
        DateTime start = _selectedDateRange!.start;
        DateTime end = _selectedDateRange!.end;
        filteredShops = shops.where((shop) {
          String visitedTimeStr =
              (shop.data() as Map<String, dynamic>)['scheduledDate'] ?? '';
          DateTime visitedTime = DateTime.parse(visitedTimeStr);
          return visitedTime.isAfter(start.subtract(const Duration(days: 1))) &&
              visitedTime.isBefore(end.add(const Duration(days: 1)));
        }).toList();
      } else {
        // Default to current date if no filter is applied
        String currentDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        filteredShops = shops.where((shop) {
          String visitedTime =
              (shop.data() as Map<String, dynamic>)['scheduledDate'] ?? '';
          return visitedTime.startsWith(currentDateStr);
        }).toList();
      }
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
                      _filterShops();
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
                          _selectedSingleDate =
                              DateTime.now(); // Reset to today
                          _selectedDateRange = null;
                          _filterShops();
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
                          _selectedSingleDate =
                              isRangeModeLocal ? null : DateTime.now();
                          _selectedDateRange = null;
                          _filterShops();
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
    return Scaffold(
      backgroundColor: AppColors.Background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: Icon(Icons.arrow_back_ios_sharp, color: AppColors.MainColor),
        ),
        title: Text(
          'Visited Shops Gallery',
          style: GoogleFonts.poppins(
            color: AppColors.MainColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.Background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: AppColors.MainColor),
            onPressed: () => _showDatePicker(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.Background, Colors.white],
          ),
        ),
        child: Column(
          children: [
            if (_selectedSingleDate != null || _selectedDateRange != null)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Chip(
                  avatar: const Icon(Icons.calendar_today,
                      size: 18, color: AppColors.MainColor),
                  label: Text(
                    _selectedSingleDate != null
                        ? 'Selected: ${DateFormat('MMM d, yyyy').format(_selectedSingleDate!)}'
                        : 'Range: ${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, yyyy').format(_selectedDateRange!.end)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.MainColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 2,
                ),
              ),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppColors.MainColor),
                      ),
                    )
                  : filteredShops.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.store_outlined,
                                  size: 60, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No visited shops found for this date.',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchShops,
                          color: AppColors.MainColor,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: filteredShops.length,
                            itemBuilder: (context, index) {
                              var shop = filteredShops[index];
                              Map<String, dynamic> shopData =
                                  shop.data() as Map<String, dynamic>;

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ShopDetailScreen(shopData: shop),
                                    ),
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Stack(
                                      children: [
                                        shopData['BannerImage'] != null &&
                                                (shopData['BannerImage']
                                                        as List)
                                                    .isNotEmpty
                                            ? Image.network(
                                                shopData['BannerImage'][0],
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                                loadingBuilder: (context, child,
                                                    loadingProgress) {
                                                  if (loadingProgress == null)
                                                    return child;
                                                  return Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      value: loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              (loadingProgress
                                                                      .expectedTotalBytes ??
                                                                  1)
                                                          : null,
                                                      color:
                                                          AppColors.MainColor,
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    Container(
                                                  color: Colors.grey[300],
                                                  child: const Center(
                                                    child: Icon(
                                                        Icons.broken_image,
                                                        color: Colors.grey),
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                color: Colors.grey[300],
                                                child: const Center(
                                                  child: Icon(Icons.image,
                                                      color: Colors.grey,
                                                      size: 50),
                                                ),
                                              ),
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withOpacity(0.7),
                                                ],
                                              ),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                bottomLeft: Radius.circular(20),
                                                bottomRight:
                                                    Radius.circular(20),
                                              ),
                                            ),
                                            child: Text(
                                              shopData['Shop Name'] ??
                                                  'Unnamed Shop',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black
                                                        .withOpacity(0.5),
                                                    blurRadius: 4,
                                                    offset: const Offset(1, 1),
                                                  ),
                                                ],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Visited',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchShops,
        backgroundColor: AppColors.MainColor,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}
