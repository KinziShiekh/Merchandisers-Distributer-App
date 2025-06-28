import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:merchandiser_app/contant/colors.dart';
import 'package:merchandiser_app/pages/homepage.dart';
import 'package:merchandiser_app/pages/outlets/outlets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:merchandiser_app/provider/user_provider.dart';
import 'package:path/path.dart' as path;

class OutletDataScreen extends StatefulWidget {
  final String shopName;
  final String? distributorId;
  final String shopDocId; // Firestore document ID for updating shop status
  final String scheduledDate;

  const OutletDataScreen(
      {super.key,
      required this.shopName,
      this.distributorId,
      required this.shopDocId,
      required this.scheduledDate});

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
  String? _selectedRack; // To store the selected rack type
  final List<String> _rackOptions = [
    'Large',
    'Medium',
    'Small',
    'Gandola'
  ]; // Rack options

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

  // Define controller in the State class to persist across rebuilds
  final TextEditingController _otherBrandController = TextEditingController();

  // Future<void> _saveData() async {
  //   bool? confirmSave = await _showConfirmationDialog();
  //   if (confirmSave != true) return;

  //   if (_formKey.currentState!.validate()) {
  //     setState(() => _isLoading = true);
  //     CollectionReference shops =
  //         FirebaseFirestore.instance.collection('Shops');

  //     try {
  //       // Fetch shop data
  //       QuerySnapshot querySnapshot = await shops
  //           .where('assignedMerchandisers', isEqualTo: _merchandiserName)
  //           .where('Shop Name', isEqualTo: widget.shopName)
  //           .get();

  //       if (querySnapshot.docs.isEmpty) {
  //         throw Exception('No matching shop found');
  //       }

  //       var existingDoc = querySnapshot.docs.first;
  //       Map<String, dynamic> shopData =
  //           existingDoc.data() as Map<String, dynamic>;
  //       String shopDay = shopData['day'] ?? _getDayFromDate(DateTime.now());
  //       String scheduledDate = shopData['scheduledDate'] ??
  //           DateFormat('yyyy-MM-dd').format(DateTime.now());

  //       // Upload images in parallel
  //       List<Future<String>> uploadTasks = [
  //         ..._outletBannerImages
  //             .map((image) => _uploadImageToStorage('BannerImage', image)),
  //         ..._beforeDisplayImages.map(
  //             (image) => _uploadImageToStorage('beforeDisplayImage', image)),
  //         ..._afterDisplayImages.map(
  //             (image) => _uploadImageToStorage('afterDisplayImage', image)),
  //       ];

  //       List<String> allUrls = await Future.wait(uploadTasks);
  //       int bannerCount = _outletBannerImages.length;
  //       int beforeCount = _beforeDisplayImages.length;

  //       List<String> outletBannerUrls = allUrls.sublist(0, bannerCount);
  //       List<String> beforeDisplayUrls =
  //           allUrls.sublist(bannerCount, bannerCount + beforeCount);
  //       List<String> afterDisplayUrls =
  //           allUrls.sublist(bannerCount + beforeCount);
  //       List<Map<String, String>> rackData = _racks
  //           .where((rack) => rack['type'] != null)
  //           .map((rack) => {
  //                 'Type': rack['type'] as String,
  //                 'Quantity': rack['quantity'] as String,
  //               })
  //           .toList();

  //       // Update shop data
  //       await shops.doc(existingDoc.id).update({
  //         'unavailableBrand': _selectedBrandsAndPrices,
  //         'visitedTime': _visitedTimeController.text,
  //         'timeSpent': _timeSpentController.text,
  //         'BannerImage': outletBannerUrls,
  //         'beforeDisplay': beforeDisplayUrls,
  //         'afterDisplay': afterDisplayUrls,
  //         'visited': true,
  //         'Rack': rackData, // Save as array of racks
  //       });

  //       // Update merchandiser goals in background
  //       _updateMerchandiserAchievedGoals(shopDay, scheduledDate).then((_) {
  //         debugPrint("Merchandiser goals updated successfully");
  //       }).catchError((e) {
  //         debugPrint("Error updating goals: $e");
  //       });

  //       _stopTimer();
  //       setState(() => _isLoading = false);

  //       if (!mounted) return;

  //       // Show success dialog and wait for user action before navigating
  //       await showDialog(
  //         context: context,
  //         builder: (BuildContext context) {
  //           return AlertDialog(
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(20),
  //             ),
  //             backgroundColor: Colors.white,
  //             elevation: 10,
  //             title: Row(
  //               children: [
  //                 Icon(
  //                   Icons.check_circle,
  //                   color: Colors.orange.shade700,
  //                   size: 30,
  //                 ),
  //                 SizedBox(width: 10),
  //                 Expanded(
  //                   child: Text(
  //                     "Success",
  //                     style: GoogleFonts.poppins(
  //                       fontSize: 22,
  //                       fontWeight: FontWeight.bold,
  //                       color: Colors.black87,
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             content: Text(
  //               "Your shop data has been saved successfully!",
  //               style: GoogleFonts.poppins(
  //                 fontSize: 16,
  //                 color: Colors.grey.shade800,
  //                 height: 1.5,
  //               ),
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () {
  //                   Navigator.of(context).pop();
  //                   Navigator.pushReplacement(
  //                     context,
  //                     MaterialPageRoute(builder: (context) => HomeScreen()),
  //                   );
  //                 },
  //                 style: TextButton.styleFrom(
  //                   padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(10),
  //                   ),
  //                   backgroundColor: Colors.orange.shade700,
  //                   foregroundColor: Colors.white,
  //                 ),
  //                 child: Text(
  //                   "OK",
  //                   style: GoogleFonts.poppins(
  //                     fontSize: 16,
  //                     fontWeight: FontWeight.w600,
  //                     color: Colors.white,
  //                   ),
  //                 ),
  //               ),
  //             ],
  //             actionsPadding: EdgeInsets.only(right: 20, bottom: 15),
  //           );
  //         },
  //       );
  //     } catch (e) {
  //       setState(() => _isLoading = false);
  //       if (!mounted) return;
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text("Error: ${e.toString()}")),
  //       );
  //     }
  //   } else {
  //     setState(() => _isLoading = false);
  //   }
  // }

  Widget _buildRackSelection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rack Selection',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                _buildAddButton(),
              ],
            ),
            SizedBox(height: 12),
            _racks.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _racks.length,
                    separatorBuilder: (context, index) => SizedBox(height: 16),
                    itemBuilder: (context, index) => _buildRackItem(index),
                  ),
          ],
        ),
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

  // Future<String> _uploadImageToStorage(String fieldName, File imageFile) async {
  //   try {
  //     String fileName = path.basename(imageFile.path);
  //     Reference storageReference = FirebaseStorage.instance
  //         .ref()
  //         .child('shop_images/$fieldName/$fileName');
  //     UploadTask uploadTask = storageReference.putFile(imageFile);
  //     TaskSnapshot taskSnapshot = await uploadTask;
  //     return await taskSnapshot.ref.getDownloadURL();
  //   } catch (e) {
  //     throw Exception("Error uploading image: $e");
  //   }
  // }

  Future<String?> _uploadImageToStorage(String fieldName, File imageFile,
      {int retries = 3}) async {
    // Determine timeout based on network type
    var connectivityResult = await Connectivity().checkConnectivity();
    int timeoutSeconds =
        connectivityResult == ConnectivityResult.wifi ? 60 : 90;

    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        print(
            'Attempt $attempt/$retries: Uploading image: ${imageFile.path}, size: ${await imageFile.length() / 1024} KB');

        // Compress the image
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
          return null; // Allow partial data saving
        }
        await Future.delayed(Duration(seconds: 3)); // Wait before retrying
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
        quality: 40, // Aggressive compression
        minWidth: 400, // Lower resolution
        minHeight: 400,
      );

      if (result != null) {
        print(
            'Compressed image: ${result.path}, size: ${await File(result.path).length() / 1024} KB');
        return File(result.path);
      }
      return null;
    } catch (e) {
      print("Error compressing image ${imageFile.path}: $e");
      return null; // Fallback to original image
    }
  }

  Future<bool> _checkNetwork() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    bool isConnected = connectivityResult != ConnectivityResult.none;
    print(
        'Network status: ${isConnected ? 'Connected ($connectivityResult)' : 'Disconnected'}');
    return isConnected;
  }

  Future<void> _saveData() async {
    bool? confirmSave = await _showConfirmationDialog();
    if (confirmSave != true) return;

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      CollectionReference shops =
          FirebaseFirestore.instance.collection('Shops');

      // Check network connectivity
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
            'Fetching shop data for merchandiser: $_merchandiserName, shop: ${widget.shopName}');
        QuerySnapshot querySnapshot = await shops
            .where('assignedMerchandisers', isEqualTo: _merchandiserName)
            .where('Shop Name', isEqualTo: widget.shopName)
            .get();

        if (querySnapshot.docs.isEmpty) {
          throw Exception('No matching shop found');
        }

        var existingDoc = querySnapshot.docs.first;
        Map<String, dynamic> shopData =
            existingDoc.data() as Map<String, dynamic>;
        String shopDay = shopData['day'] ?? _getDayFromDate(DateTime.now());
        String scheduledDate = shopData['scheduledDate'] ??
            DateFormat('yyyy-MM-dd').format(DateTime.now());

        // Upload images sequentially
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

        // Filter valid URLs and log failed ones
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

        // Prepare data to update
        Map<String, dynamic> updateData = {
          'unavailableBrand': _selectedBrandsAndPrices,
          'visitedTime': _visitedTimeController.text,
          'timeSpent': _timeSpentController.text,
          'BannerImage': validOutletBannerUrls,
          'beforeDisplay': validBeforeDisplayUrls,
          'afterDisplay': validAfterDisplayUrls,
          'visited': true,
          'Rack': rackData,
          'failedUploads':
              failedUploads, // Store failed upload paths for debugging
        };

        // Estimate document size
        int estimatedSize = updateData.toString().length * 2;
        if (estimatedSize > 900000) {
          print(
              'Warning: Document size may exceed Firestore 1MB limit: $estimatedSize bytes');
        }

        print('Updating shop document: ${existingDoc.id}');
        await shops.doc(existingDoc.id).update(updateData);
        print('Shop data updated successfully');

        // Update merchandiser goals in background
        _updateMerchandiserAchievedGoals(shopDay, scheduledDate).then((_) {
          print("Merchandiser goals updated successfully");
        }).catchError((e) {
          print("Error updating goals: $e");
        });

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

  Future<void> getImage(String imageType) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Select Image Source',
            style:
                GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera, color: Colors.orange.shade700),
              title: Text('Camera', style: GoogleFonts.poppins(fontSize: 16)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

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
                  _buildRackSelection(), // Added rack dropdown here
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
                    ).copyWith(
                      overlayColor: MaterialStateProperty.resolveWith<Color>(
                        (states) => states.contains(MaterialState.hovered)
                            ? Colors.orange.shade900
                            : Colors.transparent,
                      ),
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
          labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
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
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => getImage(type),
              icon: Icon(Icons.upload, size: 20),
              label: Text('Upload $title Image', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade100,
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
    // Custom brands will use the "Others" price range
    'Others': ['10', '20', '30', '40', '50', '60'],
  };

  void _addCustomBrand() {
    String newBrand = _otherBrandController.text.trim();
    if (newBrand.isNotEmpty) {
      setState(() {
        if (!_unavailableBrands.contains(newBrand)) {
          _unavailableBrands.add(newBrand);
        }
        _otherBrandController.clear(); // Clear after adding
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

  // Determine the price range for a brand
  List<String> _getPriceRangeForBrand(String brand) {
    // If the brand is predefined, return its specific price range
    if (_brandPriceRanges.containsKey(brand)) {
      return _brandPriceRanges[brand]!;
    }
    // For custom brands, use the "Others" price range
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
                  color: Colors.black87),
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
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: DataTable(
          columnSpacing: 20,
          dataRowHeight: 60,
          headingRowHeight: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          columns: [
            DataColumn(
              label: Text(
                'Brand',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Price',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Action',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
          rows: _selectedBrandsAndPrices.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, String> data = entry.value;
            return DataRow(
              cells: [
                DataCell(Text(data['Brand']!,
                    style: GoogleFonts.poppins(fontSize: 14))),
                DataCell(Text(data['Price']!,
                    style: GoogleFonts.poppins(fontSize: 14))),
                DataCell(
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red.shade700),
                    onPressed: () => _deleteEntry(index),
                    hoverColor: Colors.red.shade100,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getDayFromDate(DateTime date) {
    return DateFormat('EEEE').format(date);
  }

  @override
  void dispose() {
    _stopTimer();
    _otherBrandController.dispose();
    _visitedTimeController.dispose();
    _timeSpentController.dispose();
    super.dispose();
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _addRack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.MainColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.MainColor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Colors.white, size: 18),
            SizedBox(width: 4),
            Text(
              'Add Rack',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'No racks added. Tap "Add Rack" to start.',
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildRackItem(int index) {
    return Form(
      key: _racks[index]['formKey'],
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _racks[index]['type'],
                    hint: Text(
                      'Select Rack',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    icon:
                        Icon(Icons.arrow_drop_down, color: AppColors.MainColor),
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.black87),
                    items: _rackOptions.map((String rack) {
                      return DropdownMenuItem<String>(
                        value: rack,
                        child: Row(
                          children: [
                            Icon(Icons.shelves,
                                size: 18, color: AppColors.MainColor),
                            SizedBox(width: 8),
                            Text(rack),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _racks[index]['type'] = newValue;
                      });
                    },
                    decoration: InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: AppColors.MainColor, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) =>
                        value == null ? 'Select a rack type' : null,
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _racks[index]['controller'],
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      labelStyle: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.grey.shade600),
                      hintText: 'Enter quantity',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.grey.shade400),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: AppColors.MainColor, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon:
                          Icon(Icons.numbers, color: AppColors.MainColor),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter quantity';
                      }
                      if (int.tryParse(value) == null ||
                          int.parse(value) <= 0) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        _racks[index]['quantity'] = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            Column(
              children: [
                _buildQuantityButton(
                  icon: Icons.add,
                  onPressed: () => _incrementQuantity(index),
                ),
                SizedBox(height: 8),
                _buildQuantityButton(
                  icon: Icons.remove,
                  onPressed: () => _decrementQuantity(index),
                ),
                SizedBox(height: 8),
                _buildRemoveButton(index),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.MainColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.MainColor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildRemoveButton(int index) {
    return GestureDetector(
      onTap: () => _removeRack(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.red.shade200.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Icons.delete, color: Colors.white, size: 18),
      ),
    );
  }
}
