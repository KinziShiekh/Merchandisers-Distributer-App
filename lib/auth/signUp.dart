import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:merchandiser_app/Widgets/customfield.dart';
import 'package:merchandiser_app/contant/colors.dart';
import 'package:merchandiser_app/contant/images.dart';
import 'package:merchandiser_app/provider/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  String? selectedDistributorId;
  String? selectedDistributorName;
  List<Map<String, String>> distributorList = [];
  bool _isLoadingDistributors = false;
  String? _distributorError;

  @override
  void initState() {
    super.initState();
    _fetchDistributors();
  }

  Future<void> _fetchDistributors() async {
    setState(() {
      _isLoadingDistributors = true;
      _distributorError = null;
    });
    try {
      final distributorDocs =
          await FirebaseFirestore.instance.collection('distributors').get();

      setState(() {
        distributorList = distributorDocs.docs
            .map((doc) => {
                  'distributorId': doc.id,
                  'distributorName': doc['distributorName']?.toString() ?? '',
                })
            .toList();
        _isLoadingDistributors = false;
      });
    } catch (e) {
      setState(() {
        _distributorError = 'Failed to load distributors. Please try again.';
        _isLoadingDistributors = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(AppImages.loginposter),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black,
              BlendMode.dstATop,
            ),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          Row(
                            children: [
                              Image.asset(
                                AppImages.laysLogo,
                                height: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Create Your Account",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.MainColor,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "Join us as a Merchandiser!",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: AppColors.MainColor,
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Email Field
                          CustomTextField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            showClearButton: true,
                            borderColor: AppColors.MainColor,
                            errorBorderColor: Colors.red,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Please enter your email";
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return "Please enter a valid email";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Password Field
                          CustomTextField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            isPassword: true,
                            showClearButton: true,
                            borderColor: AppColors.MainColor,
                            errorBorderColor: Colors.red,
                            isPasswordVisible: _isPasswordVisible,
                            onVisibilityToggle: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Please enter your password";
                              }
                              if (value.length < 6) {
                                return "Password must be at least 6 characters";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Distributor Dropdown
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.MainColor),
                            ),
                            child: _isLoadingDistributors
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.MainColor,
                                      ),
                                    ),
                                  )
                                : DropdownButtonFormField<String>(
                                    value: selectedDistributorId,
                                    hint: Text(
                                      'Select Distributor',
                                      style: GoogleFonts.poppins(
                                          color: Colors.grey[600]),
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.store_outlined,
                                        color: AppColors.MainColor,
                                        size: 24,
                                      ),
                                      errorText: _distributorError,
                                    ),
                                    isExpanded: true,
                                    dropdownColor: Colors.white,
                                    style: GoogleFonts.poppins(
                                        color: AppColors.MainColor),
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                      color: AppColors.MainColor,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedDistributorId = value;
                                        selectedDistributorName =
                                            distributorList.firstWhere(
                                          (dist) =>
                                              dist['distributorId'] == value,
                                          orElse: () =>
                                              {'distributorName': 'Unknown'},
                                        )['distributorName'];
                                      });
                                    },
                                    items: distributorList.map((distributor) {
                                      final isSelected =
                                          selectedDistributorId ==
                                              distributor['distributorId'];
                                      return DropdownMenuItem<String>(
                                        value: distributor['distributorId'],
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 24,
                                              child: isSelected
                                                  ? Icon(
                                                      Icons.check_circle,
                                                      size: 18,
                                                      color: Color(0xFFFF6600),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                distributor[
                                                        'distributorName'] ??
                                                    'Unknown',
                                                style: GoogleFonts.poppins(
                                                  color: AppColors.MainColor,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Please select a distributor';
                                      }
                                      return null;
                                    },
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    menuMaxHeight: 300,
                                  ),
                          ),

                          // Error Message
                          if (authProvider.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(
                                authProvider.errorMessage!,
                                style: GoogleFonts.poppins(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Sign Up Button
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6600),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 5,
                              ),
                              onPressed: authProvider.isLoading ||
                                      _isLoadingDistributors
                                  ? null
                                  : () async {
                                      if (_formKey.currentState!.validate()) {
                                        bool success = await authProvider
                                            .createUserWithEmailPasswordAndDistributor(
                                          _emailController.text.trim(),
                                          _passwordController.text,
                                          selectedDistributorId,
                                          context,
                                        );
                                        if (success && mounted) {
                                          Navigator.pushReplacementNamed(
                                              context, '/home');
                                        }
                                      }
                                    },
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      height: 25,
                                      width: 25,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : Text(
                                      "Sign Up",
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Sign In Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account? ",
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    Navigator.pushNamed(context, '/signin'),
                                child: Text(
                                  "Sign In",
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFFF6600),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
