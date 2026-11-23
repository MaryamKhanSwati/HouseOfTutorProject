import 'package:flutter/material.dart';
import 'package:house_of_tutor/TutorHome.dart';
import 'package:house_of_tutor/services/api_client.dart';

class TutorProfile extends StatefulWidget {
  const TutorProfile({super.key});

  @override
  State<TutorProfile> createState() => _TutorProfileState();
}

class _TutorProfileState extends State<TutorProfile> {
  // =====================================================
  // THEME COLORS
  // =====================================================

  final Color primaryColor = const Color(0xff1E8E7E);
  final Color backgroundColor = const Color(0xffF4F6F8);

  bool loading = true;
  bool isSaving = false;

  Map<String, dynamic> tutor = {};

  String errorMessage = '';

  // =====================================================
  // INITIALIZE
  // =====================================================

  @override
  void initState() {
    super.initState();
    fetchTutorProfile();
  }

  // =====================================================
  // FETCH TUTOR PROFILE
  // GET /api/Tutor/my-profile
  // =====================================================

  Future<void> fetchTutorProfile({bool showLoader = true}) async {
    if (!mounted) return;

    if (showLoader) {
      setState(() {
        loading = true;
        errorMessage = '';
      });
    }

    try {
      final response = await ApiClient.get(
        '/api/Tutor/my-profile',
      );

      debugPrint('TUTOR PROFILE STATUS: ${response.statusCode}');
      debugPrint('TUTOR PROFILE BODY: ${response.body}');

      final decoded = await ApiClient.decodeJson(response);

      if (!mounted) return;

      if (response.statusCode == 200) {
        if (decoded is Map) {
          final profile = decoded['data'] is Map ? decoded['data'] : decoded;

          setState(() {
            tutor = Map<String, dynamic>.from(profile);
            loading = false;
            errorMessage = '';
          });
        } else {
          setState(() {
            loading = false;
            errorMessage = 'Invalid profile response from server.';
          });
        }
      } else {
        setState(() {
          loading = false;
          errorMessage = decoded is Map
              ? (decoded['message'] ?? 'Unable to load tutor profile')
                  .toString()
              : 'Unable to load tutor profile';
        });
      }
    } catch (e) {
      debugPrint('TUTOR PROFILE ERROR: $e');

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = 'Unable to connect to server. Please try again.';
      });
    }
  }

  // =====================================================
  // UPDATE TUTOR PROFILE
  // PUT /api/Tutor/edit-profile
  // =====================================================

  Future<bool> updateTutorProfile({
    required String fullName,
    required String phone,
    required String cnic,
    required String qualification,
    required String experience,
    required String radius,
  }) async {
    if (!mounted || isSaving) return false;

    setState(() {
      isSaving = true;
    });

    try {
      final num? experienceValue = experience.trim().isEmpty
          ? null
          : num.tryParse(experience.trim());

      final num? radiusValue =
          radius.trim().isEmpty ? null : num.tryParse(radius.trim());

      if (experience.trim().isNotEmpty && experienceValue == null) {
        showMessage('Please enter valid experience.', isError: true);
        return false;
      }

      if (radius.trim().isNotEmpty && radiusValue == null) {
        showMessage('Please enter a valid radius.', isError: true);
        return false;
      }

      final Map<String, dynamic> requestBody = {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'cnic': cnic.trim().isEmpty ? null : cnic.trim(),
        'qualification': qualification.trim(),
        'experience': experienceValue,
        'radius': radiusValue,
      };

      debugPrint('Updating tutor profile...');

      final response = await ApiClient.put(
        '/api/Tutor/edit-profile',
        requestBody,
      );

      debugPrint('UPDATE PROFILE STATUS: ${response.statusCode}');
      debugPrint('UPDATE PROFILE RESPONSE: ${response.body}');

      final decoded = await ApiClient.decodeJson(response);

      if (!mounted) return false;

      if (response.statusCode == 200) {
        final Map<String, dynamic> submittedValues = {
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'cnic': cnic.trim(),
          'qualification': qualification.trim(),
          'experience': experienceValue,
          'radius': radiusValue,
        };

        Map<String, dynamic> serverValues = {};
        if (decoded is Map) {
          final dynamic updatedData =
              decoded['data'] is Map ? decoded['data'] : decoded;
          if (updatedData is Map) {
            serverValues = Map<String, dynamic>.from(updatedData);
            serverValues.remove('message');
          }
        }

        setState(() {
          // Merge instead of replacing the complete profile.
          tutor = {
            ...tutor,
            ...submittedValues,
            ...serverValues,
          };
        });

        return true;
      }

      final message = decoded is Map
          ? (decoded['message'] ?? 'Profile update failed').toString()
          : 'Profile update failed';

      showMessage(message, isError: true);
      return false;
    } catch (e, stackTrace) {
      debugPrint('UPDATE TUTOR PROFILE ERROR: $e');
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

  // =====================================================
  // SHOW MESSAGE
  // =====================================================

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // =====================================================
  // SAFE PROFILE VALUE
  // =====================================================

  String getValue(String key) {
    final value = tutor[key];

    if (value == null || value.toString().trim().isEmpty) {
      return 'Not provided';
    }

    return value.toString();
  }

  // =====================================================
  // INITIALS
  // =====================================================

  String get initials {
    final name = (tutor['full_name'] ?? 'Tutor').toString().trim();

    if (name.isEmpty) return 'T';

    final parts = name.split(' ').where((e) => e.isNotEmpty).toList();

    return parts.take(2).map((e) => e[0]).join().toUpperCase();
  }

  // =====================================================
  // BACK BUTTON
  // =====================================================

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TutorHome(),
        ),
      );
    }
  }

  // =====================================================
  // OPEN EDIT PROFILE DIALOG
  // Controllers ab dialog widget ke andar hain (safe dispose)
  // =====================================================

  Future<void> openEditProfile() async {
    final bool? updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _EditTutorProfileDialog(
          tutor: tutor,
          primaryColor: primaryColor,
          onSave: updateTutorProfile,
        );
      },
    );

    if (updated == true && mounted) {
      showMessage('Tutor profile updated successfully!');
    }
  }

  // =====================================================
  // MAIN SECTION TITLE
  // =====================================================

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

  // =====================================================
  // WHITE CARD
  // =====================================================

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
            color: Colors.black.withOpacity(.035),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  // =====================================================
  // PROFILE INFORMATION ROW
  // =====================================================

  Widget _profileRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
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

  // =====================================================
  // LOADING ERROR VIEW
  // =====================================================

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
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
                size: 42,
                color: Colors.red,
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
              onPressed: () => fetchTutorProfile(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
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

  // =====================================================
  // MAIN UI
  // =====================================================

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
          onPressed: _goBack,
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: primaryColor,
            size: 20,
          ),
        ),
        title: const Text(
          'Tutor Profile',
          style: TextStyle(
            color: Color(0xff222222),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Profile',
            onPressed: loading ? null : () => fetchTutorProfile(),
            icon: Icon(
              Icons.refresh,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),

      // BODY

      body: loading
          ? Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : errorMessage.isNotEmpty && tutor.isEmpty
              ? _errorView()
              : RefreshIndicator(
                  color: primaryColor,
                  onRefresh: () => fetchTutorProfile(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(17, 20, 17, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PROFILE HEADER

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
                                        color: primaryColor.withOpacity(.35),
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 45,
                                      backgroundColor:
                                          primaryColor.withOpacity(.12),
                                      child: Text(
                                        initials,
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
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
                                      color: primaryColor,
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
                                  color: primaryColor.withOpacity(.10),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  'PROFESSIONAL TUTOR',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: .8,
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
                                    backgroundColor: primaryColor,
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
                              _profileRow(
                                icon: Icons.email_outlined,
                                iconColor: const Color(0xff238A65),
                                iconBg: const Color(0xffE6F5EE),
                                title: 'Email Address',
                                value: getValue('email'),
                              ),
                              Divider(
                                height: 29,
                                color: Colors.grey.shade200,
                              ),
                              _profileRow(
                                icon: Icons.phone_outlined,
                                iconColor: const Color(0xff2385B4),
                                iconBg: const Color(0xffE6F2F8),
                                title: 'Phone Number',
                                value: getValue('phone'),
                              ),
                              Divider(
                                height: 29,
                                color: Colors.grey.shade200,
                              ),
                              _profileRow(
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

                        // PROFESSIONAL INFORMATION

                        _sectionTitle(
                          'PROFESSIONAL INFORMATION',
                          'Your teaching qualifications and experience',
                        ),

                        const SizedBox(height: 13),

                        _card(
                          child: Column(
                            children: [
                              _profileRow(
                                icon: Icons.school_outlined,
                                iconColor: const Color(0xff6855CC),
                                iconBg: const Color(0xffEFEDFC),
                                title: 'Qualification',
                                value: getValue('qualification'),
                              ),
                              Divider(
                                height: 29,
                                color: Colors.grey.shade200,
                              ),
                              _profileRow(
                                icon: Icons.work_outline,
                                iconColor: const Color(0xff238A65),
                                iconBg: const Color(0xffE6F5EE),
                                title: 'Teaching Experience',
                                value: getValue('experience') == 'Not provided'
                                    ? 'Not provided'
                                    : '${getValue('experience')} Years',
                              ),
                              Divider(
                                height: 29,
                                color: Colors.grey.shade200,
                              ),
                              _profileRow(
                                icon: Icons.radar_outlined,
                                iconColor: const Color(0xff2385B4),
                                iconBg: const Color(0xffE6F2F8),
                                title: 'Service Radius',
                                value: getValue('radius') == 'Not provided'
                                    ? 'Not provided'
                                    : '${getValue('radius')} KM',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 25),

                        // FOOTER

                        Center(
                          child: Text(
                            'House of Tutor • Tutor Account',
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

typedef _TutorSaveCallback = Future<bool> Function({
  required String fullName,
  required String phone,
  required String cnic,
  required String qualification,
  required String experience,
  required String radius,
});

class _EditTutorProfileDialog extends StatefulWidget {
  final Map<String, dynamic> tutor;
  final Color primaryColor;
  final _TutorSaveCallback onSave;

  const _EditTutorProfileDialog({
    required this.tutor,
    required this.primaryColor,
    required this.onSave,
  });

  @override
  State<_EditTutorProfileDialog> createState() =>
      _EditTutorProfileDialogState();
}

class _EditTutorProfileDialogState extends State<_EditTutorProfileDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cnicController;
  late final TextEditingController _qualificationController;
  late final TextEditingController _experienceController;
  late final TextEditingController _radiusController;

  bool _saving = false;

  Color get _primaryColor => widget.primaryColor;

  @override
  void initState() {
    super.initState();

    final data = widget.tutor;

    _nameController =
        TextEditingController(text: data['full_name']?.toString() ?? '');
    _phoneController =
        TextEditingController(text: data['phone']?.toString() ?? '');
    _cnicController =
        TextEditingController(text: data['cnic']?.toString() ?? '');
    _qualificationController =
        TextEditingController(text: data['qualification']?.toString() ?? '');
    _experienceController =
        TextEditingController(text: data['experience']?.toString() ?? '');
    _radiusController =
        TextEditingController(text: data['radius']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cnicController.dispose();
    _qualificationController.dispose();
    _experienceController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _saving = true);

    final success = await widget.onSave(
      fullName: _nameController.text,
      phone: _phoneController.text,
      cnic: _cnicController.text,
      qualification: _qualificationController.text,
      experience: _experienceController.text,
      radius: _radiusController.text,
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
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        color: _primaryColor,
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
          color: _primaryColor,
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
            color: _primaryColor,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // HEADER

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          color: _primaryColor,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Tutor Profile',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Update your account information',
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
                  const SizedBox(height: 13),

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

                  // PROFESSIONAL INFORMATION

                  _sectionTitle('PROFESSIONAL INFORMATION'),
                  const SizedBox(height: 13),

                  _field(
                    controller: _qualificationController,
                    label: 'Qualification',
                    icon: Icons.school_outlined,
                    requiredField: true,
                  ),
                  const SizedBox(height: 14),

                  _field(
                    controller: _experienceController,
                    label: 'Experience (Years)',
                    icon: Icons.work_outline,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }

                      final number = num.tryParse(value.trim());

                      if (number == null || number < 0) {
                        return 'Enter valid experience';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  _field(
                    controller: _radiusController,
                    label: 'Service Radius (KM)',
                    icon: Icons.radar_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }

                      final number = num.tryParse(value.trim());

                      if (number == null || number < 0) {
                        return 'Enter a valid service radius';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // ACTION BUTTONS

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
                            backgroundColor: _primaryColor,
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
// import 'package:house_of_tutor/TutorHome.dart';
// import 'package:house_of_tutor/services/api_client.dart';

// class TutorProfile extends StatefulWidget {
//   const TutorProfile({super.key});

//   @override
//   State<TutorProfile> createState() => _TutorProfileState();
// }

// class _TutorProfileState extends State<TutorProfile> {
//   // =====================================================
//   // THEME COLORS
//   // =====================================================

//   final Color primaryColor = const Color(0xff1E8E7E);
//   final Color backgroundColor = const Color(0xffF4F6F8);

//   bool loading = true;
//   bool isSaving = false;

//   Map<String, dynamic> tutor = {};

//   String errorMessage = '';

//   // =====================================================
//   // INITIALIZE
//   // =====================================================

//   @override
//   void initState() {
//     super.initState();
//     fetchTutorProfile();
//   }

//   // =====================================================
//   // FETCH TUTOR PROFILE
//   // GET /api/Tutor/my-profile
//   // =====================================================

//   Future<void> fetchTutorProfile({bool showLoader = true}) async {
//     if (!mounted) return;

//     if (showLoader) {
//       setState(() {
//         loading = true;
//         errorMessage = '';
//       });
//     }

//     try {
//       final response = await ApiClient.get(
//         '/api/Tutor/my-profile',
//       );

//       debugPrint('TUTOR PROFILE STATUS: ${response.statusCode}');
//       debugPrint('TUTOR PROFILE BODY: ${response.body}');

//       final decoded = await ApiClient.decodeJson(response);

//       if (!mounted) return;

//       if (response.statusCode == 200) {
//         if (decoded is Map) {
//           final profile = decoded['data'] is Map
//               ? decoded['data']
//               : decoded;

//           setState(() {
//             tutor = Map<String, dynamic>.from(profile);
//             loading = false;
//             errorMessage = '';
//           });
//         } else {
//           setState(() {
//             loading = false;
//             errorMessage = 'Invalid profile response from server.';
//           });
//         }
//       } else {
//         setState(() {
//           loading = false;
//           errorMessage = decoded is Map
//               ? (decoded['message'] ?? 'Unable to load tutor profile')
//                   .toString()
//               : 'Unable to load tutor profile';
//         });
//       }
//     } catch (e) {
//       debugPrint('TUTOR PROFILE ERROR: $e');

//       if (!mounted) return;

//       setState(() {
//         loading = false;
//         errorMessage = 'Unable to connect to server. Please try again.';
//       });
//     }
//   }

//   // =====================================================
//   // UPDATE TUTOR PROFILE
//   // PUT /api/Tutor/edit-profile
//   // =====================================================

//   Future<bool> updateTutorProfile({
//     required String fullName,
//     required String phone,
//     required String cnic,
//     required String qualification,
//     required String experience,
//     required String radius,
//   }) async {
//     if (!mounted || isSaving) return false;

//     setState(() {
//       isSaving = true;
//     });

//     try {
//       final num? experienceValue = experience.trim().isEmpty
//           ? null
//           : num.tryParse(experience.trim());

//       final num? radiusValue = radius.trim().isEmpty
//           ? null
//           : num.tryParse(radius.trim());

//       if (experience.trim().isNotEmpty && experienceValue == null) {
//         showMessage('Please enter valid experience.', isError: true);
//         return false;
//       }

//       if (radius.trim().isNotEmpty && radiusValue == null) {
//         showMessage('Please enter a valid radius.', isError: true);
//         return false;
//       }

//       final Map<String, dynamic> requestBody = {
//         'fullName': fullName.trim(),
//         'phone': phone.trim(),
//         'cnic': cnic.trim().isEmpty ? null : cnic.trim(),
//         'qualification': qualification.trim(),
//         'experience': experienceValue,
//         'radius': radiusValue,
//       };

//       debugPrint('Updating tutor profile...');

//       final response = await ApiClient.put(
//         '/api/Tutor/edit-profile',
//         requestBody,
//       );

//       debugPrint('UPDATE PROFILE STATUS: ${response.statusCode}');
//       debugPrint('UPDATE PROFILE RESPONSE: ${response.body}');

//       final decoded = await ApiClient.decodeJson(response);

//       if (!mounted) return false;

//       if (response.statusCode == 200) {
//         if (decoded is Map) {
//           final updatedData = decoded['data'] is Map
//               ? decoded['data']
//               : decoded;

//           setState(() {
//             tutor = {
//               ...tutor,
//               ...Map<String, dynamic>.from(updatedData),
//             };
//           });
//         } else {
//           await fetchTutorProfile(showLoader: false);
//         }

//         return true;
//       }

//       final message = decoded is Map
//           ? (decoded['message'] ?? 'Profile update failed').toString()
//           : 'Profile update failed';

//       showMessage(message, isError: true);
//       return false;
//     } catch (e, stackTrace) {
//       debugPrint('UPDATE TUTOR PROFILE ERROR: $e');
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

//   // =====================================================
//   // SHOW MESSAGE
//   // =====================================================

//   void showMessage(String message, {bool isError = false}) {
//     if (!mounted) return;

//     ScaffoldMessenger.of(context).hideCurrentSnackBar();

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor:
//             isError ? Colors.red.shade700 : primaryColor,
//         behavior: SnackBarBehavior.floating,
//         margin: const EdgeInsets.all(16),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//       ),
//     );
//   }

//   // =====================================================
//   // SAFE PROFILE VALUE
//   // =====================================================

//   String getValue(String key) {
//     final value = tutor[key];

//     if (value == null || value.toString().trim().isEmpty) {
//       return 'Not provided';
//     }

//     return value.toString();
//   }

//   // =====================================================
//   // INITIALS
//   // =====================================================

//   String get initials {
//     final name = (tutor['full_name'] ?? 'Tutor').toString().trim();

//     if (name.isEmpty) return 'T';

//     final parts = name.split(' ').where((e) => e.isNotEmpty).toList();

//     return parts.take(2).map((e) => e[0]).join().toUpperCase();
//   }

//   // =====================================================
//   // BACK BUTTON
//   // =====================================================

//   void _goBack() {
//     if (Navigator.canPop(context)) {
//       Navigator.pop(context);
//     } else {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (_) => TutorHome(),
//         ),
//       );
//     }
//   }

//   // =====================================================
//   // OPEN EDIT PROFILE DIALOG
//   // =====================================================

//   void openEditProfile() {
//     final nameController = TextEditingController(
//       text: tutor['full_name']?.toString() ?? '',
//     );

//     final phoneController = TextEditingController(
//       text: tutor['phone']?.toString() ?? '',
//     );

//     final cnicController = TextEditingController(
//       text: tutor['cnic']?.toString() ?? '',
//     );

//     final qualificationController = TextEditingController(
//       text: tutor['qualification']?.toString() ?? '',
//     );

//     final experienceController = TextEditingController(
//       text: tutor['experience']?.toString() ?? '',
//     );

//     final radiusController = TextEditingController(
//       text: tutor['radius']?.toString() ?? '',
//     );

//     final formKey = GlobalKey<FormState>();

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (dialogContext) {
//         return Dialog(
//           insetPadding: const EdgeInsets.symmetric(
//             horizontal: 16,
//             vertical: 24,
//           ),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(22),
//           ),
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 500),
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.all(22),
//               child: Form(
//                 key: formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisSize: MainAxisSize.min,
//                   children: [

//                     // HEADER

//                     Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: primaryColor.withOpacity(.10),
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: Icon(
//                             Icons.edit_outlined,
//                             color: primaryColor,
//                             size: 25,
//                           ),
//                         ),

//                         const SizedBox(width: 12),

//                         const Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 'Edit Tutor Profile',
//                                 style: TextStyle(
//                                   fontSize: 19,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               SizedBox(height: 4),
//                               Text(
//                                 'Update your account information',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.grey,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),

//                         IconButton(
//                           onPressed: isSaving
//                               ? null
//                               : () => Navigator.pop(dialogContext),
//                           icon: const Icon(Icons.close),
//                         ),
//                       ],
//                     ),

//                     const SizedBox(height: 24),

//                     // PERSONAL INFORMATION

//                     _dialogSectionTitle('PERSONAL INFORMATION'),

//                     const SizedBox(height: 13),

//                     _editField(
//                       controller: nameController,
//                       label: 'Full Name',
//                       icon: Icons.person_outline,
//                       requiredField: true,
//                     ),

//                     const SizedBox(height: 14),

//                     _editField(
//                       controller: phoneController,
//                       label: 'Phone Number',
//                       icon: Icons.phone_outlined,
//                       requiredField: true,
//                       keyboardType: TextInputType.phone,
//                     ),

//                     const SizedBox(height: 14),

//                     _editField(
//                       controller: cnicController,
//                       label: 'CNIC / National ID',
//                       icon: Icons.badge_outlined,
//                       keyboardType: TextInputType.number,
//                     ),

//                     const SizedBox(height: 22),

//                     // PROFESSIONAL INFORMATION

//                     _dialogSectionTitle('PROFESSIONAL INFORMATION'),

//                     const SizedBox(height: 13),

//                     _editField(
//                       controller: qualificationController,
//                       label: 'Qualification',
//                       icon: Icons.school_outlined,
//                       requiredField: true,
//                     ),

//                     const SizedBox(height: 14),

//                     _editField(
//                       controller: experienceController,
//                       label: 'Experience (Years)',
//                       icon: Icons.work_outline,
//                       keyboardType: const TextInputType.numberWithOptions(
//                         decimal: true,
//                       ),
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return null;
//                         }

//                         final number = num.tryParse(value.trim());

//                         if (number == null || number < 0) {
//                           return 'Enter valid experience';
//                         }

//                         return null;
//                       },
//                     ),

//                     const SizedBox(height: 14),

//                     _editField(
//                       controller: radiusController,
//                       label: 'Service Radius (KM)',
//                       icon: Icons.radar_outlined,
//                       keyboardType: const TextInputType.numberWithOptions(
//                         decimal: true,
//                       ),
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return null;
//                         }

//                         final number = num.tryParse(value.trim());

//                         if (number == null || number < 0) {
//                           return 'Enter a valid service radius';
//                         }

//                         return null;
//                       },
//                     ),

//                     const SizedBox(height: 24),

//                     // ACTION BUTTONS

//                     Row(
//                       children: [
//                         Expanded(
//                           child: OutlinedButton(
//                             onPressed: isSaving
//                                 ? null
//                                 : () => Navigator.pop(dialogContext),
//                             style: OutlinedButton.styleFrom(
//                               padding: const EdgeInsets.symmetric(
//                                 vertical: 15,
//                               ),
//                               side: BorderSide(
//                                 color: Colors.grey.shade300,
//                               ),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                             ),
//                             child: const Text(
//                               'Cancel',
//                               style: TextStyle(
//                                 color: Colors.black87,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                         ),

//                         const SizedBox(width: 12),

//                         Expanded(
//                           child: ElevatedButton(
//                             onPressed: isSaving
//                                 ? null
//                                 : () async {
//                                     if (!formKey.currentState!.validate()) {
//                                       return;
//                                     }

//                                     FocusScope.of(dialogContext).unfocus();

//                                     final success = await updateTutorProfile(
//                                       fullName: nameController.text,
//                                       phone: phoneController.text,
//                                       cnic: cnicController.text,
//                                       qualification:
//                                           qualificationController.text,
//                                       experience: experienceController.text,
//                                       radius: radiusController.text,
//                                     );

//                                     if (!mounted || !dialogContext.mounted) {
//                                       return;
//                                     }

//                                     if (success) {
//                                       Navigator.of(dialogContext).pop();

//                                       // Show the message after the dialog closes.
//                                       WidgetsBinding.instance.addPostFrameCallback((_) {
//                                         if (mounted) {
//                                           showMessage(
//                                             'Tutor profile updated successfully!',
//                                           );
//                                         }
//                                       });
//                                     }
//                                   },
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: primaryColor,
//                               foregroundColor: Colors.white,
//                               padding: const EdgeInsets.symmetric(
//                                 vertical: 15,
//                               ),
//                               elevation: 0,
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                             ),
//                             child: isSaving
//                                 ? const SizedBox(
//                                     height: 20,
//                                     width: 20,
//                                     child: CircularProgressIndicator(
//                                       color: Colors.white,
//                                       strokeWidth: 2,
//                                     ),
//                                   )
//                                 : const Text(
//                                     'Save Changes',
//                                     style: TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     ).whenComplete(() {
//       nameController.dispose();
//       phoneController.dispose();
//       cnicController.dispose();
//       qualificationController.dispose();
//       experienceController.dispose();
//       radiusController.dispose();
//     });
//   }

//   // =====================================================
//   // EDIT TEXT FIELD
//   // =====================================================

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
//           color: primaryColor,
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
//             color: primaryColor,
//             width: 1.5,
//           ),
//         ),
//       ),
//       validator: validator ??
//           (value) {
//             if (requiredField &&
//                 (value == null || value.trim().isEmpty)) {
//               return '$label is required';
//             }

//             return null;
//           },
//     );
//   }

//   // =====================================================
//   // DIALOG SECTION TITLE
//   // =====================================================

//   Widget _dialogSectionTitle(String title) {
//     return Text(
//       title,
//       style: TextStyle(
//         fontSize: 11,
//         fontWeight: FontWeight.bold,
//         letterSpacing: 1,
//         color: primaryColor,
//       ),
//     );
//   }

//   // =====================================================
//   // MAIN SECTION TITLE
//   // =====================================================

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

//   // =====================================================
//   // WHITE CARD
//   // =====================================================

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
//             color: Colors.black.withOpacity(.035),
//             blurRadius: 15,
//             offset: const Offset(0, 5),
//           ),
//         ],
//       ),
//       child: child,
//     );
//   }

//   // =====================================================
//   // PROFILE INFORMATION ROW
//   // =====================================================

//   Widget _profileRow({
//     required IconData icon,
//     required Color iconColor,
//     required Color iconBg,
//     required String title,
//     required String value,
//   }) {
//     return Row(
//       children: [
//         Container(
//           height: 44,
//           width: 44,
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

//   // =====================================================
//   // LOADING ERROR VIEW
//   // =====================================================

//   Widget _errorView() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(25),
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
//                 size: 42,
//                 color: Colors.red,
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
//               onPressed: () => fetchTutorProfile(),
//               icon: const Icon(Icons.refresh),
//               label: const Text('Try Again'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: primaryColor,
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

//   // =====================================================
//   // MAIN UI
//   // =====================================================

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
//           onPressed: _goBack,
//           icon: Icon(
//             Icons.arrow_back_ios_new,
//             color: primaryColor,
//             size: 20,
//           ),
//         ),

//         title: const Text(
//           'Tutor Profile',
//           style: TextStyle(
//             color: Color(0xff222222),
//             fontWeight: FontWeight.bold,
//             fontSize: 18,
//           ),
//         ),

//         actions: [
//           IconButton(
//             tooltip: 'Refresh Profile',
//             onPressed: loading
//                 ? null
//                 : () => fetchTutorProfile(),
//             icon: Icon(
//               Icons.refresh,
//               color: primaryColor,
//             ),
//           ),
//           const SizedBox(width: 5),
//         ],
//       ),

//       // BODY

//       body: loading
//           ? Center(
//               child: CircularProgressIndicator(
//                 color: primaryColor,
//               ),
//             )
//           : errorMessage.isNotEmpty && tutor.isEmpty
//               ? _errorView()
//               : RefreshIndicator(
//                   color: primaryColor,
//                   onRefresh: fetchTutorProfile,
//                   child: SingleChildScrollView(
//                     physics: const AlwaysScrollableScrollPhysics(),
//                     padding: const EdgeInsets.fromLTRB(17, 20, 17, 30),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [

//                         // =====================================
//                         // PROFILE HEADER
//                         // =====================================

//                         _card(
//                           child: Column(
//                             children: [
//                               Stack(
//                                 alignment: Alignment.bottomRight,
//                                 children: [
//                                   Container(
//                                     padding: const EdgeInsets.all(5),
//                                     decoration: BoxDecoration(
//                                       shape: BoxShape.circle,
//                                       border: Border.all(
//                                         color: primaryColor.withOpacity(.35),
//                                         width: 2,
//                                       ),
//                                     ),
//                                     child: CircleAvatar(
//                                       radius: 45,
//                                       backgroundColor:
//                                           primaryColor.withOpacity(.12),
//                                       child: Text(
//                                         initials,
//                                         style: TextStyle(
//                                           color: primaryColor,
//                                           fontSize: 30,
//                                           fontWeight: FontWeight.bold,
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
//                                       color: primaryColor,
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
//                                   color: primaryColor.withOpacity(.10),
//                                   borderRadius: BorderRadius.circular(30),
//                                 ),
//                                 child: Text(
//                                   'PROFESSIONAL TUTOR',
//                                   style: TextStyle(
//                                     color: primaryColor,
//                                     fontSize: 11,
//                                     fontWeight: FontWeight.bold,
//                                     letterSpacing: .8,
//                                   ),
//                                 ),
//                               ),

//                               const SizedBox(height: 20),

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
//                                     backgroundColor: primaryColor,
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
//                               _profileRow(
//                                 icon: Icons.email_outlined,
//                                 iconColor: const Color(0xff238A65),
//                                 iconBg: const Color(0xffE6F5EE),
//                                 title: 'Email Address',
//                                 value: getValue('email'),
//                               ),

//                               Divider(
//                                 height: 29,
//                                 color: Colors.grey.shade200,
//                               ),

//                               _profileRow(
//                                 icon: Icons.phone_outlined,
//                                 iconColor: const Color(0xff2385B4),
//                                 iconBg: const Color(0xffE6F2F8),
//                                 title: 'Phone Number',
//                                 value: getValue('phone'),
//                               ),

//                               Divider(
//                                 height: 29,
//                                 color: Colors.grey.shade200,
//                               ),

//                               _profileRow(
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
//                         // PROFESSIONAL INFORMATION
//                         // =====================================

//                         _sectionTitle(
//                           'PROFESSIONAL INFORMATION',
//                           'Your teaching qualifications and experience',
//                         ),

//                         const SizedBox(height: 13),

//                         _card(
//                           child: Column(
//                             children: [
//                               _profileRow(
//                                 icon: Icons.school_outlined,
//                                 iconColor: const Color(0xff6855CC),
//                                 iconBg: const Color(0xffEFEDFC),
//                                 title: 'Qualification',
//                                 value: getValue('qualification'),
//                               ),

//                               Divider(
//                                 height: 29,
//                                 color: Colors.grey.shade200,
//                               ),

//                               _profileRow(
//                                 icon: Icons.work_outline,
//                                 iconColor: const Color(0xff238A65),
//                                 iconBg: const Color(0xffE6F5EE),
//                                 title: 'Teaching Experience',
//                                 value: getValue('experience') == 'Not provided'
//                                     ? 'Not provided'
//                                     : '${getValue('experience')} Years',
//                               ),

//                               Divider(
//                                 height: 29,
//                                 color: Colors.grey.shade200,
//                               ),

//                               _profileRow(
//                                 icon: Icons.radar_outlined,
//                                 iconColor: const Color(0xff2385B4),
//                                 iconBg: const Color(0xffE6F2F8),
//                                 title: 'Service Radius',
//                                 value: getValue('radius') == 'Not provided'
//                                     ? 'Not provided'
//                                     : '${getValue('radius')} KM',
//                               ),
//                             ],
//                           ),
//                         ),

//                         const SizedBox(height: 25),

//                         // FOOTER

//                         Center(
//                           child: Text(
//                             'House of Tutor • Tutor Account',
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