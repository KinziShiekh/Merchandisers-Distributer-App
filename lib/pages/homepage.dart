import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:merchandiser_app/pages/Gallery/gallery.dart';
import 'package:merchandiser_app/pages/Report/Report.dart';
import 'package:merchandiser_app/pages/dashboard/dashboard.dart';
import 'package:merchandiser_app/pages/profile/profiel_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:merchandiser_app/Widgets/container_city_state.dart';
import 'package:merchandiser_app/Widgets/containers.dart';
import 'package:merchandiser_app/pages/outlets/outlets.dart';
import 'package:merchandiser_app/provider/user_provider.dart';
import 'package:merchandiser_app/auth/logout/logout.dart';
import 'package:merchandiser_app/contant/colors.dart';
import 'package:merchandiser_app/contant/images.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/gestures.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _currentPosition;
  CameraPosition? _lastMapPosition;
  bool _locationPermissionGranted = false;
  DateTime? _selectedDate; // For single date selection
  DateTimeRange? _selectedDateRange; // For date range selection
  bool _isRangeMode = false; // Toggle between single date and range
  MapType _currentMapType = MapType.normal;
  Set<Polygon> _polygons = {};
  Set<Circle> _circles = {};
  double customPadding = 50.0;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now(); // Default to today
    checkLocationPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUserShops();
    });
  }

  Future<void> _setMapStyle() async {
    try {
      String style = await rootBundle.loadString('assets/map_style.json');
      _mapController?.setMapStyle(style);
    } catch (e) {
      debugPrint('Error setting map style: $e');
    }
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  Future<void> _zoomIn() async {
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.zoomOut());
  }

  Future<void> _goToMyLocation() async {
    try {
      final controller = await _controller.future;
      Position position = await Geolocator.getCurrentPosition();
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15.0,
        ),
      ));
    } catch (e) {
      debugPrint('Error going to location: $e');
    }
  }

  Future<void> _resetRotation() async {
    if (_lastMapPosition != null) {
      final controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          bearing: 0.0,
          target: _lastMapPosition!.target,
          zoom: _lastMapPosition!.zoom,
        ),
      ));
    }
  }

  Future<void> checkLocationPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      setState(() {
        _locationPermissionGranted = true;
      });
      await _fetchCurrentLocation();
    } else {
      debugPrint("Location permission denied");
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: _currentPosition!,
            infoWindow: const InfoWindow(title: "Your Location"),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
      });

      final GoogleMapController controller = await _controller.future;
      controller
          .animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 15));
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  Future<void> _fetchUserShops() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && _currentPosition != null) {
      try {
        CollectionReference shopsRef =
            FirebaseFirestore.instance.collection('Shops');
        QuerySnapshot snapshot = await shopsRef
            .where('assignedMerchandisers',
                isEqualTo: userProvider.merchandiserName)
            .get();

        _markers.removeWhere(
            (marker) => marker.markerId.value != 'current_location');
        _polylines.clear();

        List<QueryDocumentSnapshot> docs = snapshot.docs;
        double minDistance = double.infinity;
        String? closestShopId;

        for (var doc in docs) {
          Map<String, dynamic> shop = doc.data() as Map<String, dynamic>;
          double lat = shop['Latitude']?.toDouble() ?? 0.0;
          double lng = shop['Longitude']?.toDouble() ?? 0.0;
          LatLng shopPosition = LatLng(lat, lng);

          // Parse scheduledDate
          DateTime? shopDate;
          if (shop['scheduledDate'] != null) {
            if (shop['scheduledDate'] is Timestamp) {
              shopDate = (shop['scheduledDate'] as Timestamp).toDate();
            } else if (shop['scheduledDate'] is String) {
              shopDate = DateTime.parse(shop['scheduledDate']);
            } else {
              shopDate = shop['scheduledDate'] as DateTime;
            }
          }

          // Apply date filter
          bool matchesDate = true;
          if (shopDate != null) {
            if (_isRangeMode && _selectedDateRange != null) {
              matchesDate = shopDate.isAfter(_selectedDateRange!.start
                      .subtract(const Duration(days: 1))) &&
                  shopDate.isBefore(
                      _selectedDateRange!.end.add(const Duration(days: 1)));
            } else if (!_isRangeMode && _selectedDate != null) {
              matchesDate = shopDate.year == _selectedDate!.year &&
                  shopDate.month == _selectedDate!.month &&
                  shopDate.day == _selectedDate!.day;
            }
          } else if ((_isRangeMode && _selectedDateRange != null) ||
              (!_isRangeMode && _selectedDate != null)) {
            matchesDate =
                false; // No date in shop data, exclude if filter applied
          }

          if (matchesDate) {
            double distance = Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  shopPosition.latitude,
                  shopPosition.longitude,
                ) /
                1000;

            if (distance < minDistance) {
              minDistance = distance;
              closestShopId = doc.id;
            }

            _markers.add(
              Marker(
                markerId: MarkerId(doc.id),
                position: shopPosition,
                infoWindow: InfoWindow(
                  title: shop['Shop Name'],
                  snippet: "Distance: ${distance.toStringAsFixed(2)} km",
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange),
              ),
            );

            _polylines.add(
              Polyline(
                polylineId: PolylineId(doc.id),
                points: [_currentPosition!, shopPosition],
                color: Colors.orange,
                width: 3,
              ),
            );
          }
        }

        if (closestShopId != null) {
          _markers
              .removeWhere((marker) => marker.markerId.value == closestShopId);
          _polylines.removeWhere(
              (polyline) => polyline.polylineId.value == closestShopId);

          var closestDoc = docs.firstWhere((doc) => doc.id == closestShopId);
          Map<String, dynamic> closestShop =
              closestDoc.data() as Map<String, dynamic>;
          double lat = closestShop['Latitude']?.toDouble() ?? 0.0;
          double lng = closestShop['Longitude']?.toDouble() ?? 0.0;
          LatLng closestPosition = LatLng(lat, lng);

          _markers.add(
            Marker(
              markerId: MarkerId(closestShopId),
              position: closestPosition,
              infoWindow: InfoWindow(
                title: closestShop['Shop Name'],
                snippet:
                    " Distance: ${minDistance.toStringAsFixed(2)} km (Closest)",
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
            ),
          );

          _polylines.add(
            Polyline(
              polylineId: PolylineId(closestShopId),
              points: [_currentPosition!, closestPosition],
              color: Colors.green,
              width: 4,
            ),
          );
        }

        setState(() {});
      } catch (e) {
        debugPrint("Error fetching user shops: $e");
      }
    }
  }

  void _showDatePicker() {
    bool isRangeModeLocal = _isRangeMode;

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
              builder: (context, setDialogState) => Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  width: MediaQuery.of(context).size.width * 0.9,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1), blurRadius: 10),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with title and icon toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isRangeModeLocal
                                  ? 'Select Date Range'
                                  : 'Select a Date',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.MainColor,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  isRangeModeLocal = !isRangeModeLocal;
                                  _selectedDate = null;
                                  _selectedDateRange = null;
                                });
                                setState(() {
                                  _isRangeMode = isRangeModeLocal;
                                  _fetchUserShops();
                                });
                              },
                              icon: Icon(
                                isRangeModeLocal
                                    ? Icons.event
                                    : Icons.date_range,
                                color: AppColors.MainColor,
                              ),
                              tooltip: isRangeModeLocal
                                  ? 'Switch to Single Date'
                                  : 'Switch to Date Range',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SfDateRangePicker(
                          onSelectionChanged:
                              (DateRangePickerSelectionChangedArgs args) {
                            setDialogState(() {
                              if (isRangeModeLocal &&
                                  args.value is PickerDateRange) {
                                _selectedDateRange = DateTimeRange(
                                  start: args.value.startDate,
                                  end: args.value.endDate ??
                                      args.value.startDate,
                                );
                                _selectedDate = null;
                              } else if (!isRangeModeLocal &&
                                  args.value is DateTime) {
                                _selectedDate = args.value;
                                _selectedDateRange = null;
                              }
                            });
                          },
                          selectionMode: isRangeModeLocal
                              ? DateRangePickerSelectionMode.range
                              : DateRangePickerSelectionMode.single,
                          initialSelectedDate: _selectedDate ?? DateTime.now(),
                          initialSelectedRange: isRangeModeLocal
                              ? PickerDateRange(
                                  _selectedDateRange?.start ??
                                      DateTime.now()
                                          .subtract(const Duration(days: 7)),
                                  _selectedDateRange?.end ?? DateTime.now(),
                                )
                              : null,
                          minDate: DateTime(2020),
                          maxDate: DateTime(2026),
                          backgroundColor: Colors.grey[50],
                          todayHighlightColor: AppColors.MainColor,
                          selectionColor: AppColors.MainColor.withOpacity(0.4),
                          rangeSelectionColor:
                              AppColors.MainColor.withOpacity(0.2),
                          headerStyle: DateRangePickerHeaderStyle(
                            textStyle: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.MainColor,
                            ),
                          ),
                          monthCellStyle: DateRangePickerMonthCellStyle(
                            textStyle: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedDate = null;
                                  _selectedDateRange = null;
                                  _fetchUserShops();
                                });
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Clear',
                                style: GoogleFonts.poppins(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _isRangeMode = isRangeModeLocal;
                                          _fetchUserShops();
                                        });
                                        Navigator.pop(context);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.MainColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        'OK',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ));
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Text(
            userProvider.distributorName,
            key: ValueKey(userProvider.distributorName),
            style: GoogleFonts.poppins(
              fontSize: 20,
              color: AppColors.MainColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.push(context, _buildProfileRoute()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.MainColor,
                    AppColors.MainColor.withOpacity(0.8)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.transparent,
                child: Text(
                  FirebaseAuth.instance.currentUser?.email
                          ?.substring(0, 1)
                          .toUpperCase() ??
                      'U',
                  style: GoogleFonts.poppins(
                    color: AppColors.Background,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.MainColor, size: 28),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tapped Lays Logo'))),
              child: Image.asset(AppImages.laysLogo,
                  height: 40, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchUserShops();
        },
        color: AppColors.MainColor,
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ContainerCityState(),
              const SizedBox(height: 20),
              _buildQuickActions(context),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Find nearby shops with our map',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.MainColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: _showDatePicker,
                        child: Container(
                          height: 40,
                          width: MediaQuery.of(context).size.width *
                              0.6, // 60% of screen width
                          constraints: const BoxConstraints(
                            minWidth: 150, // Minimum width for smaller screens
                            maxWidth: 300, // Maximum width for larger screens
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.MainColor.withOpacity(0.5),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: AppColors.MainColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _selectedDate != null
                                            ? DateFormat('EEEE')
                                                .format(_selectedDate!)
                                            : _selectedDateRange != null
                                                ? '${DateFormat('EEEE').format(_selectedDateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}'
                                                : 'Select Date',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: AppColors.MainColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: AppColors.MainColor,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Container(
                        height: 20,
                        width: 20,
                        color: Colors.green,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Closest Shop',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                height: 400,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      GoogleMap(
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: true,
                        zoomControlsEnabled: false,
                        zoomGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                        markers: _markers,
                        polylines: _polylines,
                        polygons: _polygons,
                        circles: _circles,
                        mapType: _currentMapType,
                        onMapCreated: (GoogleMapController controller) {
                          _controller.complete(controller);
                          _mapController = controller;
                          _setMapStyle();
                        },
                        initialCameraPosition: _kGooglePlex,
                        onCameraMove: (CameraPosition position) {
                          _lastMapPosition = position;
                        },
                        gestureRecognizers: {
                          Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer()),
                        },
                      ),
                      Positioned(
                        right: 10,
                        bottom: 100,
                        child: Column(
                          children: [
                            FloatingActionButton(
                              heroTag: 'mapType',
                              mini: true,
                              backgroundColor: Colors.white,
                              onPressed: _toggleMapType,
                              child:
                                  const Icon(Icons.layers, color: Colors.blue),
                            ),
                            const SizedBox(height: 10),
                            FloatingActionButton(
                              heroTag: 'zoomIn',
                              mini: true,
                              backgroundColor: Colors.white,
                              onPressed: _zoomIn,
                              child: const Icon(Icons.add, color: Colors.blue),
                            ),
                            const SizedBox(height: 10),
                            FloatingActionButton(
                              heroTag: 'zoomOut',
                              mini: true,
                              backgroundColor: Colors.white,
                              onPressed: _zoomOut,
                              child:
                                  const Icon(Icons.remove, color: Colors.blue),
                            ),
                            const SizedBox(height: 10),
                            FloatingActionButton(
                              heroTag: 'myLocation',
                              mini: true,
                              backgroundColor: Colors.white,
                              onPressed: _goToMyLocation,
                              child: const Icon(Icons.my_location,
                                  color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: FloatingActionButton(
                          heroTag: 'resetRotation',
                          mini: true,
                          backgroundColor: Colors.white,
                          onPressed: _resetRotation,
                          child: const Icon(Icons.explore, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PageRouteBuilder _buildProfileRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const ProfileScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.1);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      opaque: false,
      barrierColor: Colors.black.withOpacity(0.2),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ContainerWithImageText(
              key: UniqueKey(),
              imageUrl: AppImages.Outlet,
              text: 'Outlets',
              containerColor: AppColors.Background,
              onTap: () =>
                  Navigator.push(context, _buildPageRoute(OutletsScreen())),
            ),
            ContainerWithImageText(
              key: UniqueKey(),
              imageUrl: AppImages.Gallery,
              text: 'Gallery',
              containerColor: AppColors.Background,
              onTap: () => Navigator.push(
                  context, _buildPageRoute(const GalleryScreen())),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ContainerWithImageText(
              key: UniqueKey(),
              imageUrl: AppImages.Report,
              text: 'Report',
              containerColor: AppColors.Background,
              onTap: () => Navigator.push(
                  context, _buildPageRoute(const ReportScreen())),
            ),
            ContainerWithImageText(
              key: UniqueKey(),
              imageUrl: AppImages.Dashboared,
              text: 'Dashboard',
              containerColor: AppColors.Background,
              onTap: () => Navigator.push(
                  context, _buildPageRoute(const DashboardScreen())),
            ),
          ],
        ),
      ],
    );
  }

  PageRouteBuilder _buildPageRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
