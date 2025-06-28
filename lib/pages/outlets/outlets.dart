import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:merchandiser_app/contant/colors.dart';
import 'package:merchandiser_app/contant/images.dart';
import 'package:merchandiser_app/pages/homepage.dart';
import 'package:merchandiser_app/pages/outlets/monitiez.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:merchandiser_app/provider/user_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:path/path.dart' as path;

class OutletsScreen extends StatefulWidget {
  @override
  _OutletsScreenState createState() => _OutletsScreenState();
}

class _OutletsScreenState extends State<OutletsScreen> {
  List<Map<String, dynamic>> _shops = [];
  bool _isLoading = true;
  DateTime? _selectedDate = DateTime.now();
  String _visitedFilter = "All";
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchShops();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permissions are permanently denied.')),
      );
      return;
    }

    _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {});
  }

  double _calculateDistance(double shopLat, double shopLng) {
    if (_currentPosition == null) return double.infinity;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      shopLat,
      shopLng,
    );
  }

  Future<void> _fetchShops() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userName = userProvider.merchandiserName;

    try {
      setState(() {
        _isLoading = true;
      });

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Shops')
          .where('assignedMerchandisers', isEqualTo: userName)
          .where('scheduledDate',
              isEqualTo: _selectedDate != null
                  ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                  : null)
          .get();

      List<Map<String, dynamic>> fetchedShops = snapshot.docs
          .map((doc) => {
                ...doc.data() as Map<String, dynamic>,
                'id': doc.id,
              })
          .toList();

      if (_visitedFilter != "All") {
        bool visited = _visitedFilter == "Visited" ? true : false;
        fetchedShops =
            fetchedShops.where((shop) => shop['visited'] == visited).toList();
      }

      List<Map<String, dynamic>> visitedShops =
          fetchedShops.where((shop) => shop['visited'] == true).toList();
      List<Map<String, dynamic>> unvisitedShops =
          fetchedShops.where((shop) => shop['visited'] != true).toList();

      visitedShops.sort((a, b) => a['Shop Name'].compareTo(b['Shop Name']));
      unvisitedShops.sort((a, b) => a['Shop Name'].compareTo(b['Shop Name']));

      fetchedShops = [...visitedShops, ...unvisitedShops];

      setState(() {
        _shops = fetchedShops;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching shops: $e')),
      );
    }
  }

  void _showDatePicker() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                'Select Date',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.MainColor,
                ),
              ),
              const SizedBox(height: 12),
              SfDateRangePicker(
                onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                  if (args.value is DateTime) {
                    setState(() {
                      _selectedDate = args.value;
                    });
                  }
                },
                selectionMode: DateRangePickerSelectionMode.single,
                initialSelectedDate: _selectedDate ?? DateTime.now(),
                backgroundColor: Colors.grey[50],
                todayHighlightColor: AppColors.MainColor,
                selectionColor: AppColors.MainColor.withOpacity(0.4),
                headerStyle: DateRangePickerHeaderStyle(
                  textStyle: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.MainColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedDate = DateTime.now();
                      });
                      Navigator.pop(context);
                      _fetchShops();
                    },
                    child: Text('Clear',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _fetchShops();
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.MainColor),
                    child: Text('OK', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onVisitedFilterSelected(String? selectedFilter) {
    if (selectedFilter != null) {
      setState(() {
        _visitedFilter = selectedFilter;
      });
      _fetchShops();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.Background,
      appBar: AppBar(
        backgroundColor: AppColors.Background,
        centerTitle: true,
        title: Text(
          'Outlets',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.MainColor,
          ),
        ),
        leading: IconButton(
          onPressed: () => Get.back(),
          icon:
              Icon(Icons.arrow_back_ios_new_sharp, color: AppColors.MainColor),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Image.asset(AppImages.laysLogo, height: 40),
          ),
        ],
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showDatePicker,
                    child: Container(
                      height: 40,
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.MainColor),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDate != null
                                ? DateFormat('yyyy-MM-dd')
                                    .format(_selectedDate!)
                                : 'Select Date',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.MainColor,
                            ),
                          ),
                          Icon(Icons.calendar_today,
                              size: 18, color: AppColors.MainColor),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Container(
                    height: 40,
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.MainColor),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: DropdownButton<String>(
                      value: _visitedFilter,
                      onChanged: _onVisitedFilterSelected,
                      items:
                          ["All", "Visited", "Unvisited"].map((String filter) {
                        return DropdownMenuItem<String>(
                          value: filter,
                          child: Text(
                            filter,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.MainColor,
                            ),
                          ),
                        );
                      }).toList(),
                      isExpanded: true,
                      underline: SizedBox(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _isLoading
                ? Center(
                    child:
                        CircularProgressIndicator(color: AppColors.MainColor))
                : _shops.isEmpty
                    ? Center(
                        child: Text(
                          'No shops found for this date.',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: AppColors.MainColor,
                          ),
                        ),
                      )
                    : Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            await _fetchShops();
                          },
                          color: AppColors.MainColor,
                          backgroundColor: AppColors.Background,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _shops.length,
                            itemBuilder: (context, index) {
                              var shop = _shops[index];
                              return OutletCard(
                                shop: shop,
                                currentPosition: _currentPosition,
                              );
                            },
                          ),
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}

class OutletCard extends StatelessWidget {
  final Map<String, dynamic> shop;
  final Position? currentPosition;

  OutletCard({required this.shop, this.currentPosition});

  void _showLocationPopup(BuildContext context, double lat, double lng) async {
    Position? currentPosition;
    try {
      currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print("Error getting current location: $e");
    }

    double? distanceInMeters;
    if (currentPosition != null) {
      distanceInMeters = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        lat,
        lng,
      );
    }

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 12,
          backgroundColor: Colors.transparent,
          child: Container(
            height: 460,
            width: 360,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: AppColors.Background,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.MainColor,
                        AppColors.MainColor.withOpacity(0.8)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          shop['Shop Name'] ?? "Shop",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon:
                              Icon(Icons.close, color: Colors.white, size: 26),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (distanceInMeters != null)
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          child: Icon(
                            Icons.directions_walk,
                            color: AppColors.MainColor,
                            size: 26,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Distance: ${distanceInMeters.toStringAsFixed(0)} m",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: Offset(0, -2),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(24)),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(lat, lng),
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: MarkerId("shop_location"),
                            position: LatLng(lat, lng),
                            infoWindow: InfoWindow(
                              title: shop['Shop Name'] ?? "Shop",
                            ),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed,
                            ),
                          ),
                          if (currentPosition != null)
                            Marker(
                              markerId: MarkerId("current_location"),
                              position: LatLng(
                                currentPosition.latitude,
                                currentPosition.longitude,
                              ),
                              infoWindow: InfoWindow(title: "Your Location"),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueBlue,
                              ),
                            ),
                        },
                        polylines: {
                          if (currentPosition != null)
                            Polyline(
                              polylineId: PolylineId("route"),
                              points: [
                                LatLng(currentPosition.latitude,
                                    currentPosition.longitude),
                                LatLng(lat, lng),
                              ],
                              color: AppColors.MainColor,
                              width: 5,
                              patterns: [
                                PatternItem.dash(20),
                                PatternItem.gap(10),
                              ],
                            ),
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }

  Future<bool?> _showMonetizeDialog(BuildContext context) async {
    bool isLoading = false;

    return await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(
                "Monetize Data",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.MainColor,
                ),
              ),
              content: isLoading
                  ? SizedBox(
                      height: 100,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.MainColor,
                        ),
                      ),
                    )
                  : Text(
                      "Do you want to monetize your data?",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.MainColor,
                      ),
                    ),
              actions: isLoading
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(
                          "No",
                          style:
                              GoogleFonts.poppins(color: AppColors.MainColor),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            isLoading = true;
                          });
                          await Future.delayed(Duration(seconds: 2));
                          Navigator.pop(dialogContext, true);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.MainColor),
                        child: Text(
                          "Yes",
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isVisited = shop['visited'] ?? false;
    double latitude = shop['Latitude'] ?? 0.0;
    double longitude = shop['Longitude'] ?? 0.0;
    double distance = currentPosition != null
        ? Geolocator.distanceBetween(
            currentPosition!.latitude,
            currentPosition!.longitude,
            latitude,
            longitude,
          )
        : double.infinity;
    bool isWithinRange = distance <= 30;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    String? distributorId = userProvider.distributorId;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isVisited ? Colors.green : Colors.redAccent,
          width: 2,
        ),
      ),
      elevation: 8,
      shadowColor: Colors.grey.withOpacity(0.3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.MainColor.withOpacity(0.1),
                    child: Image.asset(
                      AppImages.shop,
                      color: AppColors.MainColor,
                      height: 32,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop['Shop Name'] ?? 'No name available',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.MainColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ID: ${shop['Shop ID']}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.MainColor,
                          ),
                        ),
                        Text(
                          shop['day'] ?? 'No day available',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.MainColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          shop['scheduledDate'] ?? 'No date available',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.MainColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (currentPosition != null)
                          Text(
                            'Distance: ${distance.toStringAsFixed(1)} m',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: distance <= 30
                                  ? Colors.green
                                  : Colors.redAccent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.location_on,
                        color: AppColors.MainColor, size: 28),
                    onPressed: () =>
                        _showLocationPopup(context, latitude, longitude),
                    splashRadius: 24,
                    tooltip: 'View Location',
                  ),
                  ElevatedButton.icon(
                    onPressed: isWithinRange
                        ? () async {
                            if (isVisited) {
                              bool? confirmMonetize =
                                  await _showMonetizeDialog(context);
                              if (confirmMonetize == true) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MonetizeDataScreen(
                                      shopName: shop['Shop Name'] ??
                                          'No name available',
                                      shopId: shop['Shop ID'],
                                      scheduledDate: shop['scheduledDate'],
                                      shopDocId: 'id',
                                    ),
                                  ),
                                );
                              }
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OutletDataScreen(
                                    shopName: shop['Shop Name'] ??
                                        'No name available',
                                    shopId: shop['Shop ID'] ?? '',
                                    shopDocId: shop['id'] ?? '',
                                    scheduledDate: shop['scheduledDate'] ??
                                        DateFormat('yyyy-MM-dd')
                                            .format(DateTime.now()),
                                    distributorId: distributorId,
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: isWithinRange
                          ? AppColors.MainColor
                          : Colors.grey.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      elevation: isWithinRange ? 6 : 0,
                    ),
                    icon: Icon(Icons.store, size: 18),
                    label: Text(
                      'Visit Shop',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
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
    );
  }
}

class OutletDataScreen extends StatefulWidget {
  final String shopName;
  final String shopId;
  final String shopDocId;
  final String scheduledDate;
  final String? distributorId;

  const OutletDataScreen({
    super.key,
    required this.shopName,
    required this.shopId,
    required this.shopDocId,
    required this.scheduledDate,
    this.distributorId,
  });

  @override
  State<OutletDataScreen> createState() => OutletDataScreenState();
}

class OutletDataScreenState extends State<OutletDataScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController _visitedTimeController = TextEditingController();
  TextEditingController _timeSpentController = TextEditingController();
  String? _merchandiserName;
  List<File> _outletBannerImages = [];
  List<File> _beforeDisplayImages = [];
  List<File> _afterDisplayImages = [];
  List<String> _unavailableBrands = [];
  Map<String, List<String>> _brandPriceSelection = {};
  List<Map<String, String>> _selectedBrandsAndPrices = [];
  final ImagePicker _picker = ImagePicker();
  Timer? _timer;
  int _timeSpentInSeconds = 0;
  String? _rackQuantity;
  List<Map<String, dynamic>> _racks = [];
  bool _isLoading = false;
  String? _selectedRack;
  final List<String> _rackOptions = ['Large', 'Medium', 'Small', 'Gandola'];
  bool _isOtherSelected = true;
  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _merchandiserName = userProvider.merchandiserName;
    _setCurrentTime();
    _startTimer();
    _racks.add({
      'type': null,
      'quantity': '1',
      'controller': TextEditingController(text: '1'),
      'formKey': GlobalKey<FormState>(),
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _timeSpentInSeconds++;
        _updateTimeSpent();
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _updateTimeSpent() {
    int minutes = (_timeSpentInSeconds / 60).floor();
    int seconds = _timeSpentInSeconds % 60;
    _timeSpentController.text = '${minutes}m ${seconds}s';
  }

  void _setCurrentTime() {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    _visitedTimeController.text = formattedDate;
  }

  void _toggleBrand(String brand) {
    setState(() {
      if (_unavailableBrands.contains(brand)) {
        _unavailableBrands.remove(brand);
        _brandPriceSelection.remove(brand);
      } else {
        _unavailableBrands.add(brand);
        _brandPriceSelection[brand] = [];
      }
      _updateSelectedBrandsAndPrices();
    });
  }

  void _togglePriceRange(String brand, String price) {
    setState(() {
      if (_brandPriceSelection[brand] == null) {
        _brandPriceSelection[brand] = [];
      }
      if (_brandPriceSelection[brand]!.contains(price)) {
        _brandPriceSelection[brand]!.remove(price);
      } else {
        _brandPriceSelection[brand]!.add(price);
      }
      _updateSelectedBrandsAndPrices();
    });
  }

  void _updateSelectedBrandsAndPrices() {
    _selectedBrandsAndPrices.clear();
    _brandPriceSelection.forEach((brand, prices) {
      for (var price in prices) {
        _selectedBrandsAndPrices.add({"Brand": brand, "Price": price});
      }
    });
  }

  void _addRack() {
    setState(() {
      _racks.add({
        'type': null,
        'quantity': '1',
        'controller': TextEditingController(text: '1'),
        'formKey': GlobalKey<FormState>(),
      });
    });
  }

  void _removeRack(int index) {
    setState(() {
      _racks[index]['controller'].dispose();
      _racks.removeAt(index);
    });
  }

  void _incrementQuantity(int index) {
    setState(() {
      int current = int.tryParse(_racks[index]['quantity']) ?? 1;
      _racks[index]['quantity'] = (current + 1).toString();
      _racks[index]['controller'].text = _racks[index]['quantity'];
    });
  }

  void _decrementQuantity(int index) {
    setState(() {
      int current = int.tryParse(_racks[index]['quantity']) ?? 1;
      if (current > 1) {
        _racks[index]['quantity'] = (current - 1).toString();
        _racks[index]['controller'].text = _racks[index]['quantity'];
      }
    });
  }

  final TextEditingController _otherBrandController = TextEditingController();

  String _getDayFromDate(DateTime date) {
    return DateFormat('EEEE').format(date);
  }

  Future<void> _saveData() async {
    bool? confirmSave = await _showConfirmationDialog();
    if (confirmSave != true) return;

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      CollectionReference shops =
          FirebaseFirestore.instance.collection('Shops');

      bool isConnected = await _checkNetwork();
      if (!isConnected) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "No internet connection. Please check your network and try again.")),
        );
        return;
      }

      try {
        print(
            'Updating shop document: ${widget.shopDocId} for shop: ${widget.shopName}');
        List<String?> outletBannerUrls = [];
        List<String?> beforeDisplayUrls = [];
        List<String?> afterDisplayUrls = [];

        print('Uploading ${_outletBannerImages.length} banner images');
        for (var image in _outletBannerImages) {
          var url = await _uploadImageToStorage('BannerImage', image);
          outletBannerUrls.add(url ?? 'failed:${image.path}');
        }

        print('Uploading ${_beforeDisplayImages.length} before display images');
        for (var image in _beforeDisplayImages) {
          var url = await _uploadImageToStorage('beforeDisplayImage', image);
          beforeDisplayUrls.add(url ?? 'failed:${image.path}');
        }

        print('Uploading ${_afterDisplayImages.length} after display images');
        for (var image in _afterDisplayImages) {
          var url = await _uploadImageToStorage('afterDisplayImage', image);
          afterDisplayUrls.add(url ?? 'failed:${image.path}');
        }

        List<String> validOutletBannerUrls = outletBannerUrls
            .where((url) => url != null && !url.startsWith('failed:'))
            .cast<String>()
            .toList();
        List<String> validBeforeDisplayUrls = beforeDisplayUrls
            .where((url) => url != null && !url.startsWith('failed:'))
            .cast<String>()
            .toList();
        List<String> validAfterDisplayUrls = afterDisplayUrls
            .where((url) => url != null && !url.startsWith('failed:'))
            .cast<String>()
            .toList();

        List<String> failedUploads = [
          ...outletBannerUrls,
          ...beforeDisplayUrls,
          ...afterDisplayUrls,
        ]
            .where((url) => url != null && url.startsWith('failed:'))
            .cast<String>()
            .toList();
        if (failedUploads.isNotEmpty) {
          print('Failed uploads: $failedUploads');
        }

        print(
            'Uploaded ${validOutletBannerUrls.length + validBeforeDisplayUrls.length + validAfterDisplayUrls.length} images successfully');

        List<Map<String, String>> rackData = _racks
            .where((rack) => rack['type'] != null)
            .map((rack) => {
                  'Type': rack['type'] as String,
                  'Quantity': rack['quantity'] as String,
                })
            .toList();

        Map<String, dynamic> updateData = {
          'unavailableBrand': _selectedBrandsAndPrices,
          'visitedTime': _visitedTimeController.text,
          'timeSpent': _timeSpentController.text,
          'BannerImage': validOutletBannerUrls,
          'beforeDisplay': validBeforeDisplayUrls,
          'afterDisplay': validAfterDisplayUrls,
          'visited': true,
          'Rack': rackData,
          'failedUploads': failedUploads,
          'scheduledDate': widget.scheduledDate,
        };

        // Save to ShopVisits collection

        int estimatedSize = updateData.toString().length * 2;
        if (estimatedSize > 900000) {
          print(
              'Warning: Document size may exceed Firestore 1MB limit: $estimatedSize bytes');
        }

        // Update Shops collection
        await shops.doc(widget.shopDocId).update(updateData);
        print('Shop data updated successfully');

        _updateMerchandiserAchievedGoals(
            _getDayFromDate(DateTime.now()), widget.scheduledDate);

        _stopTimer();
        setState(() => _isLoading = false);

        if (!mounted) return;

        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              elevation: 10,
              title: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.orange.shade700,
                    size: 30,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Success",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                "Your shop data has been saved successfully!${failedUploads.isNotEmpty ? '\nNote: ${failedUploads.length} image(s) failed to upload.' : ''}",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => HomeScreen()),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    "OK",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              actionsPadding: EdgeInsets.only(right: 20, bottom: 15),
            );
          },
        );
      } catch (e) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        print('Error saving data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

// _buildRackSelection remains largely the same, but we'll pass screenWidth and textScaleFactor to _buildRackItem
  Widget _buildRackSelection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = MediaQuery.of(context).size;
        final isPortrait =
            MediaQuery.of(context).orientation == Orientation.portrait;
        final textScaleFactor = MediaQuery.of(context).textScaleFactor;

        final isMobile = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1200;
        final isDesktop = constraints.maxWidth >= 1200;

        final cardPadding = screenSize.width * 0.04;
        final spacing = screenSize.width * 0.03;
        final borderRadius = isMobile ? 12.0 : 16.0;
        final fontSizeTitle = (isMobile ? 16.0 : 20.0) * textScaleFactor;
        final maxCardWidth = isDesktop
            ? 1000.0
            : isTablet
                ? 800.0
                : double.infinity;

        final crossAxisCount = isDesktop
            ? 3
            : isTablet
                ? 2
                : 1;

        return SafeArea(
          minimum: EdgeInsets.symmetric(horizontal: isMobile ? 8.0 : 16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Container(
              constraints: BoxConstraints(maxWidth: maxCardWidth),
              margin: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 16.0),
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          'Rack Selection',
                          style: GoogleFonts.poppins(
                            fontSize: fontSizeTitle,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      _buildAddButton(),
                    ],
                  ),
                  SizedBox(height: spacing),
                  _racks.isEmpty
                      ? _buildEmptyState()
                      : MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: isMobile
                              ? ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _racks.length,
                                  separatorBuilder: (context, index) =>
                                      SizedBox(height: spacing),
                                  itemBuilder: (context, index) =>
                                      _buildRackItem(index, screenSize.width,
                                          textScaleFactor),
                                )
                              : GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: spacing,
                                    mainAxisSpacing: spacing,
                                    childAspectRatio:
                                        isPortrait ? 3 / 2 : 4 / 2,
                                  ),
                                  itemCount: _racks.length,
                                  itemBuilder: (context, index) =>
                                      _buildRackItem(index, screenSize.width,
                                          textScaleFactor),
                                ),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        final iconSize = isSmallScreen ? 24.0 : 28.0;

        return IconButton(
          icon: Icon(
            Icons.add_circle,
            color: Colors.orange.shade700,
            size: iconSize,
          ),
          padding: EdgeInsets.all(isSmallScreen ? 4.0 : 8.0),
          constraints: BoxConstraints(),
          onPressed: _addRack,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaleFactor = MediaQuery.of(context).textScaleFactor;
        final isSmallScreen = constraints.maxWidth < 600;
        final fontSize = (isSmallScreen ? 14.0 : 16.0) * textScaleFactor;

        return Center(
          child: Padding(
            padding:
                EdgeInsets.symmetric(vertical: isSmallScreen ? 16.0 : 24.0),
            child: Text(
              'No racks selected. Add a rack to start.',
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRackItem(int index, double screenWidth, double textScaleFactor) {
    final isVerySmallScreen =
        screenWidth < 440; // For screens narrower than 440px
    final isSmallScreen = screenWidth < 600;
    final fontSize = (isSmallScreen ? 14.0 : 16.0) * textScaleFactor;
    final padding = screenWidth * 0.02;
    final qtyFieldWidth = isVerySmallScreen
        ? screenWidth * 0.2
        : isSmallScreen
            ? screenWidth * 0.25
            : 120.0;
    final iconSize = isSmallScreen ? 20.0 : 24.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: padding),
      child: Wrap(
        spacing: padding,
        runSpacing: padding,
        children: [
          SizedBox(
            width: isVerySmallScreen
                ? screenWidth - (padding * 2)
                : screenWidth * 0.5, // Full width on very small screens
            child: DropdownButtonFormField<String>(
              value: _racks[index]['type'],
              hint: Text(
                'Select Rack Type',
                style: GoogleFonts.poppins(fontSize: fontSize * 0.9),
              ),
              items: _rackOptions.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option,
                    style: GoogleFonts.poppins(fontSize: fontSize * 0.9),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _racks[index]['type'] = value;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: padding,
                  vertical: isSmallScreen ? 8.0 : 12.0,
                ),
              ),
              validator: (value) =>
                  value == null ? 'Please select a rack type' : null,
              isDense: true,
              dropdownColor: Colors.white,
            ),
          ),
          SizedBox(
            width: qtyFieldWidth,
            child: Form(
              key: _racks[index]['formKey'],
              child: TextFormField(
                controller: _racks[index]['controller'],
                decoration: InputDecoration(
                  labelText: 'Qty',
                  labelStyle: GoogleFonts.poppins(fontSize: fontSize * 0.8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: padding,
                    vertical: isSmallScreen ? 8.0 : 12.0,
                  ),
                  suffixIcon: isVerySmallScreen
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => _incrementQuantity(index),
                              child: Icon(Icons.arrow_drop_up,
                                  size: iconSize, color: Colors.green.shade700),
                            ),
                            GestureDetector(
                              onTap: () => _decrementQuantity(index),
                              child: Icon(Icons.arrow_drop_down,
                                  size: iconSize, color: Colors.red.shade700),
                            ),
                          ],
                        )
                      : null,
                ),
                style: GoogleFonts.poppins(fontSize: fontSize * 0.9),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onChanged: (value) {
                  setState(() {
                    _racks[index]['quantity'] = value;
                  });
                },
                validator: (value) => value!.isEmpty ? 'Enter quantity' : null,
              ),
            ),
          ),
          if (!isVerySmallScreen) ...[
            IconButton(
              icon: Icon(
                Icons.remove_circle,
                color: Colors.red.shade700,
                size: iconSize,
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () => _removeRack(index),
            ),
            IconButton(
              icon: Icon(
                Icons.add_circle,
                color: Colors.green.shade700,
                size: iconSize,
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () => _incrementQuantity(index),
            ),
            IconButton(
              icon: Icon(
                Icons.remove_circle,
                color: Colors.red.shade700,
                size: iconSize,
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () => _decrementQuantity(index),
            ),
          ],
          if (isVerySmallScreen)
            IconButton(
              icon: Icon(
                Icons.remove_circle,
                color: Colors.red.shade700,
                size: iconSize,
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () => _removeRack(index),
            ),
        ],
      ),
    );
  }

  Future<void> _updateMerchandiserAchievedGoals(
      String shopDay, String scheduledDate) async {
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('No authenticated user found');
      }

      QuerySnapshot merchandiserSnapshot = await FirebaseFirestore.instance
          .collection('Merchandiser')
          .where('merchandiserId', isEqualTo: uid)
          .limit(1)
          .get();

      if (merchandiserSnapshot.docs.isEmpty) {
        throw Exception('Merchandiser not found');
      }

      var merchandiserDoc = merchandiserSnapshot.docs.first;
      String merchandiserId = merchandiserDoc.id;
      Map<String, dynamic> merchData =
          merchandiserDoc.data() as Map<String, dynamic>;

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      String? distributorId =
          widget.distributorId ?? userProvider.distributorId;

      if (distributorId == null || distributorId.isEmpty) {
        throw Exception('Distributor ID is not available');
      }

      Map<String, dynamic> achievedGoals = {};
      if (merchData.containsKey('achievedGoals') &&
          merchData['achievedGoals'] != null) {
        achievedGoals = Map<String, dynamic>.from(merchData['achievedGoals']);
      }

      List<Map<String, dynamic>> dateEntries = [];
      if (achievedGoals.containsKey(scheduledDate) &&
          achievedGoals[scheduledDate] != null) {
        dateEntries =
            List<Map<String, dynamic>>.from(achievedGoals[scheduledDate]);
      }

      bool foundMatch = false;
      for (int i = 0; i < dateEntries.length; i++) {
        if (dateEntries[i]['Shop Name'] == widget.shopName) {
          dateEntries[i]['status'] = true;
          dateEntries[i]['date'] = scheduledDate;
          foundMatch = true;
          break;
        }
      }

      if (!foundMatch) {
        dateEntries.add({
          'date': scheduledDate,
          'Shop Name': widget.shopName,
          'status': true,
        });
      }

      achievedGoals[scheduledDate] = dateEntries;

      Map<String, dynamic> updateData = {
        'achievedGoals': achievedGoals,
      };

      await FirebaseFirestore.instance
          .collection('Merchandiser')
          .doc(merchandiserId)
          .update(updateData);

      DocumentSnapshot distributorMerchDoc = await FirebaseFirestore.instance
          .collection('distributors')
          .doc(distributorId)
          .collection('Merchandiser')
          .doc(merchandiserId)
          .get();

      if (distributorMerchDoc.exists) {
        await FirebaseFirestore.instance
            .collection('distributors')
            .doc(distributorId)
            .collection('Merchandiser')
            .doc(merchandiserId)
            .update(updateData);
      } else {
        await FirebaseFirestore.instance
            .collection('distributors')
            .doc(distributorId)
            .collection('Merchandiser')
            .doc(merchandiserId)
            .set(updateData);
      }
    } catch (e) {
      debugPrint('Error updating achievedGoals: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating achieved goals: $e")),
        );
      }
    }
  }

  Future<bool?> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Confirm Save",
            style:
                GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Text(
          "Are you sure you want to save the data?",
          style: GoogleFonts.poppins(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style:
                  GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              "Confirm",
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _uploadImageToStorage(String fieldName, File imageFile,
      {int retries = 3}) async {
    var connectivityResult = await Connectivity().checkConnectivity();
    int timeoutSeconds =
        connectivityResult == ConnectivityResult.wifi ? 60 : 90;

    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        print(
            'Attempt $attempt/$retries: Uploading image: ${imageFile.path}, size: ${await imageFile.length() / 1024} KB');

        File? compressedImage = await _compressImage(imageFile);
        File fileToUpload = compressedImage ?? imageFile;
        print(
            'Attempt $attempt/$retries: Using file: ${fileToUpload.path}, size: ${await fileToUpload.length() / 1024} KB');

        String fileName = path.basename(fileToUpload.path);
        Reference storageReference = FirebaseStorage.instance
            .ref()
            .child('shop_images/$fieldName/$fileName');

        UploadTask uploadTask = storageReference.putFile(fileToUpload);
        TaskSnapshot taskSnapshot = await uploadTask
            .timeout(Duration(seconds: timeoutSeconds), onTimeout: () {
          throw Exception('Image upload timed out: ${fileToUpload.path}');
        });

        String downloadUrl = await taskSnapshot.ref.getDownloadURL();
        print('Attempt $attempt/$retries: Uploaded image: $downloadUrl');
        return downloadUrl;
      } catch (e) {
        print(
            'Attempt $attempt/$retries: Error uploading image ${imageFile.path}: $e');
        if (attempt == retries) {
          print('Failed to upload ${imageFile.path} after $retries attempts');
          return null;
        }
        await Future.delayed(Duration(seconds: 3));
      }
    }
    return null;
  }

  Future<File?> _compressImage(File imageFile) async {
    try {
      String targetPath = imageFile.path.replaceFirst(
        path.extension(imageFile.path),
        '_compressed${path.extension(imageFile.path)}',
      );

      var result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,

        quality: 30,
        minWidth: 512,
        minHeight: 512,
        // quality: 50, // Adjust quality (0-100, lower means more compression)
        // minWidth: 1024, // Adjust resolution as needed
        // minHeight: 1024,
      );

      if (result != null) {
        print(
            'Compressed image: ${result.path}, size: ${await File(result.path).length() / 1024} KB');
        return File(result.path);
      }
      return null;
    } catch (e) {
      print("Error compressing image ${imageFile.path}: $e");
      return null;
    }
  }

  Future<bool> _checkNetwork() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    bool isConnected = connectivityResult != ConnectivityResult.none;
    print(
        'Network status: ${isConnected ? 'Connected ($connectivityResult)' : 'Disconnected'}');
    return isConnected;
  }

  Future<void> getImage(String imageType) async {
    final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)), // Smoother corners
              elevation: 8, // Subtle shadow for depth
              backgroundColor: Colors.white, // Clean background
              title: Text(
                'Select Image Source',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.MainColor, // Softer color for title
                ),
                textAlign: TextAlign.center, // Centered title
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Camera Option
                  AnimatedContainer(
                    duration:
                        Duration(milliseconds: 200), // Smooth tap animation
                    child: ListTile(
                      leading: Icon(
                        Icons.camera,
                        color: AppColors.MainColor,
                        size: 28, // Slightly larger icon
                      ),
                      title: Text(
                        'Camera',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context, ImageSource.camera);
                      },
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8), // Better spacing
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10), // Rounded tap area
                      ),
                      tileColor:
                          Colors.grey[50], // Subtle background for ListTile
                      hoverColor:
                          AppColors.MainColor.withOpacity(0.1), // Hover effect
                      splashColor:
                          AppColors.MainColor.withOpacity(0.2), // Tap feedback
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: Colors.grey[300], // Subtle divider
                    indent: 16,
                    endIndent: 16,
                  ),
                  // Gallery Option (Uncommented and Enhanced)

                  SizedBox(height: 10), // Spacing before cancel button
                  // Cancel Button
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.MainColor, // Consistent color
                      padding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: AppColors.MainColor.withOpacity(
                          0.1), // Subtle background
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.MainColor,
                      ),
                    ),
                  ),
                ],
              ),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 8, vertical: 12), // Adjusted padding
              insetPadding:
                  EdgeInsets.all(16), // Dialog padding from screen edges
            ));

    if (source != null) {
      if (await _requestPermissions(source == ImageSource.camera)) {
        final pickedFile = await _picker.pickImage(source: source);
        if (pickedFile != null) {
          setState(() {
            if (imageType == 'BannerImage') {
              _outletBannerImages.add(File(pickedFile.path));
            } else if (imageType == 'beforeDisplay') {
              _beforeDisplayImages.add(File(pickedFile.path));
            } else if (imageType == 'afterDisplay') {
              _afterDisplayImages.add(File(pickedFile.path));
            }
          });
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Permission denied")),
        );
      }
    }
  }

  Future<bool> _requestPermissions(bool isCamera) async {
    PermissionStatus status = isCamera
        ? await Permission.camera.request()
        : await Permission.photos.request();
    return status.isGranted;
  }

  void _deleteImage(String imageType, int index) {
    setState(() {
      if (imageType == 'BannerImage') {
        _outletBannerImages.removeAt(index);
      } else if (imageType == 'beforeDisplay') {
        _beforeDisplayImages.removeAt(index);
      } else if (imageType == 'afterDisplay') {
        _afterDisplayImages.removeAt(index);
      }
    });
  }

  void _deleteEntry(int index) {
    setState(() {
      final entry = _selectedBrandsAndPrices[index];
      final brand = entry['Brand']!;
      final price = entry['Price']!;
      _brandPriceSelection[brand]!.remove(price);
      if (_brandPriceSelection[brand]!.isEmpty) {
        _unavailableBrands.remove(brand);
        _brandPriceSelection.remove(brand);
      }
      _updateSelectedBrandsAndPrices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.Background,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.shopName,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.orange.shade700,
        elevation: 4,
        shadowColor: Colors.black26,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  Row(
                    children: [
                      Text(
                        'Modify Your Data',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.edit, color: Colors.orange.shade700, size: 28),
                    ],
                  ),
                  SizedBox(height: 25),
                  _buildTextField(
                    controller: _visitedTimeController,
                    label: 'Visited Time',
                    icon: Icons.access_time,
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),
                  SizedBox(height: 20),
                  _buildTextField(
                    controller: _timeSpentController,
                    label: 'Time Spent',
                    icon: Icons.timer,
                    readOnly: true,
                  ),
                  SizedBox(height: 25),
                  _buildImageSection(
                      'Outlet Banner', 'BannerImage', _outletBannerImages),
                  SizedBox(height: 25),
                  _buildImageSection(
                      'Before Display', 'beforeDisplay', _beforeDisplayImages),
                  SizedBox(height: 25),
                  _buildImageSection(
                      'After Display', 'afterDisplay', _afterDisplayImages),
                  SizedBox(height: 25),
                  _buildUnavailableBrandsSection(),
                  SizedBox(height: 25),
                  _buildRackSelection(),
                  SizedBox(height: 25),
                  if (_selectedBrandsAndPrices.isNotEmpty) _buildDataTable(),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _saveData,
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(vertical: 18, horizontal: 30),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                      shadowColor: Colors.orange.shade200,
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Submit/Save',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                      strokeWidth: 5,
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Saving Data...",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
              color: AppColors.MainColor, fontWeight: FontWeight.w600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(icon, color: Colors.orange.shade700),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
        style: GoogleFonts.poppins(fontSize: 16),
        validator: validator,
      ),
    );
  }

  Widget _buildImageSection(String title, String type, List<File> images) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.MainColor,
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => getImage(type),
              icon: Icon(Icons.upload, size: 20),
              label: Text('Upload $title Image', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange.shade700,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                elevation: 2,
              ),
            ),
            if (images.isNotEmpty) ...[
              SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            images[index],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _deleteImage(type, index),
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  final Map<String, List<String>> _brandPriceRanges = {
    'Lays': ['20', '30', '50', '70', '100', '150'],
    'Wavy': ['30', '50', '70', '100'],
    'Kurkure': ['20', '30', '40', '60'],
    'Cheetos': ['10', '20', '30', '40', '50', '60', '70', '80', '100'],
    'Others': ['10', '20', '30', '40', '50', '60'],
  };

  void _addCustomBrand() {
    String newBrand = _otherBrandController.text.trim();
    if (newBrand.isNotEmpty) {
      setState(() {
        if (!_unavailableBrands.contains(newBrand)) {
          _unavailableBrands.add(newBrand);
          _brandPriceSelection[newBrand] = [];
        }
        _otherBrandController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$newBrand added')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a brand name')),
      );
    }
  }

  List<String> _getPriceRangeForBrand(String brand) {
    if (_brandPriceRanges.containsKey(brand)) {
      return _brandPriceRanges[brand]!;
    }
    return _brandPriceRanges['Others']!;
  }

  Widget _buildUnavailableBrandsSection() {
    bool _isOtherSelected = true;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unavailable Brands',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.MainColor),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              children: [
                // Predefined brand chips
                ...['Lays', 'Wavy', 'Kurkure', 'Cheetos'].map((brand) {
                  bool isSelected = _unavailableBrands.contains(brand);
                  return ChoiceChip(
                    label: Text(brand),
                    selected: isSelected,
                    onSelected: (selected) => _toggleBrand(brand),
                    selectedColor: AppColors.MainColor,
                    labelStyle: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontSize: 14),
                    backgroundColor: Colors.grey.shade200,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  );
                }).toList(),
                // "Other" button to toggle TextField
                ChoiceChip(
                  label: Text('Other'),
                  selected: _isOtherSelected,
                  onSelected: (selected) {
                    setState(() {
                      _isOtherSelected = selected;
                      if (!selected) {
                        _otherBrandController
                            .clear(); // Clear text when closing
                      }
                    });
                  },
                  selectedColor: AppColors.MainColor,
                  labelStyle: GoogleFonts.poppins(
                      color: _isOtherSelected ? Colors.white : Colors.black87,
                      fontSize: 14),
                  backgroundColor: Colors.grey.shade200,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ],
            ),
            // Separate TextField and Add button for custom brand input
            if (_isOtherSelected)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 200, // Adjust as needed
                      child: TextField(
                        controller: _otherBrandController,
                        decoration: InputDecoration(
                          labelText: 'Custom Brand',
                          hintText: 'Enter brand name',
                          hintStyle: GoogleFonts.poppins(fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        keyboardType: TextInputType.text,
                        autofocus: true,
                        onChanged: (value) {
                          // Debug to track text changes
                          print('TextField value: $value');
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addCustomBrand,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.MainColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: Text(
                        'Add',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            if (_unavailableBrands.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  children: _unavailableBrands.map((brand) {
                    // Get the price range for this brand
                    List<String> priceRange = _getPriceRangeForBrand(brand);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price Range for $brand',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: priceRange.map((price) {
                            bool isSelected =
                                _brandPriceSelection[brand]?.contains(price) ??
                                    false;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (value) =>
                                      _togglePriceRange(brand, price),
                                  activeColor: AppColors.MainColor,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4)),
                                ),
                                Text('Rs $price',
                                    style: GoogleFonts.poppins(fontSize: 14)),
                              ],
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Brands and Prices',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.MainColor),
            ),
            SizedBox(height: 12),
            DataTable(
              columnSpacing: 20,
              columns: [
                DataColumn(
                    label: Text('Brand',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppColors.MainColor,
                        ))),
                DataColumn(
                    label: Text('Price',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppColors.MainColor,
                        ))),
                DataColumn(
                    label: Text('Action',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppColors.MainColor,
                        ))),
              ],
              rows: _selectedBrandsAndPrices.asMap().entries.map((entry) {
                int index = entry.key;
                var item = entry.value;
                return DataRow(cells: [
                  DataCell(Text(item['Brand']!,
                      style: GoogleFonts.poppins(fontSize: 14))),
                  DataCell(Text('${item['Price']} Rs',
                      style: GoogleFonts.poppins(fontSize: 14))),
                  DataCell(IconButton(
                    icon: Icon(Icons.delete, color: Colors.red.shade700),
                    onPressed: () => _deleteEntry(index),
                  )),
                ]);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _visitedTimeController.dispose();
    _timeSpentController.dispose();
    _otherBrandController.dispose();
    _racks.forEach((rack) => rack['controller'].dispose());
    _timer?.cancel();
    super.dispose();
  }
}
