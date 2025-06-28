import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:merchandiser_app/contant/colors.dart';
import 'package:merchandiser_app/provider/user_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:path_provider/path_provider.dart';

class MonetizeDataScreen extends StatefulWidget {
  final String shopName;
  final String shopId;
  final String shopDocId;
  final String scheduledDate;
  final String? distributorId;

  const MonetizeDataScreen({
    required this.shopName,
    required this.shopId,
    required this.shopDocId,
    required this.scheduledDate,
    this.distributorId,
    Key? key,
  }) : super(key: key);

  @override
  _MonetizeDataScreenState createState() => _MonetizeDataScreenState();
}

class _MonetizeDataScreenState extends State<MonetizeDataScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  Map<String, dynamic>? _shopData;
  Map<String, dynamic>? _visitData;
  String? _visitDocId;
  final TextEditingController _otherBrandController = TextEditingController();
  String? _merchandiserName;
  final TextEditingController _visitedTimeController = TextEditingController();
  final TextEditingController _timeSpentController = TextEditingController();
  final TextEditingController _scheduledDateController =
      TextEditingController();
  List<File> _outletBannerFiles = [];
  List<String> _outletBannerUrls = [];
  List<File> _beforeDisplayFiles = [];
  List<String> _beforeDisplayUrls = [];
  List<File> _afterDisplayFiles = [];
  List<String> _afterDisplayUrls = [];
  List<String> _unavailableBrands = [];
  Map<String, List<String>> _brandPriceSelection = {};
  List<Map<String, String>> _selectedBrandsAndPrices = [];
  final ImagePicker _picker = ImagePicker();
  Timer? _timer;
  int _timeSpentInSeconds = 0;
  final List<String> _rackOptions = ['Large', 'Medium', 'Small', 'Gandola'];
  List<Map<String, dynamic>> _racks = [];

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _merchandiserName = userProvider.merchandiserName;
    _scheduledDateController.text = widget.scheduledDate;
    _setCurrentTime();
    _racks.add({
      'type': null,
      'quantity': '1',
      'controller': TextEditingController(text: '1'),
      'formKey': GlobalKey<FormState>(),
    });
    _fetchShopData();
  }

  void _startTimer([int initialSeconds = 0]) {
    _timeSpentInSeconds = initialSeconds;
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

  Future<String?> _showActionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Choose Action',
            style:
                GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Text(
          'Do you want to update the existing data or append new data to it?',
          style: GoogleFonts.poppins(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child:
                Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'update'),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.MainColor),
            child:
                Text('Update', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickVisitedTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        final dateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        _visitedTimeController.text =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
      }
    }
  }

  String _getDayFromDate(DateTime date) {
    return DateFormat('EEEE').format(date);
  }

  Future<void> _fetchShopData() async {
    setState(() => _isLoading = true);
    try {
      print(
          'Fetching data for shop: ${widget.shopName}, Doc ID: ${widget.shopDocId}, Scheduled Date: ${widget.scheduledDate}');

      QuerySnapshot visitSnapshot = await FirebaseFirestore.instance
          .collection('Shops')
          .where('Shop Name', isEqualTo: widget.shopName)
          .where('scheduledDate', isEqualTo: widget.scheduledDate)
          .get();
      if (visitSnapshot.docs.isNotEmpty) {
        _visitDocId = visitSnapshot.docs.first.id;
        _visitData = visitSnapshot.docs.first.data() as Map<String, dynamic>;
        print('Visit Data: $_visitData');

        _visitedTimeController.text = _visitData?['visitedTime'] ??
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        String? timeSpent = _visitData?['timeSpent'];
        if (timeSpent != null && timeSpent.isNotEmpty) {
          int minutes = 0;
          int seconds = 0;
          if (timeSpent.contains('m')) {
            minutes = int.tryParse(timeSpent.split('m')[0].trim()) ?? 0;
            if (timeSpent.contains('s')) {
              seconds =
                  int.tryParse(timeSpent.split('m')[1].split('s')[0].trim()) ??
                      0;
            }
          }
          _timeSpentInSeconds = minutes * 60 + seconds;
          _startTimer(_timeSpentInSeconds);
        } else {
          _startTimer();
        }
        _timeSpentController.text = timeSpent ?? '';

        _racks.clear();
        if (_visitData?['Rack'] != null &&
            (_visitData!['Rack'] as List).isNotEmpty) {
          for (var rack in _visitData!['Rack']) {
            String type = rack['Type'] ?? '';
            String quantity = rack['Quantity'] ?? '1';
            if (_rackOptions.contains(type)) {
              _racks.add({
                'type': type,
                'quantity': quantity,
                'controller': TextEditingController(text: quantity),
                'formKey': GlobalKey<FormState>(),
              });
            }
          }
        } else {
          _racks.add({
            'type': null,
            'quantity': '1',
            'controller': TextEditingController(text: '1'),
            'formKey': GlobalKey<FormState>(),
          });
        }
        print('Fetched Racks: $_racks');

        _selectedBrandsAndPrices = _visitData?['unavailableBrand'] != null
            ? (_visitData!['unavailableBrand'] as List)
                .map((item) => Map<String, String>.from(item as Map))
                .toList()
            : [];

        _outletBannerUrls = _visitData?['BannerImage']?.cast<String>() ?? [];
        _beforeDisplayUrls = _visitData?['beforeDisplay']?.cast<String>() ?? [];
        _afterDisplayUrls = _visitData?['afterDisplay']?.cast<String>() ?? [];
      } else {
        print('No visit data found, fetching from Shops collection');
        DocumentSnapshot shopSnapshot = await FirebaseFirestore.instance
            .collection('Shops')
            .doc(widget.shopDocId)
            .get();

        if (shopSnapshot.exists) {
          _shopData = shopSnapshot.data() as Map<String, dynamic>;
          print('Shop Data: $_shopData');

          _visitedTimeController.text = _shopData?['visitedTime'] ??
              DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
          String? timeSpent = _shopData?['timeSpent'];
          if (timeSpent != null && timeSpent.isNotEmpty) {
            int minutes = 0;
            int seconds = 0;
            if (timeSpent.contains('m')) {
              minutes = int.tryParse(timeSpent.split('m')[0].trim()) ?? 0;
              if (timeSpent.contains('s')) {
                seconds = int.tryParse(
                        timeSpent.split('m')[1].split('s')[0].trim()) ??
                    0;
              }
            }
            _timeSpentInSeconds = minutes * 60 + seconds;
            _startTimer(_timeSpentInSeconds);
          } else {
            _startTimer();
          }
          _timeSpentController.text = timeSpent ?? '';

          _racks.clear();
          if (_shopData?['Rack'] != null &&
              (_shopData!['Rack'] as List).isNotEmpty) {
            for (var rack in _shopData!['Rack']) {
              String type = rack['Type'] ?? '';
              String quantity = rack['Quantity'] ?? '1';
              if (_rackOptions.contains(type)) {
                _racks.add({
                  'type': type,
                  'quantity': quantity,
                  'controller': TextEditingController(text: quantity),
                  'formKey': GlobalKey<FormState>(),
                });
              }
            }
          } else {
            _racks.add({
              'type': null,
              'quantity': '1',
              'controller': TextEditingController(text: '1'),
              'formKey': GlobalKey<FormState>(),
            });
          }
          print('Fetched Racks: $_racks');

          _selectedBrandsAndPrices = _shopData?['unavailableBrand'] != null
              ? (_shopData!['unavailableBrand'] as List)
                  .map((item) => Map<String, String>.from(item as Map))
                  .toList()
              : [];

          _outletBannerUrls = _shopData?['BannerImage']?.cast<String>() ?? [];
          _beforeDisplayUrls =
              _shopData?['beforeDisplay']?.cast<String>() ?? [];
          _afterDisplayUrls = _shopData?['afterDisplay']?.cast<String>() ?? [];

          print('Banner URLs: $_outletBannerUrls');
          print('Before Display URLs: $_beforeDisplayUrls');
          print('After Display URLs: $_afterDisplayUrls');
        } else {
          print('No document found for shop: ${widget.shopName}');
          _visitedTimeController.text =
              DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
          _timeSpentController.text = '';
          _startTimer();
        }
      }

      _outletBannerFiles.clear();
      _beforeDisplayFiles.clear();
      _afterDisplayFiles.clear();
      _unavailableBrands.clear();
      _brandPriceSelection.clear();
      for (var item in _selectedBrandsAndPrices) {
        String brand = item['Brand']!;
        String price = item['Price']!;
        if (!_brandPriceSelection.containsKey(brand)) {
          _brandPriceSelection[brand] = [];
          _unavailableBrands.add(brand);
        }
        if (!_brandPriceSelection[brand]!.contains(price)) {
          _brandPriceSelection[brand]!.add(price);
        }
      }
    } catch (e) {
      print('Error fetching shop data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error fetching shop data: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<String>> _uploadImages(
      String fieldName, List<File> images, BuildContext context) async {
    List<String> urls = [];
    print('Uploading ${images.length} images for $fieldName...');

    for (File image in images) {
      try {
        // Compress the image
        File? compressedImage = await _compressImage(image);
        if (compressedImage == null) {
          print('Error compressing image: $image');
          continue; // Skip to the next image if compression fails
        }

        String fileName = path.basename(compressedImage.path);
        print('Uploading compressed image: $fileName');

        // Upload to Firebase Storage
        Reference storageReference = FirebaseStorage.instance
            .ref()
            .child('shop_images/$fieldName/$fileName');
        UploadTask uploadTask = storageReference.putFile(compressedImage);
        TaskSnapshot taskSnapshot = await uploadTask;
        String url = await taskSnapshot.ref.getDownloadURL();
        print('Uploaded image URL: $url');
        urls.add(url);

        // Clean up: Delete the compressed file
        await compressedImage.delete();
      } catch (e) {
        print('Error uploading image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    return urls;
  }

// Function to compress the image
  Future<File?> _compressImage(File image) async {
    try {
      // Get temporary directory to store compressed image
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          path.join(tempDir.path, 'compressed_${path.basename(image.path)}');

      // Compress image
      var result = await FlutterImageCompress.compressAndGetFile(
        image.absolute.path,
        targetPath,
        quality: 30,
        minWidth: 512,
        minHeight: 512,
      );

      if (result != null) {
        return File(result.path);
      } else {
        print('Compression failed');
        return null;
      }
    } catch (e) {
      print('Error compressing image: $e');
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

  Future<void> _updateShopData() async {
    if (_formKey.currentState!.validate()) {
      // Show dialog to ask user whether to update or append
      String? action = await _showActionDialog();
      if (action == null) return; // User canceled

      setState(() => _isLoading = true);
      try {
        print('Starting update/append operation for shop: ${widget.shopName}');
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('Shops')
            .where('Shop Name', isEqualTo: widget.shopName)
            .where('scheduledDate', isEqualTo: widget.scheduledDate)
            .get();

        print('Documents found: ${snapshot.docs.length}');
        if (snapshot.docs.isNotEmpty) {
          print('Document ID: ${snapshot.docs.first.id}');
        }

        // Upload new files and combine with existing URLs
        List<String> bannerUrls = List.from(_outletBannerUrls);
        bannerUrls.addAll(
            await _uploadImages('BannerImage', _outletBannerFiles, context));
        List<String> beforeUrls = List.from(_beforeDisplayUrls);
        beforeUrls.addAll(
            await _uploadImages('beforeDisplay', _beforeDisplayFiles, context));
        List<String> afterUrls = List.from(_afterDisplayUrls);
        afterUrls.addAll(
            await _uploadImages('afterDisplay', _afterDisplayFiles, context));

        // Prepare the updated data map, preserving existing fields
        List<Map<String, String>> rackData = _racks
            .where((rack) => rack['type'] != null)
            .map((rack) => {
                  'Type': rack['type'] as String,
                  'Quantity': rack['quantity'] as String,
                })
            .toList();
        Map<String, dynamic> updatedData = {
          'Shop Name': widget.shopName,
          'visitedTime': _visitedTimeController.text,
          'timeSpent': _timeSpentController.text,
          'lastUpdated': DateTime.now(),
          'monetized': true,
          'visited': true,
          'Rack': rackData,
        };

        // Preserve existing fields from _shopData
        if (_shopData != null) {
          updatedData.addAll({
            'Latitude': _shopData!['Latitude'],
            'Longitude': _shopData!['Longitude'],
            'MerchandiserName': _shopData!['MerchandiserName'],
            'Shop ID': _shopData!['Shop ID'],
            'assignedMerchandisers': _shopData!['assignedMerchandisers'],
            'createdAt': _shopData!['createdAt'],
            'day': _shopData!['day'],
            'distributorId': _shopData!['distributorId'],
            'distributorName': _shopData!['distributorName'],
            'merchandiserId': _shopData!['merchandiserId'],
            'scheduledDate': _shopData!['scheduledDate'],
            'uidMerchandiser': _shopData!['uidMerchandiser'],
          });
        }

        if (snapshot.docs.isNotEmpty) {
          DocumentReference docRef = snapshot.docs.first.reference;
          if (action == 'update') {
            // Update: Overwrite the existing data
            print('Updating existing document...');
            updatedData.addAll({
              'unavailableBrand': _selectedBrandsAndPrices,
              'BannerImage': bannerUrls,
              'beforeDisplay': beforeUrls,
              'afterDisplay': afterUrls,
            });
            await docRef.set(updatedData, SetOptions(merge: true));
            print('Document updated successfully');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Data updated successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            // Navigate to home screen after a delay
            Future.delayed(Duration(seconds: 2), () {
              Navigator.pushReplacementNamed(context, '/home');
            });
          } else if (action == 'append') {
            // Append: Add new data to existing arrays
            print('Appending to existing document...');
            updatedData.addAll({
              'unavailableBrand':
                  FieldValue.arrayUnion(_selectedBrandsAndPrices),
              'BannerImage': FieldValue.arrayUnion(bannerUrls),
              'beforeDisplay': FieldValue.arrayUnion(beforeUrls),
              'afterDisplay': FieldValue.arrayUnion(afterUrls),
            });
            await docRef.set(updatedData, SetOptions(merge: true));
            print('Document appended successfully');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Data appended successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            // Navigate to home screen after a delay
            Future.delayed(Duration(seconds: 2), () {
              Navigator.pushReplacementNamed(context, '/home');
            });
          }
        } else {
          // If no document exists, create a new one
          print('Adding new document...');
          updatedData.addAll({
            'unavailableBrand': _selectedBrandsAndPrices,
            'BannerImage': bannerUrls,
            'beforeDisplay': beforeUrls,
            'afterDisplay': afterUrls,
            'createdAt': DateTime.now(),
            'day': DateFormat('EEEE').format(DateTime.now()),
            'scheduledDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          });
          await FirebaseFirestore.instance.collection('Shops').add(updatedData);
          print('New document added successfully');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Data added successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          // Navigate to home screen after a delay
          Future.delayed(Duration(seconds: 2), () {
            Navigator.pushReplacementNamed(context, '/home');
          });
        }
      } catch (e) {
        print('Error in update/append operation: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _isLoading = false);
        // Only fetch data if there's an error and we're staying on the screen
        if (mounted) {
          await _fetchShopData();
        }
      }
    }
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
            .child('shop_images/${widget.shopId}/$fieldName/$fileName');

        UploadTask uploadTask = storageReference.putFile(fileToUpload);
        TaskSnapshot taskSnapshot = await uploadTask.timeout(
          Duration(seconds: timeoutSeconds),
          onTimeout: () =>
              throw Exception('Image upload timed out: ${fileToUpload.path}'),
        );

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

  Future<void> _deleteImageFromStorage(String imageUrl) async {
    try {
      await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      print('Deleted image from storage: $imageUrl');
    } catch (e) {
      print('Error deleting image from storage: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete image: $e')),
      );
    }
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
          "Are you sure you want to save the data for ${widget.shopName} on ${widget.scheduledDate}?",
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
              backgroundColor: AppColors.MainColor,
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

  Future<void> _getImage(String imageType) async {
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
              _outletBannerFiles.add(File(pickedFile.path));
            } else if (imageType == 'beforeDisplay') {
              _beforeDisplayFiles.add(File(pickedFile.path));
            } else if (imageType == 'afterDisplay') {
              _afterDisplayFiles.add(File(pickedFile.path));
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

  void _deleteImage(String imageType, int index, bool isUrl) {
    setState(() {
      if (imageType == 'BannerImage') {
        if (isUrl) {
          String url = _outletBannerUrls[index];
          _outletBannerUrls.removeAt(index);
          _deleteImageFromStorage(url);
        } else {
          _outletBannerFiles.removeAt(index);
        }
      } else if (imageType == 'beforeDisplay') {
        if (isUrl) {
          String url = _beforeDisplayUrls[index];
          _beforeDisplayUrls.removeAt(index);
          _deleteImageFromStorage(url);
        } else {
          _beforeDisplayFiles.removeAt(index);
        }
      } else if (imageType == 'afterDisplay') {
        if (isUrl) {
          String url = _afterDisplayUrls[index];
          _afterDisplayUrls.removeAt(index);
          _deleteImageFromStorage(url);
        } else {
          _afterDisplayFiles.removeAt(index);
        }
      }
    });
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
      if (_brandPriceSelection[brand] == null) _brandPriceSelection[brand] = [];
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

  final Map<String, List<String>> _brandPriceRanges = {
    'Lays': ['20', '30', '50', '70', '100', '150'],
    'Wavy': ['30', '50', '70', '100'],
    'Kurkure': ['20', '30', '40', '60'],
    'Cheetos': ['10', '20', '30', '40', '50', '60', '70', '80', '100'],
    'Others': ['10', '20', '30', '40', '50', '60'],
  };

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
        backgroundColor: AppColors.MainColor,
        elevation: 4,
        shadowColor: Colors.black26,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchShopData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  _buildTextField(
                    controller: _scheduledDateController,
                    label: 'Scheduled Date',
                    icon: Icons.calendar_today,
                    readOnly: true,
                  ),
                  SizedBox(height: 20),
                  _buildTextField(
                    controller: _visitedTimeController,
                    label: 'Visited Time',
                    icon: Icons.access_time,
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                    onTap: _pickVisitedTime,
                  ),
                  SizedBox(height: 20),
                  _buildTextField(
                    controller: _timeSpentController,
                    label: 'Time Spent',
                    icon: Icons.timer,
                    readOnly: true,
                  ),
                  SizedBox(height: 25),
                  _buildImageSection('Outlet Banner', 'BannerImage',
                      _outletBannerFiles, _outletBannerUrls),
                  SizedBox(height: 25),
                  _buildImageSection('Before Display', 'beforeDisplay',
                      _beforeDisplayFiles, _beforeDisplayUrls),
                  SizedBox(height: 25),
                  _buildImageSection('After Display', 'afterDisplay',
                      _afterDisplayFiles, _afterDisplayUrls),
                  SizedBox(height: 25),
                  _buildUnavailableBrandsSection(),
                  SizedBox(height: 25),
                  if (_selectedBrandsAndPrices.isNotEmpty) _buildDataTable(),
                  SizedBox(height: 25),
                  _buildRackSelection(
                    context,
                    racks: _racks,
                    rackOptions: _rackOptions,
                    addRack: _addRack,
                    removeRack: _removeRack,
                    incrementQuantity: _incrementQuantity,
                    decrementQuantity: _decrementQuantity,
                    setState: setState,
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateShopData,
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(vertical: 18, horizontal: 30),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                      shadowColor: AppColors.MainColor.withOpacity(0.2),
                      backgroundColor: AppColors.MainColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'UpdateShop',
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
                          AlwaysStoppedAnimation<Color>(AppColors.MainColor),
                      strokeWidth: 5,
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Updating Data...",
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
    void Function()? onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
              color: AppColors.MainColor, fontWeight: FontWeight.w600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(icon, color: AppColors.MainColor),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
        style: GoogleFonts.poppins(fontSize: 16),
        validator: validator,
      ),
    );
  }

  Widget _buildImageSection(
      String title, String type, List<File> files, List<String> urls) {
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
              onPressed: _isLoading ? null : () => _getImage(type),
              icon: Icon(Icons.upload, size: 20),
              label: Text('Upload $title Image', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.Background,
                foregroundColor: AppColors.MainColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                elevation: 2,
              ),
            ),
            if (files.isNotEmpty || urls.isNotEmpty) ...[
              SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: files.length + urls.length,
                  itemBuilder: (context, index) {
                    if (index < urls.length) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                urls[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.error, color: Colors.red),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _deleteImage(type, index, true),
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
                      );
                    } else {
                      int fileIndex = index - urls.length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                files[fileIndex],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () =>
                                    _deleteImage(type, fileIndex, false),
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
                      );
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
                color: AppColors.MainColor,
              ),
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

  Widget _buildRackSelection(
    BuildContext context, {
    required List<Map<String, dynamic>> racks,
    required List<String> rackOptions,
    required VoidCallback addRack,
    required Function(int) removeRack,
    required Function(int) incrementQuantity,
    required Function(int) decrementQuantity,
    required StateSetter setState,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Screen size, orientation, and text scale
        final screenSize = MediaQuery.of(context).size;
        final isPortrait =
            MediaQuery.of(context).orientation == Orientation.portrait;
        final textScaleFactor = MediaQuery.of(context).textScaleFactor;

        // Responsive breakpoints
        final isMobile = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1200;
        final isDesktop = constraints.maxWidth >= 1200;

        // Dynamic sizing
        final cardPadding = screenSize.width * 0.04; // 4% of screen width
        final spacing = screenSize.width * 0.03; // 3% of screen width
        final borderRadius = isMobile ? 16.0 : 20.0;
        final fontSizeTitle = (isMobile ? 18.0 : 22.0) * textScaleFactor;
        final maxCardWidth = isDesktop
            ? 1000.0
            : isTablet
                ? 800.0
                : double.infinity;

        // Grid vs List layout
        final crossAxisCount = isDesktop
            ? 3
            : isTablet
                ? 2
                : 1;

        return SafeArea(
          minimum: EdgeInsets.symmetric(horizontal: isMobile ? 8.0 : 16.0),
          child: Card(
            elevation: 8,
            shadowColor: AppColors.MainColor.withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Container(
              constraints: BoxConstraints(maxWidth: maxCardWidth),
              margin: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Padding(
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
                              fontWeight: FontWeight.w700,
                              color: AppColors.MainColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        GestureDetector(
                          onTap: addRack,
                          child: Container(
                            padding: EdgeInsets.all(isMobile ? 6.0 : 8.0),
                            decoration: BoxDecoration(
                              color: AppColors.MainColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add,
                              color: AppColors.MainColor,
                              size: isMobile ? 24.0 : 28.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing),
                    racks.isEmpty
                        ? Container(
                            padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.grey.shade600,
                                  size: isMobile ? 20.0 : 24.0,
                                ),
                                SizedBox(width: spacing),
                                Flexible(
                                  child: Text(
                                    'No racks added. Tap + to start.',
                                    style: GoogleFonts.poppins(
                                      fontSize: (isMobile ? 14.0 : 16.0) *
                                          textScaleFactor,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : MediaQuery.removePadding(
                            context: context,
                            removeTop: true,
                            child: isMobile
                                ? ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: racks.length,
                                    separatorBuilder: (context, index) =>
                                        SizedBox(height: spacing),
                                    itemBuilder: (context, index) =>
                                        _buildRackItem(
                                      index,
                                      racks,
                                      rackOptions,
                                      removeRack,
                                      incrementQuantity,
                                      decrementQuantity,
                                      setState,
                                      screenSize.width,
                                      textScaleFactor,
                                      isMobile,
                                    ),
                                  )
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: spacing,
                                      mainAxisSpacing: spacing,
                                      childAspectRatio:
                                          isPortrait ? 3 / 2 : 4 / 2,
                                    ),
                                    itemCount: racks.length,
                                    itemBuilder: (context, index) =>
                                        _buildRackItem(
                                      index,
                                      racks,
                                      rackOptions,
                                      removeRack,
                                      incrementQuantity,
                                      decrementQuantity,
                                      setState,
                                      screenSize.width,
                                      textScaleFactor,
                                      isMobile,
                                    ),
                                  ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRackItem(
    int index,
    List<Map<String, dynamic>> racks,
    List<String> rackOptions,
    Function(int) removeRack,
    Function(int) incrementQuantity,
    Function(int) decrementQuantity,
    StateSetter setState,
    double screenWidth,
    double textScaleFactor,
    bool isMobile,
  ) {
    final isVerySmallScreen = screenWidth < 440;
    final fontSize = (isMobile ? 12.0 : 14.0) * textScaleFactor;
    final padding = screenWidth * 0.02;
    final qtyFieldWidth = isVerySmallScreen
        ? screenWidth * 0.2
        : isMobile
            ? screenWidth * 0.25
            : 100.0;
    final iconSize = isMobile ? 18.0 : 20.0;

    return AnimatedOpacity(
      opacity: racks[index]['type'] != null ? 1.0 : 0.9,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: EdgeInsets.all(padding),
        margin: EdgeInsets.symmetric(vertical: padding * 0.5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Form(
          key: racks[index]['formKey'],
          child: Wrap(
            spacing: padding,
            runSpacing: padding,
            children: [
              SizedBox(
                width: isVerySmallScreen
                    ? screenWidth - (padding * 4)
                    : screenWidth * 0.5,
                child: DropdownButtonFormField<String>(
                  value: racks[index]['type'],
                  hint: Text(
                    'Select Rack Type',
                    style: GoogleFonts.poppins(
                      fontSize: fontSize,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  items: rackOptions.map((String option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(
                        option,
                        style: GoogleFonts.poppins(
                          fontSize: fontSize,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      racks[index]['type'] = value;
                    });
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.MainColor,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.ErrorColor,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: padding,
                      vertical: isMobile ? 10.0 : 14.0,
                    ),
                    prefixIcon: Icon(
                      Icons.shelves,
                      color: AppColors.MainColor,
                      size: isMobile ? 18.0 : 20.0,
                    ),
                  ),
                  validator: (value) =>
                      value == null ? 'Select a rack type' : null,
                  dropdownColor: Colors.white,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.MainColor,
                    size: isMobile ? 20.0 : 24.0,
                  ),
                  isDense: true,
                ),
              ),
              SizedBox(
                width: qtyFieldWidth,
                child: TextFormField(
                  controller: racks[index]['controller'],
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    labelStyle: GoogleFonts.poppins(
                      fontSize: fontSize * 0.9,
                      color: Colors.grey.shade500,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.MainColor,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.ErrorColor,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: padding,
                      vertical: isMobile ? 10.0 : 14.0,
                    ),
                    suffixIcon: isVerySmallScreen
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => incrementQuantity(index),
                                child: Icon(
                                  Icons.arrow_drop_up,
                                  size: iconSize,
                                  color: AppColors.MainColor,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => decrementQuantity(index),
                                child: Icon(
                                  Icons.arrow_drop_down,
                                  size: iconSize,
                                  color: AppColors.ErrorColor,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: fontSize),
                  onChanged: (value) {
                    setState(() {
                      racks[index]['quantity'] = value.isEmpty ? '1' : value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter qty';
                    }
                    if (int.tryParse(value) == null || int.parse(value) <= 0) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
              if (!isVerySmallScreen)
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => incrementQuantity(index),
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 4.0 : 6.0),
                        decoration: BoxDecoration(
                          color: AppColors.MainColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: iconSize,
                        ),
                      ),
                    ),
                    SizedBox(height: padding),
                    GestureDetector(
                      onTap: () => decrementQuantity(index),
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 4.0 : 6.0),
                        decoration: BoxDecoration(
                          color: AppColors.ErrorColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.remove,
                          color: Colors.white,
                          size: iconSize,
                        ),
                      ),
                    ),
                    SizedBox(height: padding),
                    GestureDetector(
                      onTap: () => removeRack(index),
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 4.0 : 6.0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.grey.shade700,
                          size: iconSize,
                        ),
                      ),
                    ),
                  ],
                ),
              if (isVerySmallScreen)
                GestureDetector(
                  onTap: () => removeRack(index),
                  child: Container(
                    padding: EdgeInsets.all(isMobile ? 4.0 : 6.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.grey.shade700,
                      size: iconSize,
                    ),
                  ),
                ),
            ],
          ),
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
    _scheduledDateController.dispose();
    _otherBrandController.dispose();
    _racks.forEach((rack) => rack['controller'].dispose());
    _stopTimer();
    super.dispose();
  }
}
