import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:merchandiser_app/contant/colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>?> _userDataFuture;
  String? _profileImageUrl;
  File? _selectedImage;
  bool _isUploading = false;
  bool _isLoggingOut = false; // Added for logout loading state
  Uint8List? _selectedImageBytes;
  @override
  void initState() {
    super.initState();
    _userDataFuture = _fetchUserData();
  }

  Future<Map<String, dynamic>?> _fetchUserData() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('Merchandiser')
          .where('authId', isEqualTo: uid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data();
        _profileImageUrl = data['profileImage'] as String?;
        return data;
      }
      return null;
    } catch (e) {
      print("Error fetching user data: $e");
      return null;
    }
  }

  // Function to pick and preview image
  Future<bool> _requestGalleryPermission() async {
    if (kIsWeb) {
      return true; // Web doesn't require gallery permissions
    }

    var status = await Permission.photos.status;
    if (!status.isGranted) {
      status = await Permission.photos.request();
    }
    return status.isGranted;
  }

  Future<void> _pickProfileImage() async {
    try {
      // Request permissions for Android/iOS
      if (!kIsWeb) {
        bool permissionGranted = await _requestGalleryPermission();
        if (!permissionGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gallery access denied. Please grant permission.',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }

      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        if (kIsWeb) {
          // On web, get the image as bytes
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImage = null;
          });
        } else {
          // On Android/iOS, get the image as a File
          setState(() {
            _selectedImage = File(image.path);
            _selectedImageBytes = null;
          });
        }

        // Show confirmation dialog
        bool? confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Upload Image',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.MainColor,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kIsWeb)
                  Image.memory(
                    _selectedImageBytes!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  )
                else
                  Image.file(
                    _selectedImage!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                const SizedBox(height: 10),
                Text(
                  'Do you want to upload this image as your profile picture?',
                  style: GoogleFonts.poppins(
                    color: AppColors.MainColor,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: AppColors.MainColor),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Upload',
                  style: GoogleFonts.poppins(color: AppColors.MainColor),
                ),
              ),
            ],
          ),
        );

        if (confirm == true) {
          setState(() {
            _isUploading = true;
          });
          await _uploadProfileImage();
        } else {
          setState(() {
            _selectedImage = null;
            _selectedImageBytes = null;
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error picking image: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppColors.MainColor,
        ),
      );
    }
  }

  Future<void> _uploadProfileImage() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User not logged in!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() {
        _isUploading = false;
      });
      return;
    }

    if (_selectedImage == null && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No image selected!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() {
        _isUploading = false;
      });
      return;
    }

    try {
      final storageRef =
          FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');
      print('Uploading image to: ${storageRef.fullPath}');

      if (kIsWeb) {
        await storageRef.putData(_selectedImageBytes!);
      } else {
        await storageRef.putFile(_selectedImage!);
      }
      print('Image uploaded successfully');

      String downloadUrl = await storageRef.getDownloadURL();
      print('Download URL: $downloadUrl');

      // Find the document with the matching authId
      var snapshot = await FirebaseFirestore.instance
          .collection('Merchandiser')
          .where('authId', isEqualTo: uid)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception(
            'No matching Merchandiser document found for UID: $uid');
      }

      String docId = snapshot.docs.first.id;

      await FirebaseFirestore.instance
          .collection('Merchandiser')
          .doc(docId)
          .update({'profileImage': downloadUrl});
      print('Firestore updated with profile image URL');

      setState(() {
        _profileImageUrl = downloadUrl;
        _selectedImage = null;
        _selectedImageBytes = null;
        _isUploading = false;
        _userDataFuture = _fetchUserData();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile image uploaded successfully!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      print('Error uploading image: $e');
      setState(() {
        _selectedImage = null;
        _selectedImageBytes = null;
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error uploading image: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Logout function
  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await FirebaseAuth.instance.signOut();
      Get.offAllNamed('/login'); // Use named route for better navigation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged out successfully!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppColors.MainColor,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoggingOut = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error logging out: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.MainColor,
                  AppColors.MainColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Text(
            'Profile',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontSize: screenWidth * 0.04,
            ),
          ),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            'User not logged in',
            style: GoogleFonts.poppins(
              fontSize: screenWidth * 0.03,
              color: AppColors.MainColor,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.MainColor,
                AppColors.MainColor.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: screenWidth * 0.04,
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _userDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.MainColor),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: GoogleFonts.poppins(
                  fontSize: screenWidth * 0.03,
                  color: AppColors.MainColor,
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Text(
                'No profile data found',
                style: GoogleFonts.poppins(
                  fontSize: screenWidth * 0.03,
                  color: AppColors.MainColor,
                ),
              ),
            );
          }

          var userData = snapshot.data!;

          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(screenWidth * 0.03),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // Profile Header with Image
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.MainColor.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: screenWidth * 0.14,
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!)
                                : _profileImageUrl != null
                                    ? NetworkImage(_profileImageUrl!)
                                    : const AssetImage(
                                            'assets/default_avatar.png')
                                        as ImageProvider,
                            backgroundColor: Colors.grey[200],
                            child: _selectedImage == null &&
                                    _profileImageUrl == null
                                ? const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: AppColors.MainColor,
                                  )
                                : null,
                          ),
                        ),
                        if (_isUploading)
                          CircularProgressIndicator(
                            color: AppColors.MainColor,
                            strokeWidth: 3,
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: screenWidth * 0.035,
                            backgroundColor: AppColors.MainColor,
                            child: IconButton(
                              icon: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 16,
                              ),
                              onPressed:
                                  _isUploading ? null : _pickProfileImage,
                              tooltip: 'Upload Profile Picture',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Profile Name
                  Center(
                    child: Text(
                      userData['Name'] ?? 'Unnamed User',
                      style: GoogleFonts.poppins(
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.w600,
                        color: AppColors.MainColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Details Card
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(
                        color: AppColors.MainColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(screenWidth * 0.03),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Distributor Name',
                              userData['distributorName'] ?? 'N/A'),
                          const Divider(height: 15, color: Colors.grey),
                          _buildDetailRow('Email', userData['Email'] ?? 'N/A'),
                          const Divider(height: 15, color: Colors.grey),
                          _buildDetailRow(
                              'Contact', userData['ContactNo'] ?? 'N/A'),
                          const Divider(height: 15, color: Colors.grey),
                          _buildDetailRow('Merchandiser ID',
                              userData['merchandiserId'] ?? 'N/A'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  // Logout Button with Loading State
                  Center(
                    child: SizedBox(
                      width: screenWidth * 0.7,
                      child: ElevatedButton(
                        onPressed: _isLoggingOut
                            ? null
                            : () async {
                                bool? confirm = await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(
                                      'Logout',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        fontSize: screenWidth * 0.035,
                                      ),
                                    ),
                                    backgroundColor: AppColors.MainColor,
                                    content: Text(
                                      'Are you sure you want to logout?',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: screenWidth * 0.03,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(
                                          'Cancel',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: screenWidth * 0.03,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(
                                          'Yes',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: screenWidth * 0.03,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await _logout();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(
                              vertical: screenHeight * 0.012),
                          elevation: 3,
                        ),
                        child: _isLoggingOut
                            ? SizedBox(
                                height: screenWidth * 0.04,
                                width: screenWidth * 0.04,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Logout',
                                style: GoogleFonts.poppins(
                                  fontSize: screenWidth * 0.03,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: screenWidth * 0.03,
              color: AppColors.MainColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: screenWidth * 0.035,
              color: AppColors.MainColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
