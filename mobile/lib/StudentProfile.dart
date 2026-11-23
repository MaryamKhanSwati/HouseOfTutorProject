import 'package:flutter/material.dart';
import 'package:house_of_tutor/services/api_client.dart';

class StudentProfile extends StatefulWidget {
  const StudentProfile({super.key});

  @override
  State<StudentProfile> createState() => _StudentProfileState();
}

class _StudentProfileState extends State<StudentProfile> {
  // =========================================================
  // THEME
  // =========================================================

  final Color mainColor = const Color(0xff1E8E7E);
  final Color backgroundColor = const Color(0xffF4F6F8);

  bool isLoading = true;
  bool isSaving = false;

  Map<String, dynamic> profileData = {};

  String errorMessage = '';

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();
    fetchStudentProfile();
  }

  // =========================================================
  // GET STUDENT PROFILE API
  // GET /api/Student/my-profile
  // =========================================================

  Future<void> fetchStudentProfile({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      final response = await ApiClient.get(
        '/api/Student/my-profile',
      );

      final data = await ApiClient.decodeJson(response);

      if (!mounted) return;

      if (response.statusCode == 200) {
        if (data is Map) {
          final dynamic responseData =
              data['data'] is Map ? data['data'] : data;

          if (responseData is Map) {
            setState(() {
              profileData = Map<String, dynamic>.from(responseData);
              isLoading = false;
              errorMessage = '';
            });
          } else {
            setState(() {
              isLoading = false;
              errorMessage = 'Invalid profile response from server.';
            });
          }
        } else {
          setState(() {
            isLoading = false;
            errorMessage = 'Invalid profile response from server.';
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = data is Map
              ? (data['message'] ?? 'Failed to load profile').toString()
              : 'Failed to load profile';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to connect to server. Please try again.';
      });
    }
  }

  // =========================================================
  // PUT EDIT PROFILE API
  // PUT /api/Student/edit-profile
  // =========================================================

  Future<bool> updateStudentProfile({
    required String fullName,
    required String phone,
    required String cnic,
    required String location,
    required String latitude,
    required String longitude,
  }) async {
    if (!mounted || isSaving) return false;

    setState(() {
      isSaving = true;
    });

    try {
      final String latText = latitude.trim();
      final String lngText = longitude.trim();

      final double? lat = latText.isEmpty ? null : double.tryParse(latText);
      final double? lng = lngText.isEmpty ? null : double.tryParse(lngText);

      if (latText.isNotEmpty && lat == null) {
        showMessage('Please enter a valid latitude.', isError: true);
        return false;
      }

      if (lngText.isNotEmpty && lng == null) {
        showMessage('Please enter a valid longitude.', isError: true);
        return false;
      }

      final Map<String, dynamic> requestBody = {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'cnic': cnic.trim().isEmpty ? null : cnic.trim(),
        'location': location.trim().isEmpty ? null : location.trim(),
        'latitude': lat,
        'longitude': lng,
      };

      debugPrint('Updating student profile...');
      final response = await ApiClient.put(
        '/api/Student/edit-profile',
        requestBody,
      );

      debugPrint('STUDENT PROFILE UPDATE STATUS: ${response.statusCode}');
      debugPrint('STUDENT PROFILE UPDATE BODY: ${response.body}');

      final decoded = await ApiClient.decodeJson(response);

      if (!mounted) return false;

      if (response.statusCode == 200) {
        final Map<String, dynamic> submittedValues = {
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'cnic': cnic.trim(),
          'location': location.trim(),
          'latitude': lat,
          'longitude': lng,
        };

        Map<String, dynamic> serverValues = {};
        if (decoded is Map) {
          final dynamic responseData =
              decoded['data'] is Map ? decoded['data'] : decoded;
          if (responseData is Map) {
            serverValues = Map<String, dynamic>.from(responseData);
            serverValues.remove('message');
          }
        }

        setState(() {
          // Merge instead of replacing the complete profile.
          profileData = {
            ...profileData,
            ...submittedValues,
            ...serverValues,
          };
        });

        return true;
      }

      final String message = decoded is Map
          ? (decoded['message'] ??
                  decoded['title'] ??
                  'Failed to update profile')
              .toString()
          : 'Failed to update profile (HTTP ${response.statusCode}).';

      showMessage(message, isError: true);
      return false;
    } catch (e, stackTrace) {
      debugPrint('STUDENT PROFILE UPDATE ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      showMessage(
        'Unable to update profile. Please try again.',
        isError: true,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // =========================================================
  // SNACKBAR
  // =========================================================

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : mainColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // =========================================================
  // INITIALS
  // =========================================================

  String get initials {
    final name = (profileData['full_name'] ?? '').toString().trim();

    if (name.isEmpty) return 'S';

    final parts = name.split(' ').where((e) => e.isNotEmpty).toList();

    return parts.take(2).map((e) => e[0]).join().toUpperCase();
  }

  // =========================================================
  // SAFE VALUE
  // =========================================================

  String getValue(String key) {
    final value = profileData[key];

    if (value == null || value.toString().trim().isEmpty) {
      return 'Not provided';
    }

    return value.toString();
  }

  // =========================================================
  // OPEN EDIT PROFILE DIALOG
  // Controllers ab dialog widget ke andar hain (safe dispose)
  // =========================================================

  Future<void> openEditProfile() async {
    final bool? updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _EditStudentProfileDialog(
          profileData: profileData,
          mainColor: mainColor,
          onSave: updateStudentProfile,
          onError: (message) => showMessage(message, isError: true),
        );
      },
    );

    if (updated == true && mounted) {
      showMessage('Profile updated successfully!');
    }
  }

  // =========================================================
  // PROFILE CARD
  // =========================================================

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(left: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Color(0xff333333),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // INFO ROW
  // =========================================================

  Widget _infoRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          height: 43,
          width: 43,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 21,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff333333),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // COORDINATE BOX
  // =========================================================

  Widget _coordinateBox({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: mainColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xff333333),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ERROR SCREEN
  // =========================================================

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Colors.red,
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Unable to Load Profile',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () => fetchStudentProfile(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // MAIN UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      // APP BAR

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: mainColor,
            size: 20,
          ),
        ),
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Color(0xff222222),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Profile',
            onPressed: isLoading ? null : () => fetchStudentProfile(),
            icon: Icon(
              Icons.refresh,
              color: mainColor,
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),

      // BODY

      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: mainColor,
              ),
            )
          : errorMessage.isNotEmpty && profileData.isEmpty
              ? _errorView()
              : RefreshIndicator(
                  color: mainColor,
                  onRefresh: () => fetchStudentProfile(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(17, 20, 17, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PROFILE HEADER CARD

                        _card(
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: mainColor.withOpacity(.35),
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 43,
                                      backgroundColor:
                                          mainColor.withOpacity(.12),
                                      child: Text(
                                        initials,
                                        style: TextStyle(
                                          color: mainColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 30,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.verified,
                                      color: mainColor,
                                      size: 21,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              Text(
                                getValue('full_name'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff222222),
                                ),
                              ),
                              const SizedBox(height: 9),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: mainColor.withOpacity(.10),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  'STUDENT',
                                  style: TextStyle(
                                    color: mainColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: openEditProfile,
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Edit Profile',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: mainColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 26),

                        // PERSONAL INFORMATION

                        _sectionTitle(
                          'PERSONAL INFORMATION',
                          'Your registered account information',
                        ),

                        const SizedBox(height: 13),

                        _card(
                          child: Column(
                            children: [
                              _infoRow(
                                icon: Icons.email_outlined,
                                iconColor: const Color(0xff238A65),
                                iconBg: const Color(0xffE6F5EE),
                                title: 'Email Address',
                                value: getValue('email'),
                              ),
                              Divider(
                                height: 28,
                                color: Colors.grey.shade200,
                              ),
                              _infoRow(
                                icon: Icons.phone_outlined,
                                iconColor: const Color(0xff2385B4),
                                iconBg: const Color(0xffE6F2F8),
                                title: 'Phone Number',
                                value: getValue('phone'),
                              ),
                              Divider(
                                height: 28,
                                color: Colors.grey.shade200,
                              ),
                              _infoRow(
                                icon: Icons.badge_outlined,
                                iconColor: const Color(0xffB8752D),
                                iconBg: const Color(0xffFFF1E2),
                                title: 'CNIC / National ID',
                                value: getValue('cnic'),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 26),

                        // LOCATION INFORMATION

                        _sectionTitle(
                          'LOCATION INFORMATION',
                          'Your registered residential location',
                        ),

                        const SizedBox(height: 13),

                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _infoRow(
                                icon: Icons.location_on_outlined,
                                iconColor: const Color(0xff6855CC),
                                iconBg: const Color(0xffEFEDFC),
                                title: 'City / Location',
                                value: getValue('location'),
                              ),
                              Divider(
                                height: 30,
                                color: Colors.grey.shade200,
                              ),
                              const Text(
                                'LOCATION COORDINATES',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: .8,
                                ),
                              ),
                              const SizedBox(height: 13),
                              Row(
                                children: [
                                  Expanded(
                                    child: _coordinateBox(
                                      title: 'Latitude',
                                      value: getValue('latitude'),
                                      icon: Icons.explore_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _coordinateBox(
                                      title: 'Longitude',
                                      value: getValue('longitude'),
                                      icon: Icons.explore_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // FOOTER

                        Center(
                          child: Text(
                            'House of Tutor • Student Account',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

// =============================================================
// EDIT PROFILE DIALOG (SEPARATE WIDGET)
// Controllers yahan create hote hain aur yahin dispose hote hain.
// Is wajah se "controller used after being disposed" error nahi aata.
// =============================================================

typedef _StudentSaveCallback = Future<bool> Function({
  required String fullName,
  required String phone,
  required String cnic,
  required String location,
  required String latitude,
  required String longitude,
});

class _EditStudentProfileDialog extends StatefulWidget {
  final Map<String, dynamic> profileData;
  final Color mainColor;
  final _StudentSaveCallback onSave;
  final void Function(String message) onError;

  const _EditStudentProfileDialog({
    required this.profileData,
    required this.mainColor,
    required this.onSave,
    required this.onError,
  });

  @override
  State<_EditStudentProfileDialog> createState() =>
      _EditStudentProfileDialogState();
}

class _EditStudentProfileDialogState extends State<_EditStudentProfileDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cnicController;
  late final TextEditingController _locationController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;

  bool _saving = false;

  Color get _mainColor => widget.mainColor;

  @override
  void initState() {
    super.initState();

    final data = widget.profileData;

    _nameController =
        TextEditingController(text: data['full_name']?.toString() ?? '');
    _phoneController =
        TextEditingController(text: data['phone']?.toString() ?? '');
    _cnicController =
        TextEditingController(text: data['cnic']?.toString() ?? '');
    _locationController =
        TextEditingController(text: data['location']?.toString() ?? '');
    _latitudeController =
        TextEditingController(text: data['latitude']?.toString() ?? '');
    _longitudeController =
        TextEditingController(text: data['longitude']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cnicController.dispose();
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final lat = _latitudeController.text.trim();
    final lng = _longitudeController.text.trim();

    // Latitude and longitude must be entered together, or both left empty.
    if (lat.isEmpty != lng.isEmpty) {
      widget.onError(
        'Enter both latitude and longitude, or leave both empty.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _saving = true);

    final success = await widget.onSave(
      fullName: _nameController.text,
      phone: _phoneController.text,
      cnic: _cnicController.text,
      location: _locationController.text,
      latitude: lat,
      longitude: lng,
    );

    if (!mounted) return;

    setState(() => _saving = false);

    if (success) {
      Navigator.of(context).pop(true);
    }
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: _mainColor,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool requiredField = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: _mainColor,
          size: 21,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _mainColor,
            width: 1.5,
          ),
        ),
      ),
      validator: validator ??
          (value) {
            if (requiredField && (value == null || value.trim().isEmpty)) {
              return '$label is required';
            }
            return null;
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _mainColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          color: _mainColor,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Update your personal information',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // PERSONAL INFORMATION

                  _sectionTitle('PERSONAL INFORMATION'),
                  const SizedBox(height: 12),

                  _field(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    requiredField: true,
                  ),
                  const SizedBox(height: 14),

                  _field(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    requiredField: true,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),

                  _field(
                    controller: _cnicController,
                    label: 'CNIC / National ID',
                    icon: Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 22),

                  // LOCATION INFORMATION

                  _sectionTitle('LOCATION INFORMATION'),
                  const SizedBox(height: 12),

                  _field(
                    controller: _locationController,
                    label: 'City / Location',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 14),

                  _field(
                    controller: _latitudeController,
                    label: 'Latitude',
                    icon: Icons.explore_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }

                      final number = double.tryParse(value.trim());

                      if (number == null || number < -90 || number > 90) {
                        return 'Enter valid latitude (-90 to 90)';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  _field(
                    controller: _longitudeController,
                    label: 'Longitude',
                    icon: Icons.explore_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }

                      final number = double.tryParse(value.trim());

                      if (number == null || number < -180 || number > 180) {
                        return 'Enter valid longitude (-180 to 180)';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 22),

                  // BUTTONS

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _saving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _mainColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
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
      ),
    );
  }
}




















// import 'package:flutter/material.dart';
// import 'package:house_of_tutor/services/api_client.dart';

// class StudentProfile extends StatefulWidget {
//   const StudentProfile({super.key});

//   @override
//   State<StudentProfile> createState() => _StudentProfileState();
// }

// class _StudentProfileState extends State<StudentProfile> {
//   // =========================================================
//   // THEME
//   // =========================================================

//   final Color mainColor = const Color(0xff1E8E7E);
//   final Color backgroundColor = const Color(0xffF4F6F8);

//   bool isLoading = true;
//   bool isSaving = false;

//   Map<String, dynamic> profileData = {};

//   String errorMessage = '';

//   // =========================================================
//   // INIT
//   // =========================================================

//   @override
//   void initState() {
//     super.initState();
//     fetchStudentProfile();
//   }

//   // =========================================================
//   // GET STUDENT PROFILE API
//   // GET /api/Student/my-profile
//   // =========================================================

//   Future<void> fetchStudentProfile({bool showLoader = true}) async {
//     if (showLoader && mounted) {
//       setState(() {
//         isLoading = true;
//         errorMessage = '';
//       });
//     }

//     try {
//       final response = await ApiClient.get(
//         '/api/Student/my-profile',
//       );

//       final data = await ApiClient.decodeJson(response);

//       if (!mounted) return;

//       if (response.statusCode == 200) {
//         if (data is Map) {
//           final dynamic responseData =
//               data['data'] is Map ? data['data'] : data;

//           if (responseData is Map) {
//             setState(() {
//               profileData = Map<String, dynamic>.from(responseData);
//               isLoading = false;
//               errorMessage = '';
//             });
//           } else {
//             setState(() {
//               isLoading = false;
//               errorMessage = 'Invalid profile response from server.';
//             });
//           }
//         } else {
//           setState(() {
//             isLoading = false;
//             errorMessage = 'Invalid profile response from server.';
//           });
//         }
//       } else {
//         setState(() {
//           isLoading = false;
//           errorMessage = data is Map
//               ? (data['message'] ?? 'Failed to load profile').toString()
//               : 'Failed to load profile';
//         });
//       }
//     } catch (e) {
//       if (!mounted) return;

//       setState(() {
//         isLoading = false;
//         errorMessage = 'Unable to connect to server. Please try again.';
//       });
//     }
//   }

//   // =========================================================
//   // PUT EDIT PROFILE API
//   // PUT /api/Student/edit-profile
//   // =========================================================

//   Future<bool> updateStudentProfile({
//     required String fullName,
//     required String phone,
//     required String cnic,
//     required String location,
//     required String latitude,
//     required String longitude,
//   }) async {
//     if (!mounted || isSaving) return false;

//     setState(() {
//       isSaving = true;
//     });

//     try {
//       final String latText = latitude.trim();
//       final String lngText = longitude.trim();

//       final double? lat =
//           latText.isEmpty ? null : double.tryParse(latText);
//       final double? lng =
//           lngText.isEmpty ? null : double.tryParse(lngText);

//       if (latText.isNotEmpty && lat == null) {
//         showMessage('Please enter a valid latitude.', isError: true);
//         return false;
//       }

//       if (lngText.isNotEmpty && lng == null) {
//         showMessage('Please enter a valid longitude.', isError: true);
//         return false;
//       }

//       final Map<String, dynamic> requestBody = {
//         'fullName': fullName.trim(),
//         'phone': phone.trim(),
//         'cnic': cnic.trim().isEmpty ? null : cnic.trim(),
//         'location': location.trim().isEmpty ? null : location.trim(),
//         'latitude': lat,
//         'longitude': lng,
//       };

//       debugPrint('Updating student profile...');
//       final response = await ApiClient.put(
//         '/api/Student/edit-profile',
//         requestBody,
//       );

//       debugPrint('STUDENT PROFILE UPDATE STATUS: ${response.statusCode}');
//       debugPrint('STUDENT PROFILE UPDATE BODY: ${response.body}');

//       final decoded = await ApiClient.decodeJson(response);

//       if (!mounted) return false;

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> submittedValues = {
//           'full_name': fullName.trim(),
//           'phone': phone.trim(),
//           'cnic': cnic.trim(),
//           'location': location.trim(),
//           'latitude': lat,
//           'longitude': lng,
//         };

//         Map<String, dynamic> serverValues = {};
//         if (decoded is Map) {
//           final dynamic responseData =
//               decoded['data'] is Map ? decoded['data'] : decoded;
//           if (responseData is Map) {
//             serverValues = Map<String, dynamic>.from(responseData);
//           }
//         }

//         if (!mounted) return false;

//         setState(() {
//           // Merge instead of replacing the complete profile.
//           // This keeps email and any other fields returned by GET profile.
//           profileData = {
//             ...profileData,
//             ...submittedValues,
//             ...serverValues,
//           };
//         });

//         return true;
//       }

//       final String message = decoded is Map
//           ? (decoded['message'] ??
//                   decoded['title'] ??
//                   'Failed to update profile')
//               .toString()
//           : 'Failed to update profile (HTTP ${response.statusCode}).';

//       if (mounted) {
//         showMessage(message, isError: true);
//       }
//       return false;
//     } catch (e, stackTrace) {
//       debugPrint('STUDENT PROFILE UPDATE ERROR: $e');
//       debugPrintStack(stackTrace: stackTrace);

//       if (mounted) {
//         showMessage(
//           'Unable to update profile. Please try again.',
//           isError: true,
//         );
//       }
//       return false;
//     } finally {
//       if (mounted) {
//         setState(() {
//           isSaving = false;
//         });
//       }
//     }
//   }

//   // =========================================================
//   // SNACKBAR
//   // =========================================================

//   void showMessage(String message, {bool isError = false}) {
//     if (!mounted) return;

//     ScaffoldMessenger.of(context).hideCurrentSnackBar();

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: isError
//             ? Colors.red.shade700
//             : mainColor,
//         behavior: SnackBarBehavior.floating,
//         margin: const EdgeInsets.all(16),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//       ),
//     );
//   }

//   // =========================================================
//   // INITIALS
//   // =========================================================

//   String get initials {
//     final name = (profileData['full_name'] ?? '').toString().trim();

//     if (name.isEmpty) return 'S';

//     final parts = name.split(' ').where((e) => e.isNotEmpty).toList();

//     return parts.take(2).map((e) => e[0]).join().toUpperCase();
//   }

//   // =========================================================
//   // SAFE VALUE
//   // =========================================================

//   String getValue(String key) {
//     final value = profileData[key];

//     if (value == null || value.toString().trim().isEmpty) {
//       return 'Not provided';
//     }

//     return value.toString();
//   }

//   // =========================================================
//   // EDIT PROFILE DIALOG
//   // =========================================================

//   void openEditProfile() {
//     final nameController = TextEditingController(
//       text: profileData['full_name']?.toString() ?? '',
//     );

//     final phoneController = TextEditingController(
//       text: profileData['phone']?.toString() ?? '',
//     );

//     final cnicController = TextEditingController(
//       text: profileData['cnic']?.toString() ?? '',
//     );

//     final locationController = TextEditingController(
//       text: profileData['location']?.toString() ?? '',
//     );

//     final latitudeController = TextEditingController(
//       text: profileData['latitude']?.toString() ?? '',
//     );

//     final longitudeController = TextEditingController(
//       text: profileData['longitude']?.toString() ?? '',
//     );

//     final formKey = GlobalKey<FormState>();
//     bool dialogSaving = false;

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (dialogContext) {
//         return StatefulBuilder(
//           builder: (context, setDialogState) {
//             return Dialog(
//               insetPadding: const EdgeInsets.symmetric(
//                 horizontal: 16,
//                 vertical: 24,
//               ),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(22),
//               ),
//               child: ConstrainedBox(
//                 constraints: const BoxConstraints(maxWidth: 500),
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.all(22),
//                   child: Form(
//                     key: formKey,
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [

//                         // HEADER

//                         Row(
//                           children: [
//                             Container(
//                               padding: const EdgeInsets.all(12),
//                               decoration: BoxDecoration(
//                                 color: mainColor.withOpacity(0.10),
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                               child: Icon(
//                                 Icons.edit_outlined,
//                                 color: mainColor,
//                                 size: 25,
//                               ),
//                             ),

//                             const SizedBox(width: 12),

//                             const Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     'Edit Profile',
//                                     style: TextStyle(
//                                       fontSize: 20,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   SizedBox(height: 4),
//                                   Text(
//                                     'Update your personal information',
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.grey,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),

//                             IconButton(
//                               onPressed: (isSaving || dialogSaving)
//                                   ? null
//                                   : () => Navigator.pop(dialogContext),
//                               icon: const Icon(Icons.close),
//                             ),
//                           ],
//                         ),

//                         const SizedBox(height: 24),

//                         // PERSONAL INFORMATION

//                         _editSectionTitle('PERSONAL INFORMATION'),

//                         const SizedBox(height: 12),

//                         _editField(
//                           controller: nameController,
//                           label: 'Full Name',
//                           icon: Icons.person_outline,
//                           requiredField: true,
//                         ),

//                         const SizedBox(height: 14),

//                         _editField(
//                           controller: phoneController,
//                           label: 'Phone Number',
//                           icon: Icons.phone_outlined,
//                           requiredField: true,
//                           keyboardType: TextInputType.phone,
//                         ),

//                         const SizedBox(height: 14),

//                         _editField(
//                           controller: cnicController,
//                           label: 'CNIC / National ID',
//                           icon: Icons.badge_outlined,
//                           keyboardType: TextInputType.number,
//                         ),

//                         const SizedBox(height: 22),

//                         // LOCATION INFORMATION

//                         _editSectionTitle('LOCATION INFORMATION'),

//                         const SizedBox(height: 12),

//                         _editField(
//                           controller: locationController,
//                           label: 'City / Location',
//                           icon: Icons.location_on_outlined,
//                         ),

//                         const SizedBox(height: 14),

//                         _editField(
//                           controller: latitudeController,
//                           label: 'Latitude',
//                           icon: Icons.explore_outlined,
//                           keyboardType: const TextInputType.numberWithOptions(
//                             decimal: true,
//                             signed: true,
//                           ),
//                           validator: (value) {
//                             if (value == null || value.trim().isEmpty) {
//                               return null;
//                             }

//                             final number = double.tryParse(value.trim());

//                             if (number == null ||
//                                 number < -90 ||
//                                 number > 90) {
//                               return 'Enter valid latitude (-90 to 90)';
//                             }

//                             return null;
//                           },
//                         ),

//                         const SizedBox(height: 14),

//                         _editField(
//                           controller: longitudeController,
//                           label: 'Longitude',
//                           icon: Icons.explore_outlined,
//                           keyboardType: const TextInputType.numberWithOptions(
//                             decimal: true,
//                             signed: true,
//                           ),
//                           validator: (value) {
//                             if (value == null || value.trim().isEmpty) {
//                               return null;
//                             }

//                             final number = double.tryParse(value.trim());

//                             if (number == null ||
//                                 number < -180 ||
//                                 number > 180) {
//                               return 'Enter valid longitude (-180 to 180)';
//                             }

//                             return null;
//                           },
//                         ),

//                         const SizedBox(height: 22),

//                         // BUTTONS

//                         Row(
//                           children: [
//                             Expanded(
//                               child: OutlinedButton(
//                                 onPressed: (isSaving || dialogSaving)
//                                     ? null
//                                     : () => Navigator.pop(dialogContext),
//                                 style: OutlinedButton.styleFrom(
//                                   padding: const EdgeInsets.symmetric(
//                                     vertical: 15,
//                                   ),
//                                   side: BorderSide(
//                                     color: Colors.grey.shade300,
//                                   ),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                 ),
//                                 child: const Text(
//                                   'Cancel',
//                                   style: TextStyle(
//                                     color: Colors.black87,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               ),
//                             ),

//                             const SizedBox(width: 12),

//                             Expanded(
//                               child: ElevatedButton(
//                                 onPressed: (isSaving || dialogSaving)
//                                     ? null
//                                     : () async {
//                                         if (!formKey.currentState!.validate()) {
//                                           return;
//                                         }

//                                         // Latitude and longitude must be
//                                         // entered together, or both left empty.
//                                         final lat =
//                                             latitudeController.text.trim();
//                                         final lng =
//                                             longitudeController.text.trim();

//                                         if (lat.isEmpty != lng.isEmpty) {
//                                           showMessage(
//                                             'Enter both latitude and longitude, or leave both empty.',
//                                             isError: true,
//                                           );
//                                           return;
//                                         }

//                                         FocusScope.of(dialogContext).unfocus();

//                                         setDialogState(() {
//                                           dialogSaving = true;
//                                         });

//                                         final success =
//                                             await updateStudentProfile(
//                                           fullName: nameController.text,
//                                           phone: phoneController.text,
//                                           cnic: cnicController.text,
//                                           location: locationController.text,
//                                           latitude: lat,
//                                           longitude: lng,
//                                         );

//                                         if (!mounted ||
//                                             !dialogContext.mounted) {
//                                           return;
//                                         }

//                                         setDialogState(() {
//                                           dialogSaving = false;
//                                         });

//                                         if (success) {
//                                           Navigator.of(dialogContext).pop();

//                                           WidgetsBinding.instance
//                                               .addPostFrameCallback((_) {
//                                             if (mounted) {
//                                               showMessage(
//                                                 'Profile updated successfully!',
//                                               );
//                                             }
//                                           });
//                                         }
//                                       },
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: mainColor,
//                                   foregroundColor: Colors.white,
//                                   padding: const EdgeInsets.symmetric(
//                                     vertical: 15,
//                                   ),
//                                   elevation: 0,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                 ),
//                                 child: (isSaving || dialogSaving)
//                                     ? const SizedBox(
//                                         height: 20,
//                                         width: 20,
//                                         child: CircularProgressIndicator(
//                                           color: Colors.white,
//                                           strokeWidth: 2,
//                                         ),
//                                       )
//                                     : const Text(
//                                         'Save Changes',
//                                         style: TextStyle(
//                                           fontWeight: FontWeight.bold,
//                                         ),
//                                       ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     ).whenComplete(() {
//       nameController.dispose();
//       phoneController.dispose();
//       cnicController.dispose();
//       locationController.dispose();
//       latitudeController.dispose();
//       longitudeController.dispose();
//     });
//   }

//   // =========================================================
//   // EDIT FIELD
//   // =========================================================

//   Widget _editField({
//     required TextEditingController controller,
//     required String label,
//     required IconData icon,
//     TextInputType keyboardType = TextInputType.text,
//     bool requiredField = false,
//     String? Function(String?)? validator,
//   }) {
//     return TextFormField(
//       controller: controller,
//       keyboardType: keyboardType,
//       textCapitalization: TextCapitalization.words,
//       style: const TextStyle(
//         fontSize: 14,
//         fontWeight: FontWeight.w500,
//       ),
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(
//           icon,
//           color: mainColor,
//           size: 21,
//         ),
//         filled: true,
//         fillColor: Colors.grey.shade50,
//         contentPadding: const EdgeInsets.symmetric(
//           horizontal: 14,
//           vertical: 16,
//         ),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(color: Colors.grey.shade200),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(color: Colors.grey.shade200),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(
//             color: mainColor,
//             width: 1.5,
//           ),
//         ),
//       ),
//       validator: validator ??
//           (value) {
//             if (requiredField && (value == null || value.trim().isEmpty)) {
//               return '$label is required';
//             }

//             return null;
//           },
//     );
//   }

//   // =========================================================
//   // SECTION TITLE IN EDIT DIALOG
//   // =========================================================

//   Widget _editSectionTitle(String title) {
//     return Text(
//       title,
//       style: TextStyle(
//         color: mainColor,
//         fontSize: 11,
//         fontWeight: FontWeight.bold,
//         letterSpacing: 1.2,
//       ),
//     );
//   }

//   // =========================================================
//   // PROFILE CARD
//   // =========================================================

//   Widget _card({required Widget child}) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(19),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(
//           color: Colors.grey.shade100,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.035),
//             blurRadius: 15,
//             offset: const Offset(0, 5),
//           ),
//         ],
//       ),
//       child: child,
//     );
//   }

//   // =========================================================
//   // SECTION TITLE
//   // =========================================================

//   Widget _sectionTitle(String title, String subtitle) {
//     return Padding(
//       padding: const EdgeInsets.only(left: 3),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(
//               fontSize: 13,
//               fontWeight: FontWeight.bold,
//               letterSpacing: 1,
//               color: Color(0xff333333),
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             subtitle,
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.grey.shade500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // =========================================================
//   // INFO ROW
//   // =========================================================

//   Widget _infoRow({
//     required IconData icon,
//     required Color iconColor,
//     required Color iconBg,
//     required String title,
//     required String value,
//   }) {
//     return Row(
//       children: [
//         Container(
//           height: 43,
//           width: 43,
//           decoration: BoxDecoration(
//             color: iconBg,
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Icon(
//             icon,
//             color: iconColor,
//             size: 21,
//           ),
//         ),

//         const SizedBox(width: 13),

//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 style: TextStyle(
//                   fontSize: 11,
//                   color: Colors.grey.shade500,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),

//               const SizedBox(height: 5),

//               Text(
//                 value,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xff333333),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   // =========================================================
//   // COORDINATE BOX
//   // =========================================================

//   Widget _coordinateBox({
//     required String title,
//     required String value,
//     required IconData icon,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(13),
//       decoration: BoxDecoration(
//         color: backgroundColor,
//         borderRadius: BorderRadius.circular(13),
//         border: Border.all(
//           color: Colors.grey.shade200,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(
//                 icon,
//                 color: mainColor,
//                 size: 16,
//               ),
//               const SizedBox(width: 6),
//               Text(
//                 title,
//                 style: TextStyle(
//                   color: Colors.grey.shade600,
//                   fontSize: 11,
//                 ),
//               ),
//             ],
//           ),

//           const SizedBox(height: 8),

//           Text(
//             value,
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: const TextStyle(
//               fontSize: 13,
//               fontWeight: FontWeight.bold,
//               color: Color(0xff333333),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // =========================================================
//   // ERROR SCREEN
//   // =========================================================

//   Widget _errorView() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(28),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(22),
//               decoration: BoxDecoration(
//                 color: Colors.red.withOpacity(.08),
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(
//                 Icons.wifi_off_rounded,
//                 color: Colors.red,
//                 size: 42,
//               ),
//             ),

//             const SizedBox(height: 18),

//             const Text(
//               'Unable to Load Profile',
//               style: TextStyle(
//                 fontSize: 19,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),

//             const SizedBox(height: 8),

//             Text(
//               errorMessage,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 color: Colors.grey.shade600,
//                 fontSize: 13,
//               ),
//             ),

//             const SizedBox(height: 22),

//             ElevatedButton.icon(
//               onPressed: () => fetchStudentProfile(),
//               icon: const Icon(Icons.refresh),
//               label: const Text('Try Again'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: mainColor,
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 24,
//                   vertical: 13,
//                 ),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // =========================================================
//   // MAIN UI
//   // =========================================================

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: backgroundColor,

//       // APP BAR

//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         centerTitle: true,

//         leading: IconButton(
//           onPressed: () => Navigator.pop(context),
//           icon: Icon(
//             Icons.arrow_back_ios_new,
//             color: mainColor,
//             size: 20,
//           ),
//         ),

//         title: const Text(
//           'My Profile',
//           style: TextStyle(
//             color: Color(0xff222222),
//             fontWeight: FontWeight.bold,
//             fontSize: 18,
//           ),
//         ),

//         actions: [
//           IconButton(
//             tooltip: 'Refresh Profile',
//             onPressed: isLoading
//                 ? null
//                 : () => fetchStudentProfile(),
//             icon: Icon(
//               Icons.refresh,
//               color: mainColor,
//             ),
//           ),

//           const SizedBox(width: 5),
//         ],
//       ),

//       // BODY

//       body: isLoading
//           ? Center(
//               child: CircularProgressIndicator(
//                 color: mainColor,
//               ),
//             )
//           : errorMessage.isNotEmpty && profileData.isEmpty
//               ? _errorView()
//               : RefreshIndicator(
//                   color: mainColor,
//                   onRefresh: () => fetchStudentProfile(),
//                   child: SingleChildScrollView(
//                     physics: const AlwaysScrollableScrollPhysics(),
//                     padding: const EdgeInsets.fromLTRB(17, 20, 17, 30),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [

//                         // =====================================
//                         // PROFILE HEADER CARD
//                         // =====================================

//                         _card(
//                           child: Column(
//                             children: [

//                               // AVATAR

//                               Stack(
//                                 alignment: Alignment.bottomRight,
//                                 children: [
//                                   Container(
//                                     padding: const EdgeInsets.all(5),
//                                     decoration: BoxDecoration(
//                                       shape: BoxShape.circle,
//                                       border: Border.all(
//                                         color: mainColor.withOpacity(.35),
//                                         width: 2,
//                                       ),
//                                     ),
//                                     child: CircleAvatar(
//                                       radius: 43,
//                                       backgroundColor: mainColor.withOpacity(.12),
//                                       child: Text(
//                                         initials,
//                                         style: TextStyle(
//                                           color: mainColor,
//                                           fontWeight: FontWeight.bold,
//                                           fontSize: 30,
//                                         ),
//                                       ),
//                                     ),
//                                   ),

//                                   Container(
//                                     padding: const EdgeInsets.all(5),
//                                     decoration: const BoxDecoration(
//                                       color: Colors.white,
//                                       shape: BoxShape.circle,
//                                     ),
//                                     child: Icon(
//                                       Icons.verified,
//                                       color: mainColor,
//                                       size: 21,
//                                     ),
//                                   ),
//                                 ],
//                               ),

//                               const SizedBox(height: 15),

//                               Text(
//                                 getValue('full_name'),
//                                 textAlign: TextAlign.center,
//                                 style: const TextStyle(
//                                   fontSize: 21,
//                                   fontWeight: FontWeight.bold,
//                                   color: Color(0xff222222),
//                                 ),
//                               ),

//                               const SizedBox(height: 9),

//                               Container(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 16,
//                                   vertical: 7,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   color: mainColor.withOpacity(.10),
//                                   borderRadius: BorderRadius.circular(30),
//                                 ),
//                                 child: Text(
//                                   'STUDENT',
//                                   style: TextStyle(
//                                     color: mainColor,
//                                     fontSize: 11,
//                                     fontWeight: FontWeight.bold,
//                                     letterSpacing: 1,
//                                   ),
//                                 ),
//                               ),

//                               const SizedBox(height: 20),

//                               // EDIT BUTTON

//                               SizedBox(
//                                 width: double.infinity,
//                                 child: ElevatedButton.icon(
//                                   onPressed: openEditProfile,
//                                   icon: const Icon(
//                                     Icons.edit_outlined,
//                                     size: 18,
//                                   ),
//                                   label: const Text(
//                                     'Edit Profile',
//                                     style: TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: mainColor,
//                                     foregroundColor: Colors.white,
//                                     padding: const EdgeInsets.symmetric(
//                                       vertical: 14,
//                                     ),
//                                     elevation: 0,
//                                     shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(12),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),

//                         const SizedBox(height: 26),

//                         // =====================================
//                         // PERSONAL INFORMATION
//                         // =====================================

//                         _sectionTitle(
//                           'PERSONAL INFORMATION',
//                           'Your registered account information',
//                         ),

//                         const SizedBox(height: 13),

//                         _card(
//                           child: Column(
//                             children: [

//                               _infoRow(
//                                 icon: Icons.email_outlined,
//                                 iconColor: const Color(0xff238A65),
//                                 iconBg: const Color(0xffE6F5EE),
//                                 title: 'Email Address',
//                                 value: getValue('email'),
//                               ),

//                               Divider(
//                                 height: 28,
//                                 color: Colors.grey.shade200,
//                               ),

//                               _infoRow(
//                                 icon: Icons.phone_outlined,
//                                 iconColor: const Color(0xff2385B4),
//                                 iconBg: const Color(0xffE6F2F8),
//                                 title: 'Phone Number',
//                                 value: getValue('phone'),
//                               ),

//                               Divider(
//                                 height: 28,
//                                 color: Colors.grey.shade200,
//                               ),

//                               _infoRow(
//                                 icon: Icons.badge_outlined,
//                                 iconColor: const Color(0xffB8752D),
//                                 iconBg: const Color(0xffFFF1E2),
//                                 title: 'CNIC / National ID',
//                                 value: getValue('cnic'),
//                               ),
//                             ],
//                           ),
//                         ),

//                         const SizedBox(height: 26),

//                         // =====================================
//                         // LOCATION INFORMATION
//                         // =====================================

//                         _sectionTitle(
//                           'LOCATION INFORMATION',
//                           'Your registered residential location',
//                         ),

//                         const SizedBox(height: 13),

//                         _card(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [

//                               _infoRow(
//                                 icon: Icons.location_on_outlined,
//                                 iconColor: const Color(0xff6855CC),
//                                 iconBg: const Color(0xffEFEDFC),
//                                 title: 'City / Location',
//                                 value: getValue('location'),
//                               ),

//                               Divider(
//                                 height: 30,
//                                 color: Colors.grey.shade200,
//                               ),

//                               const Text(
//                                 'LOCATION COORDINATES',
//                                 style: TextStyle(
//                                   fontSize: 11,
//                                   color: Colors.grey,
//                                   fontWeight: FontWeight.bold,
//                                   letterSpacing: .8,
//                                 ),
//                               ),

//                               const SizedBox(height: 13),

//                               Row(
//                                 children: [
//                                   Expanded(
//                                     child: _coordinateBox(
//                                       title: 'Latitude',
//                                       value: getValue('latitude'),
//                                       icon: Icons.explore_outlined,
//                                     ),
//                                   ),

//                                   const SizedBox(width: 12),

//                                   Expanded(
//                                     child: _coordinateBox(
//                                       title: 'Longitude',
//                                       value: getValue('longitude'),
//                                       icon: Icons.explore_outlined,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),

//                         const SizedBox(height: 24),

//                         // =====================================
//                         // FOOTER
//                         // =====================================

//                         Center(
//                           child: Text(
//                             'House of Tutor • Student Account',
//                             style: TextStyle(
//                               color: Colors.grey.shade500,
//                               fontSize: 11,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//     );
//   }
// }






















// // import 'dart:convert';

// // import 'package:flutter/material.dart';
// // import 'package:house_of_tutor/services/api_client.dart';

// // class StudentProfile extends StatefulWidget {
// //   const StudentProfile({super.key});

// //   @override
// //   State<StudentProfile> createState() => _StudentProfileState();
// // }

// // class _StudentProfileState extends State<StudentProfile> {
// //   // =========================================================
// //   // THEME
// //   // =========================================================

// //   final Color mainColor = const Color(0xff1E8E7E);
// //   final Color backgroundColor = const Color(0xffF4F6F8);

// //   bool isLoading = true;
// //   bool isSaving = false;

// //   Map<String, dynamic> profileData = {};

// //   String errorMessage = '';

// //   // =========================================================
// //   // INIT
// //   // =========================================================

// //   @override
// //   void initState() {
// //     super.initState();
// //     fetchStudentProfile();
// //   }

// //   // =========================================================
// //   // GET STUDENT PROFILE API
// //   // GET /api/Student/my-profile
// //   // =========================================================

// //   Future<void> fetchStudentProfile({bool showLoader = true}) async {
// //     if (showLoader && mounted) {
// //       setState(() {
// //         isLoading = true;
// //         errorMessage = '';
// //       });
// //     }

// //     try {
// //       final response = await ApiClient.get(
// //         '/api/Student/my-profile',
// //       );

// //       final data = await ApiClient.decodeJson(response);

// //       if (!mounted) return;

// //       if (response.statusCode == 200) {
// //         if (data is Map) {
// //           setState(() {
// //             profileData = Map<String, dynamic>.from(data);
// //             isLoading = false;
// //             errorMessage = '';
// //           });
// //         } else {
// //           setState(() {
// //             isLoading = false;
// //             errorMessage = 'Invalid profile response from server.';
// //           });
// //         }
// //       } else {
// //         setState(() {
// //           isLoading = false;
// //           errorMessage = data is Map
// //               ? (data['message'] ?? 'Failed to load profile').toString()
// //               : 'Failed to load profile';
// //         });
// //       }
// //     } catch (e) {
// //       if (!mounted) return;

// //       setState(() {
// //         isLoading = false;
// //         errorMessage = 'Unable to connect to server. Please try again.';
// //       });
// //     }
// //   }

// //   // =========================================================
// //   // PUT EDIT PROFILE API
// //   // PUT /api/Student/edit-profile
// //   // =========================================================

// //   Future<bool> updateStudentProfile({
// //     required String fullName,
// //     required String phone,
// //     required String cnic,
// //     required String location,
// //     required String latitude,
// //     required String longitude,
// //   }) async {
// //     if (isSaving) return false;

// //     setState(() {
// //       isSaving = true;
// //     });

// //     try {
// //       final double? lat = latitude.trim().isEmpty
// //           ? null
// //           : double.tryParse(latitude.trim());

// //       final double? lng = longitude.trim().isEmpty
// //           ? null
// //           : double.tryParse(longitude.trim());

// //       final Map<String, dynamic> body = {
// //         'fullName': fullName.trim(),
// //         'phone': phone.trim(),
// //         'cnic': cnic.trim().isEmpty ? null : cnic.trim(),
// //         'location': location.trim().isEmpty ? null : location.trim(),
// //         'latitude': lat,
// //         'longitude': lng,
// //       };

// //       final response = await ApiClient.put(
// //         '/api/Student/edit-profile',
// //         body,
// //       );

// //       final data = await ApiClient.decodeJson(response);

// //       if (!mounted) return false;

// //       if (response.statusCode == 200) {
// //         setState(() {
// //           if (data is Map) {
// //             profileData = Map<String, dynamic>.from(data);
// //           }
// //           isSaving = false;
// //         });

// //         return true;
// //       } else {
// //         final message = data is Map
// //             ? (data['message'] ?? 'Failed to update profile').toString()
// //             : 'Failed to update profile';

// //         setState(() {
// //           isSaving = false;
// //         });

// //         showMessage(message, isError: true);

// //         return false;
// //       }
// //     } catch (e) {
// //       if (!mounted) return false;

// //       setState(() {
// //         isSaving = false;
// //       });

// //       showMessage(
// //         'Something went wrong. Please try again.',
// //         isError: true,
// //       );

// //       return false;
// //     }
// //   }

// //   // =========================================================
// //   // SNACKBAR
// //   // =========================================================

// //   void showMessage(String message, {bool isError = false}) {
// //     if (!mounted) return;

// //     ScaffoldMessenger.of(context).hideCurrentSnackBar();

// //     ScaffoldMessenger.of(context).showSnackBar(
// //       SnackBar(
// //         content: Text(message),
// //         backgroundColor: isError
// //             ? Colors.red.shade700
// //             : mainColor,
// //         behavior: SnackBarBehavior.floating,
// //         margin: const EdgeInsets.all(16),
// //         shape: RoundedRectangleBorder(
// //           borderRadius: BorderRadius.circular(12),
// //         ),
// //       ),
// //     );
// //   }

// //   // =========================================================
// //   // INITIALS
// //   // =========================================================

// //   String get initials {
// //     final name = (profileData['full_name'] ?? '').toString().trim();

// //     if (name.isEmpty) return 'S';

// //     final parts = name.split(' ').where((e) => e.isNotEmpty).toList();

// //     return parts.take(2).map((e) => e[0]).join().toUpperCase();
// //   }

// //   // =========================================================
// //   // SAFE VALUE
// //   // =========================================================

// //   String getValue(String key) {
// //     final value = profileData[key];

// //     if (value == null || value.toString().trim().isEmpty) {
// //       return 'Not provided';
// //     }

// //     return value.toString();
// //   }

// //   // =========================================================
// //   // EDIT PROFILE DIALOG
// //   // =========================================================

// //   void openEditProfile() {
// //     final nameController = TextEditingController(
// //       text: profileData['full_name']?.toString() ?? '',
// //     );

// //     final phoneController = TextEditingController(
// //       text: profileData['phone']?.toString() ?? '',
// //     );

// //     final cnicController = TextEditingController(
// //       text: profileData['cnic']?.toString() ?? '',
// //     );

// //     final locationController = TextEditingController(
// //       text: profileData['location']?.toString() ?? '',
// //     );

// //     final latitudeController = TextEditingController(
// //       text: profileData['latitude']?.toString() ?? '',
// //     );

// //     final longitudeController = TextEditingController(
// //       text: profileData['longitude']?.toString() ?? '',
// //     );

// //     final formKey = GlobalKey<FormState>();

// //     showDialog(
// //       context: context,
// //       barrierDismissible: false,
// //       builder: (dialogContext) {
// //         return StatefulBuilder(
// //           builder: (context, setDialogState) {
// //             return Dialog(
// //               insetPadding: const EdgeInsets.symmetric(
// //                 horizontal: 16,
// //                 vertical: 24,
// //               ),
// //               shape: RoundedRectangleBorder(
// //                 borderRadius: BorderRadius.circular(22),
// //               ),
// //               child: ConstrainedBox(
// //                 constraints: const BoxConstraints(maxWidth: 500),
// //                 child: SingleChildScrollView(
// //                   padding: const EdgeInsets.all(22),
// //                   child: Form(
// //                     key: formKey,
// //                     child: Column(
// //                       mainAxisSize: MainAxisSize.min,
// //                       crossAxisAlignment: CrossAxisAlignment.start,
// //                       children: [

// //                         // HEADER

// //                         Row(
// //                           children: [
// //                             Container(
// //                               padding: const EdgeInsets.all(12),
// //                               decoration: BoxDecoration(
// //                                 color: mainColor.withOpacity(0.10),
// //                                 borderRadius: BorderRadius.circular(12),
// //                               ),
// //                               child: Icon(
// //                                 Icons.edit_outlined,
// //                                 color: mainColor,
// //                                 size: 25,
// //                               ),
// //                             ),

// //                             const SizedBox(width: 12),

// //                             const Expanded(
// //                               child: Column(
// //                                 crossAxisAlignment: CrossAxisAlignment.start,
// //                                 children: [
// //                                   Text(
// //                                     'Edit Profile',
// //                                     style: TextStyle(
// //                                       fontSize: 20,
// //                                       fontWeight: FontWeight.bold,
// //                                     ),
// //                                   ),
// //                                   SizedBox(height: 4),
// //                                   Text(
// //                                     'Update your personal information',
// //                                     style: TextStyle(
// //                                       fontSize: 12,
// //                                       color: Colors.grey,
// //                                     ),
// //                                   ),
// //                                 ],
// //                               ),
// //                             ),

// //                             IconButton(
// //                               onPressed: isSaving
// //                                   ? null
// //                                   : () => Navigator.pop(dialogContext),
// //                               icon: const Icon(Icons.close),
// //                             ),
// //                           ],
// //                         ),

// //                         const SizedBox(height: 24),

// //                         // PERSONAL INFORMATION

// //                         _editSectionTitle('PERSONAL INFORMATION'),

// //                         const SizedBox(height: 12),

// //                         _editField(
// //                           controller: nameController,
// //                           label: 'Full Name',
// //                           icon: Icons.person_outline,
// //                           requiredField: true,
// //                         ),

// //                         const SizedBox(height: 14),

// //                         _editField(
// //                           controller: phoneController,
// //                           label: 'Phone Number',
// //                           icon: Icons.phone_outlined,
// //                           requiredField: true,
// //                           keyboardType: TextInputType.phone,
// //                         ),

// //                         const SizedBox(height: 14),

// //                         _editField(
// //                           controller: cnicController,
// //                           label: 'CNIC / National ID',
// //                           icon: Icons.badge_outlined,
// //                           keyboardType: TextInputType.number,
// //                         ),

// //                         const SizedBox(height: 22),

// //                         // LOCATION INFORMATION

// //                         _editSectionTitle('LOCATION INFORMATION'),

// //                         const SizedBox(height: 12),

// //                         _editField(
// //                           controller: locationController,
// //                           label: 'City / Location',
// //                           icon: Icons.location_on_outlined,
// //                         ),

// //                         const SizedBox(height: 14),

// //                         _editField(
// //                           controller: latitudeController,
// //                           label: 'Latitude',
// //                           icon: Icons.explore_outlined,
// //                           keyboardType: const TextInputType.numberWithOptions(
// //                             decimal: true,
// //                             signed: true,
// //                           ),
// //                           validator: (value) {
// //                             if (value == null || value.trim().isEmpty) {
// //                               return null;
// //                             }

// //                             final number = double.tryParse(value.trim());

// //                             if (number == null ||
// //                                 number < -90 ||
// //                                 number > 90) {
// //                               return 'Enter valid latitude (-90 to 90)';
// //                             }

// //                             return null;
// //                           },
// //                         ),

// //                         const SizedBox(height: 14),

// //                         _editField(
// //                           controller: longitudeController,
// //                           label: 'Longitude',
// //                           icon: Icons.explore_outlined,
// //                           keyboardType: const TextInputType.numberWithOptions(
// //                             decimal: true,
// //                             signed: true,
// //                           ),
// //                           validator: (value) {
// //                             if (value == null || value.trim().isEmpty) {
// //                               return null;
// //                             }

// //                             final number = double.tryParse(value.trim());

// //                             if (number == null ||
// //                                 number < -180 ||
// //                                 number > 180) {
// //                               return 'Enter valid longitude (-180 to 180)';
// //                             }

// //                             return null;
// //                           },
// //                         ),

// //                         const SizedBox(height: 22),

// //                         // BUTTONS

// //                         Row(
// //                           children: [
// //                             Expanded(
// //                               child: OutlinedButton(
// //                                 onPressed: isSaving
// //                                     ? null
// //                                     : () => Navigator.pop(dialogContext),
// //                                 style: OutlinedButton.styleFrom(
// //                                   padding: const EdgeInsets.symmetric(
// //                                     vertical: 15,
// //                                   ),
// //                                   side: BorderSide(
// //                                     color: Colors.grey.shade300,
// //                                   ),
// //                                   shape: RoundedRectangleBorder(
// //                                     borderRadius: BorderRadius.circular(12),
// //                                   ),
// //                                 ),
// //                                 child: const Text(
// //                                   'Cancel',
// //                                   style: TextStyle(
// //                                     color: Colors.black87,
// //                                     fontWeight: FontWeight.w600,
// //                                   ),
// //                                 ),
// //                               ),
// //                             ),

// //                             const SizedBox(width: 12),

// //                             Expanded(
// //                               child: ElevatedButton(
// //                                 onPressed: isSaving
// //                                     ? null
// //                                     : () async {
// //                                         if (!formKey.currentState!.validate()) {
// //                                           return;
// //                                         }

// //                                         // Latitude and longitude should
// //                                         // either both be provided or both
// //                                         // remain empty.

// //                                         final lat = latitudeController.text.trim();
// //                                         final lng = longitudeController.text.trim();

// //                                         if (lat.isEmpty != lng.isEmpty) {
// //                                           showMessage(
// //                                             'Enter both latitude and longitude, or leave both empty.',
// //                                             isError: true,
// //                                           );
// //                                           return;
// //                                         }

// //                                         setDialogState(() {});

// //                                         final success = await updateStudentProfile(
// //                                           fullName: nameController.text,
// //                                           phone: phoneController.text,
// //                                           cnic: cnicController.text,
// //                                           location: locationController.text,
// //                                           latitude: lat,
// //                                           longitude: lng,
// //                                         );

// //                                         if (!mounted) return;

// //                                         if (success) {
// //                                           Navigator.pop(dialogContext);

// //                                           showMessage(
// //                                             'Profile updated successfully!',
// //                                           );
// //                                         } else {
// //                                           setDialogState(() {});
// //                                         }
// //                                       },
// //                                 style: ElevatedButton.styleFrom(
// //                                   backgroundColor: mainColor,
// //                                   foregroundColor: Colors.white,
// //                                   padding: const EdgeInsets.symmetric(
// //                                     vertical: 15,
// //                                   ),
// //                                   elevation: 0,
// //                                   shape: RoundedRectangleBorder(
// //                                     borderRadius: BorderRadius.circular(12),
// //                                   ),
// //                                 ),
// //                                 child: isSaving
// //                                     ? const SizedBox(
// //                                         height: 20,
// //                                         width: 20,
// //                                         child: CircularProgressIndicator(
// //                                           color: Colors.white,
// //                                           strokeWidth: 2,
// //                                         ),
// //                                       )
// //                                     : const Text(
// //                                         'Save Changes',
// //                                         style: TextStyle(
// //                                           fontWeight: FontWeight.bold,
// //                                         ),
// //                                       ),
// //                               ),
// //                             ),
// //                           ],
// //                         ),
// //                       ],
// //                     ),
// //                   ),
// //                 ),
// //               ),
// //             );
// //           },
// //         );
// //       },
// //     ).whenComplete(() {
// //       nameController.dispose();
// //       phoneController.dispose();
// //       cnicController.dispose();
// //       locationController.dispose();
// //       latitudeController.dispose();
// //       longitudeController.dispose();
// //     });
// //   }

// //   // =========================================================
// //   // EDIT FIELD
// //   // =========================================================

// //   Widget _editField({
// //     required TextEditingController controller,
// //     required String label,
// //     required IconData icon,
// //     TextInputType keyboardType = TextInputType.text,
// //     bool requiredField = false,
// //     String? Function(String?)? validator,
// //   }) {
// //     return TextFormField(
// //       controller: controller,
// //       keyboardType: keyboardType,
// //       textCapitalization: TextCapitalization.words,
// //       style: const TextStyle(
// //         fontSize: 14,
// //         fontWeight: FontWeight.w500,
// //       ),
// //       decoration: InputDecoration(
// //         labelText: label,
// //         prefixIcon: Icon(
// //           icon,
// //           color: mainColor,
// //           size: 21,
// //         ),
// //         filled: true,
// //         fillColor: Colors.grey.shade50,
// //         contentPadding: const EdgeInsets.symmetric(
// //           horizontal: 14,
// //           vertical: 16,
// //         ),
// //         border: OutlineInputBorder(
// //           borderRadius: BorderRadius.circular(12),
// //           borderSide: BorderSide(color: Colors.grey.shade200),
// //         ),
// //         enabledBorder: OutlineInputBorder(
// //           borderRadius: BorderRadius.circular(12),
// //           borderSide: BorderSide(color: Colors.grey.shade200),
// //         ),
// //         focusedBorder: OutlineInputBorder(
// //           borderRadius: BorderRadius.circular(12),
// //           borderSide: BorderSide(
// //             color: mainColor,
// //             width: 1.5,
// //           ),
// //         ),
// //       ),
// //       validator: validator ??
// //           (value) {
// //             if (requiredField && (value == null || value.trim().isEmpty)) {
// //               return '$label is required';
// //             }

// //             return null;
// //           },
// //     );
// //   }

// //   // =========================================================
// //   // SECTION TITLE IN EDIT DIALOG
// //   // =========================================================

// //   Widget _editSectionTitle(String title) {
// //     return Text(
// //       title,
// //       style: TextStyle(
// //         color: mainColor,
// //         fontSize: 11,
// //         fontWeight: FontWeight.bold,
// //         letterSpacing: 1.2,
// //       ),
// //     );
// //   }

// //   // =========================================================
// //   // PROFILE CARD
// //   // =========================================================

// //   Widget _card({required Widget child}) {
// //     return Container(
// //       width: double.infinity,
// //       padding: const EdgeInsets.all(19),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(18),
// //         border: Border.all(
// //           color: Colors.grey.shade100,
// //         ),
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.black.withOpacity(0.035),
// //             blurRadius: 15,
// //             offset: const Offset(0, 5),
// //           ),
// //         ],
// //       ),
// //       child: child,
// //     );
// //   }

// //   // =========================================================
// //   // SECTION TITLE
// //   // =========================================================

// //   Widget _sectionTitle(String title, String subtitle) {
// //     return Padding(
// //       padding: const EdgeInsets.only(left: 3),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Text(
// //             title,
// //             style: const TextStyle(
// //               fontSize: 13,
// //               fontWeight: FontWeight.bold,
// //               letterSpacing: 1,
// //               color: Color(0xff333333),
// //             ),
// //           ),
// //           const SizedBox(height: 4),
// //           Text(
// //             subtitle,
// //             style: TextStyle(
// //               fontSize: 12,
// //               color: Colors.grey.shade500,
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   // =========================================================
// //   // INFO ROW
// //   // =========================================================

// //   Widget _infoRow({
// //     required IconData icon,
// //     required Color iconColor,
// //     required Color iconBg,
// //     required String title,
// //     required String value,
// //   }) {
// //     return Row(
// //       children: [
// //         Container(
// //           height: 43,
// //           width: 43,
// //           decoration: BoxDecoration(
// //             color: iconBg,
// //             borderRadius: BorderRadius.circular(12),
// //           ),
// //           child: Icon(
// //             icon,
// //             color: iconColor,
// //             size: 21,
// //           ),
// //         ),

// //         const SizedBox(width: 13),

// //         Expanded(
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               Text(
// //                 title,
// //                 style: TextStyle(
// //                   fontSize: 11,
// //                   color: Colors.grey.shade500,
// //                   fontWeight: FontWeight.w500,
// //                 ),
// //               ),

// //               const SizedBox(height: 5),

// //               Text(
// //                 value,
// //                 style: const TextStyle(
// //                   fontSize: 14,
// //                   fontWeight: FontWeight.w600,
// //                   color: Color(0xff333333),
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ],
// //     );
// //   }

// //   // =========================================================
// //   // COORDINATE BOX
// //   // =========================================================

// //   Widget _coordinateBox({
// //     required String title,
// //     required String value,
// //     required IconData icon,
// //   }) {
// //     return Container(
// //       padding: const EdgeInsets.all(13),
// //       decoration: BoxDecoration(
// //         color: backgroundColor,
// //         borderRadius: BorderRadius.circular(13),
// //         border: Border.all(
// //           color: Colors.grey.shade200,
// //         ),
// //       ),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Row(
// //             children: [
// //               Icon(
// //                 icon,
// //                 color: mainColor,
// //                 size: 16,
// //               ),
// //               const SizedBox(width: 6),
// //               Text(
// //                 title,
// //                 style: TextStyle(
// //                   color: Colors.grey.shade600,
// //                   fontSize: 11,
// //                 ),
// //               ),
// //             ],
// //           ),

// //           const SizedBox(height: 8),

// //           Text(
// //             value,
// //             maxLines: 1,
// //             overflow: TextOverflow.ellipsis,
// //             style: const TextStyle(
// //               fontSize: 13,
// //               fontWeight: FontWeight.bold,
// //               color: Color(0xff333333),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   // =========================================================
// //   // ERROR SCREEN
// //   // =========================================================

// //   Widget _errorView() {
// //     return Center(
// //       child: Padding(
// //         padding: const EdgeInsets.all(28),
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             Container(
// //               padding: const EdgeInsets.all(22),
// //               decoration: BoxDecoration(
// //                 color: Colors.red.withOpacity(.08),
// //                 shape: BoxShape.circle,
// //               ),
// //               child: const Icon(
// //                 Icons.wifi_off_rounded,
// //                 color: Colors.red,
// //                 size: 42,
// //               ),
// //             ),

// //             const SizedBox(height: 18),

// //             const Text(
// //               'Unable to Load Profile',
// //               style: TextStyle(
// //                 fontSize: 19,
// //                 fontWeight: FontWeight.bold,
// //               ),
// //             ),

// //             const SizedBox(height: 8),

// //             Text(
// //               errorMessage,
// //               textAlign: TextAlign.center,
// //               style: TextStyle(
// //                 color: Colors.grey.shade600,
// //                 fontSize: 13,
// //               ),
// //             ),

// //             const SizedBox(height: 22),

// //             ElevatedButton.icon(
// //               onPressed: () => fetchStudentProfile(),
// //               icon: const Icon(Icons.refresh),
// //               label: const Text('Try Again'),
// //               style: ElevatedButton.styleFrom(
// //                 backgroundColor: mainColor,
// //                 foregroundColor: Colors.white,
// //                 padding: const EdgeInsets.symmetric(
// //                   horizontal: 24,
// //                   vertical: 13,
// //                 ),
// //                 shape: RoundedRectangleBorder(
// //                   borderRadius: BorderRadius.circular(12),
// //                 ),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   // =========================================================
// //   // MAIN UI
// //   // =========================================================

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: backgroundColor,

// //       // APP BAR

// //       appBar: AppBar(
// //         backgroundColor: Colors.white,
// //         elevation: 0,
// //         centerTitle: true,

// //         leading: IconButton(
// //           onPressed: () => Navigator.pop(context),
// //           icon: Icon(
// //             Icons.arrow_back_ios_new,
// //             color: mainColor,
// //             size: 20,
// //           ),
// //         ),

// //         title: const Text(
// //           'My Profile',
// //           style: TextStyle(
// //             color: Color(0xff222222),
// //             fontWeight: FontWeight.bold,
// //             fontSize: 18,
// //           ),
// //         ),

// //         actions: [
// //           IconButton(
// //             tooltip: 'Refresh Profile',
// //             onPressed: isLoading
// //                 ? null
// //                 : () => fetchStudentProfile(),
// //             icon: Icon(
// //               Icons.refresh,
// //               color: mainColor,
// //             ),
// //           ),

// //           const SizedBox(width: 5),
// //         ],
// //       ),

// //       // BODY

// //       body: isLoading
// //           ? Center(
// //               child: CircularProgressIndicator(
// //                 color: mainColor,
// //               ),
// //             )
// //           : errorMessage.isNotEmpty && profileData.isEmpty
// //               ? _errorView()
// //               : RefreshIndicator(
// //                   color: mainColor,
// //                   onRefresh: () => fetchStudentProfile(),
// //                   child: SingleChildScrollView(
// //                     physics: const AlwaysScrollableScrollPhysics(),
// //                     padding: const EdgeInsets.fromLTRB(17, 20, 17, 30),
// //                     child: Column(
// //                       crossAxisAlignment: CrossAxisAlignment.start,
// //                       children: [

// //                         // =====================================
// //                         // PROFILE HEADER CARD
// //                         // =====================================

// //                         _card(
// //                           child: Column(
// //                             children: [

// //                               // AVATAR

// //                               Stack(
// //                                 alignment: Alignment.bottomRight,
// //                                 children: [
// //                                   Container(
// //                                     padding: const EdgeInsets.all(5),
// //                                     decoration: BoxDecoration(
// //                                       shape: BoxShape.circle,
// //                                       border: Border.all(
// //                                         color: mainColor.withOpacity(.35),
// //                                         width: 2,
// //                                       ),
// //                                     ),
// //                                     child: CircleAvatar(
// //                                       radius: 43,
// //                                       backgroundColor: mainColor.withOpacity(.12),
// //                                       child: Text(
// //                                         initials,
// //                                         style: TextStyle(
// //                                           color: mainColor,
// //                                           fontWeight: FontWeight.bold,
// //                                           fontSize: 30,
// //                                         ),
// //                                       ),
// //                                     ),
// //                                   ),

// //                                   Container(
// //                                     padding: const EdgeInsets.all(5),
// //                                     decoration: const BoxDecoration(
// //                                       color: Colors.white,
// //                                       shape: BoxShape.circle,
// //                                     ),
// //                                     child: Icon(
// //                                       Icons.verified,
// //                                       color: mainColor,
// //                                       size: 21,
// //                                     ),
// //                                   ),
// //                                 ],
// //                               ),

// //                               const SizedBox(height: 15),

// //                               Text(
// //                                 getValue('full_name'),
// //                                 textAlign: TextAlign.center,
// //                                 style: const TextStyle(
// //                                   fontSize: 21,
// //                                   fontWeight: FontWeight.bold,
// //                                   color: Color(0xff222222),
// //                                 ),
// //                               ),

// //                               const SizedBox(height: 9),

// //                               Container(
// //                                 padding: const EdgeInsets.symmetric(
// //                                   horizontal: 16,
// //                                   vertical: 7,
// //                                 ),
// //                                 decoration: BoxDecoration(
// //                                   color: mainColor.withOpacity(.10),
// //                                   borderRadius: BorderRadius.circular(30),
// //                                 ),
// //                                 child: Text(
// //                                   'STUDENT',
// //                                   style: TextStyle(
// //                                     color: mainColor,
// //                                     fontSize: 11,
// //                                     fontWeight: FontWeight.bold,
// //                                     letterSpacing: 1,
// //                                   ),
// //                                 ),
// //                               ),

// //                               const SizedBox(height: 20),

// //                               // EDIT BUTTON

// //                               SizedBox(
// //                                 width: double.infinity,
// //                                 child: ElevatedButton.icon(
// //                                   onPressed: openEditProfile,
// //                                   icon: const Icon(
// //                                     Icons.edit_outlined,
// //                                     size: 18,
// //                                   ),
// //                                   label: const Text(
// //                                     'Edit Profile',
// //                                     style: TextStyle(
// //                                       fontWeight: FontWeight.bold,
// //                                     ),
// //                                   ),
// //                                   style: ElevatedButton.styleFrom(
// //                                     backgroundColor: mainColor,
// //                                     foregroundColor: Colors.white,
// //                                     padding: const EdgeInsets.symmetric(
// //                                       vertical: 14,
// //                                     ),
// //                                     elevation: 0,
// //                                     shape: RoundedRectangleBorder(
// //                                       borderRadius: BorderRadius.circular(12),
// //                                     ),
// //                                   ),
// //                                 ),
// //                               ),
// //                             ],
// //                           ),
// //                         ),

// //                         const SizedBox(height: 26),

// //                         // =====================================
// //                         // PERSONAL INFORMATION
// //                         // =====================================

// //                         _sectionTitle(
// //                           'PERSONAL INFORMATION',
// //                           'Your registered account information',
// //                         ),

// //                         const SizedBox(height: 13),

// //                         _card(
// //                           child: Column(
// //                             children: [

// //                               _infoRow(
// //                                 icon: Icons.email_outlined,
// //                                 iconColor: const Color(0xff238A65),
// //                                 iconBg: const Color(0xffE6F5EE),
// //                                 title: 'Email Address',
// //                                 value: getValue('email'),
// //                               ),

// //                               Divider(
// //                                 height: 28,
// //                                 color: Colors.grey.shade200,
// //                               ),

// //                               _infoRow(
// //                                 icon: Icons.phone_outlined,
// //                                 iconColor: const Color(0xff2385B4),
// //                                 iconBg: const Color(0xffE6F2F8),
// //                                 title: 'Phone Number',
// //                                 value: getValue('phone'),
// //                               ),

// //                               Divider(
// //                                 height: 28,
// //                                 color: Colors.grey.shade200,
// //                               ),

// //                               _infoRow(
// //                                 icon: Icons.badge_outlined,
// //                                 iconColor: const Color(0xffB8752D),
// //                                 iconBg: const Color(0xffFFF1E2),
// //                                 title: 'CNIC / National ID',
// //                                 value: getValue('cnic'),
// //                               ),
// //                             ],
// //                           ),
// //                         ),

// //                         const SizedBox(height: 26),

// //                         // =====================================
// //                         // LOCATION INFORMATION
// //                         // =====================================

// //                         _sectionTitle(
// //                           'LOCATION INFORMATION',
// //                           'Your registered residential location',
// //                         ),

// //                         const SizedBox(height: 13),

// //                         _card(
// //                           child: Column(
// //                             crossAxisAlignment: CrossAxisAlignment.start,
// //                             children: [

// //                               _infoRow(
// //                                 icon: Icons.location_on_outlined,
// //                                 iconColor: const Color(0xff6855CC),
// //                                 iconBg: const Color(0xffEFEDFC),
// //                                 title: 'City / Location',
// //                                 value: getValue('location'),
// //                               ),

// //                               Divider(
// //                                 height: 30,
// //                                 color: Colors.grey.shade200,
// //                               ),

// //                               const Text(
// //                                 'LOCATION COORDINATES',
// //                                 style: TextStyle(
// //                                   fontSize: 11,
// //                                   color: Colors.grey,
// //                                   fontWeight: FontWeight.bold,
// //                                   letterSpacing: .8,
// //                                 ),
// //                               ),

// //                               const SizedBox(height: 13),

// //                               Row(
// //                                 children: [
// //                                   Expanded(
// //                                     child: _coordinateBox(
// //                                       title: 'Latitude',
// //                                       value: getValue('latitude'),
// //                                       icon: Icons.explore_outlined,
// //                                     ),
// //                                   ),

// //                                   const SizedBox(width: 12),

// //                                   Expanded(
// //                                     child: _coordinateBox(
// //                                       title: 'Longitude',
// //                                       value: getValue('longitude'),
// //                                       icon: Icons.explore_outlined,
// //                                     ),
// //                                   ),
// //                                 ],
// //                               ),
// //                             ],
// //                           ),
// //                         ),

// //                         const SizedBox(height: 24),

// //                         // =====================================
// //                         // FOOTER
// //                         // =====================================

// //                         Center(
// //                           child: Text(
// //                             'House of Tutor • Student Account',
// //                             style: TextStyle(
// //                               color: Colors.grey.shade500,
// //                               fontSize: 11,
// //                               fontWeight: FontWeight.w500,
// //                             ),
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                   ),
// //                 ),
// //     );
// //   }
// // }