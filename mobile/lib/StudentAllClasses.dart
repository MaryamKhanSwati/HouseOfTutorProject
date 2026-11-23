import 'package:flutter/material.dart';
import 'package:house_of_tutor/StudentHome.dart';
import 'package:house_of_tutor/StudentAddCourses.dart';
import 'package:house_of_tutor/StudentCourses.dart';
import 'package:house_of_tutor/StudentDrawer.dart';
import 'package:house_of_tutor/services/api_client.dart';

class StudentAllClasses extends StatefulWidget {
  const StudentAllClasses({super.key});

  @override
  State<StudentAllClasses> createState() => _StudentAllClassesState();
}

class _StudentAllClassesState extends State<StudentAllClasses> {
  static const Color primaryColor = Color(0xff009688);

  static const String logoPath = 'assets/images/logo.png';

  bool isLoading = true;

  List<dynamic> classesList = [];

  String errorMessage = '';

  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  int selectedIndex = 3;

  @override
  void initState() {
    super.initState();
    fetchStudentClasses();
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  void onTapBottom(int index) {
    if (index == selectedIndex) return;

    Widget? screen;

    switch (index) {
      case 0:
        screen = const StudentHome();
        break;

      case 1:
        screen = const StudentAddCourses();
        break;

      case 2:
        screen = const StudentCourses();
        break;

      case 3:
        return;
    }

    if (screen == null) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen!),
    );
  }

  // ============================================================
  // FETCH STUDENT CLASSES
  //
  // GET /api/Student/all-classes
  //
  // Backend response:
  //
  // {
  //   "success": true,
  //   "message": "Student classes fetched successfully",
  //   "data": [
  //     {
  //       "request_id": 1,
  //       "tutor_id": 2,
  //       "tutor_name": "Tutor Name",
  //       "course_id": 5,
  //       "course_name": "Programming",
  //       "class_date": "2026-11-15T00:00:00",
  //       "day": "Sunday",
  //       "time": "10:00-11:00 am",
  //       "request_type": "Normal",
  //       "status": "Accepted",
  //       "request_date": "2026-11-10T00:00:00"
  //     }
  //   ]
  // }
  // ============================================================

  Future<void> fetchStudentClasses() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await ApiClient.get(
        '/api/Student/all-classes',
      );

      debugPrint('All Classes Status: ${response.statusCode}');
      debugPrint('All Classes Body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final dynamic decoded =
            await ApiClient.decodeJson(response);

        if (!mounted) return;

        List<dynamic> items = [];

        if (decoded is Map) {
          if (decoded['success'] == true &&
              decoded['data'] is List) {
            items = decoded['data'];
          } else if (decoded['data'] is List) {
            items = decoded['data'];
          } else {
            errorMessage = decoded['message']?.toString() ??
                'Unable to load student classes.';
          }
        } else if (decoded is List) {
          items = decoded;
        }

        setState(() {
          classesList = items;
          isLoading = false;
        });
      } else {
        final message =
            ApiClient.messageFromBody(response.body);

        setState(() {
          classesList = [];

          errorMessage = message ??
              'Failed to load classes. Status: ${response.statusCode}';

          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('All Classes Error: $e');

      if (!mounted) return;

      setState(() {
        classesList = [];
        errorMessage = 'An error occurred: $e';
        isLoading = false;
      });
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _text(dynamic value, String fallback) {
    if (value == null) return fallback;

    final String result = value.toString().trim();

    if (result.isEmpty || result.toLowerCase() == 'null') {
      return fallback;
    }

    return result;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    if (value is num) return value.toInt();

    return int.tryParse(value.toString().trim());
  }

  String _formatDate(dynamic value) {
    final String date = _text(value, '');

    if (date.isEmpty) return 'Not set';

    try {
      final DateTime parsed = DateTime.parse(date);

      return '${parsed.day.toString().padLeft(2, '0')}-'
          '${parsed.month.toString().padLeft(2, '0')}-'
          '${parsed.year}';
    } catch (_) {
      return date.contains('T')
          ? date.split('T').first
          : date;
    }
  }

  String _formatStatus(dynamic value) {
    final String status = _text(value, 'Accepted');

    return status.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (match) => ' ',
    ).toUpperCase();
  }

  String _formatRequestType(dynamic value) {
    final String type = _text(value, 'Normal');

    return type.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (match) => ' ',
    );
  }

  int? _weekdayFromName(String name) {
    final String day = name.trim().toLowerCase();

    if (day.length < 3) return null;

    const Map<String, int> days = {
      'mon': DateTime.monday,
      'tue': DateTime.tuesday,
      'wed': DateTime.wednesday,
      'thu': DateTime.thursday,
      'fri': DateTime.friday,
      'sat': DateTime.saturday,
      'sun': DateTime.sunday,
    };

    return days[day.substring(0, 3)];
  }

  // ============================================================
  // LOGO
  // ============================================================

  Widget buildLogo() {
    return Image.asset(
      logoPath,
      height: 32,
      width: 32,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.school,
            color: primaryColor,
            size: 20,
          ),
        );
      },
    );
  }

  // ============================================================
  // PICK DATE FOR SLOT
  // ============================================================

  Future<DateTime?> _pickDateForSlot(
    BuildContext pickerContext,
    String slotDay,
  ) {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime lastDate =
        today.add(const Duration(days: 90));

    final int? weekday = _weekdayFromName(slotDay);

    DateTime initialDate = today;

    if (weekday != null) {
      for (int i = 0; i <= 7; i++) {
        final DateTime date =
            today.add(Duration(days: i));

        if (date.weekday == weekday) {
          initialDate = date;
          break;
        }
      }
    }

    return showDatePicker(
      context: pickerContext,
      initialDate: initialDate,
      firstDate: today,
      lastDate: lastDate,
      helpText: weekday == null
          ? 'Select date'
          : 'Select a $slotDay',
      selectableDayPredicate: (DateTime day) {
        if (weekday == null) return true;

        return day.weekday == weekday;
      },
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  // ============================================================
  // AVAILABLE SLOTS
  //
  // GET /api/Student/available-slots/{requestId}
  //
  // NOTE:
  // This endpoint is retained from your existing frontend.
  // ============================================================

  Future<void> showActionBottomSheet(
    int requestId,
    String actionType,
  ) async {
    try {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading available slots...'),
          duration: Duration(seconds: 1),
        ),
      );

      final response = await ApiClient.get(
        '/api/Student/available-slots/$requestId',
      );

      debugPrint(
        'Available Slots Status: ${response.statusCode}',
      );

      debugPrint(
        'Available Slots Body: ${response.body}',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic decoded =
            await ApiClient.decodeJson(response);

        List<dynamic> slots = [];

        if (decoded is List) {
          slots = decoded;
        } else if (decoded is Map &&
            decoded['data'] is List) {
          slots = decoded['data'];
        }

        if (!mounted) return;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          builder: (sheetContext) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            actionType == 'Reschedule'
                                ? 'Re-Schedule Class'
                                : 'Pre-Schedule Class',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                          },
                        ),
                      ],
                    ),

                    const Text(
                      'Choose an available time slot from your tutor.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 15),

                    SizedBox(
                      height: 300,
                      child: slots.isEmpty
                          ? const Center(
                              child: Text(
                                'No available slots found.',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: slots.length,
                              itemBuilder: (context, index) {
                                final dynamic slot = slots[index];

                                if (slot is! Map) {
                                  return const SizedBox.shrink();
                                }

                                final String slotDay =
                                    _text(slot['day'], '');

                                final String slotTime =
                                    _text(slot['time'], '');

                                return Container(
                                  margin: const EdgeInsets.only(
                                    bottom: 10,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding:
                                            const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.calendar_today,
                                          color: primaryColor,
                                          size: 18,
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              slotDay,
                                              style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              slotTime,
                                              style: TextStyle(
                                                color: Colors
                                                    .grey.shade600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      ElevatedButton(
                                        style:
                                            ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.teal.shade50,
                                          foregroundColor:
                                              primaryColor,
                                          elevation: 0,
                                          shape:
                                              RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: slotDay.isEmpty ||
                                                slotTime.isEmpty
                                            ? null
                                            : () async {
                                                final DateTime?
                                                    pickedDate =
                                                    await _pickDateForSlot(
                                                  sheetContext,
                                                  slotDay,
                                                );

                                                if (pickedDate != null &&
                                                    sheetContext.mounted) {
                                                  Navigator.pop(
                                                    sheetContext,
                                                  );

                                                  submitScheduleRequest(
                                                    requestId,
                                                    slotDay,
                                                    slotTime,
                                                    pickedDate,
                                                    actionType,
                                                  );
                                                }
                                              },
                                        child: const Text(
                                          'Select >',
                                          style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        final String message =
            ApiClient.messageFromBody(response.body) ??
                'Failed to fetch available slots.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading available slots: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // SUBMIT RESCHEDULE / PRESCHEDULE
  //
  // These two existing endpoints are retained.
  // ============================================================

  Future<void> submitScheduleRequest(
    int parentRequestId,
    String day,
    String time,
    DateTime newDate,
    String actionType,
  ) async {
    try {
      final String endpoint =
          actionType == 'Reschedule'
              ? '/api/Student/create-reschedule'
              : '/api/Student/create-preschedule';

      final response = await ApiClient.post(
        endpoint,
        {
          'parentRequestId': parentRequestId,
          'day': day,
          'time': time,
          'newClassDate': newDate.toIso8601String(),
        },
      );

      debugPrint(
        '$actionType Status: ${response.statusCode}',
      );

      debugPrint(
        '$actionType Body: ${response.body}',
      );

      final dynamic resData =
          await ApiClient.decodeJson(response);

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final String message =
            resData is Map
                ? _text(
                    resData['message'],
                    'Request sent successfully.',
                  )
                : 'Request sent successfully.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: primaryColor,
          ),
        );

        fetchStudentClasses();
      } else {
        final String message =
            resData is Map
                ? _text(
                    resData['message'],
                    'Failed to submit request.',
                  )
                : resData.toString();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // REQUEST / CLASS CARD
  // ============================================================

  Widget _buildRequestCard(dynamic cls) {
    if (cls is! Map) {
      return const SizedBox.shrink();
    }

    final int? requestId =
        _toInt(cls['request_id']);

    final String courseName =
        _text(cls['course_name'], 'Course');

    final String tutorName =
        _text(cls['tutor_name'], 'Tutor');

    final String classDate =
        _formatDate(cls['class_date']);

    final String day =
        _text(cls['day'], '');

    final String time =
        _text(cls['time'], 'Not set');

    final String status =
        _formatStatus(cls['status']);

    final String requestType =
        _formatRequestType(cls['request_type']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ====================================================
          // COURSE INFORMATION
          // ====================================================

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.school,
                  color: primaryColor,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courseName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      '$requestType Class',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              height: 1,
              color: Colors.black12,
            ),
          ),

          // ====================================================
          // TUTOR
          // ====================================================

          _buildInfoRow(
            icon: Icons.person_outline,
            title: 'Tutor',
            value: tutorName,
          ),

          const SizedBox(height: 8),

          // ====================================================
          // CLASS DATE
          // ====================================================

          _buildInfoRow(
            icon: Icons.calendar_today_outlined,
            title: 'Class Date',
            value: day.isEmpty
                ? classDate
                : '$classDate ($day)',
          ),

          const SizedBox(height: 8),

          // ====================================================
          // CLASS TIME
          // ====================================================

          _buildInfoRow(
            icon: Icons.access_time_outlined,
            title: 'Time',
            value: time,
          ),

          const SizedBox(height: 16),

          // ====================================================
          // RESCHEDULE / PRESCHEDULE BUTTONS
          // ====================================================

          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.edit_calendar,
                  label: 'Re-Schedule',
                  onPressed: requestId == null
                      ? null
                      : () {
                          showActionBottomSheet(
                            requestId,
                            'Reschedule',
                          );
                        },
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildActionButton(
                  icon: Icons.update,
                  label: 'Pre-Schedule',
                  onPressed: requestId == null
                      ? null
                      : () {
                          showActionBottomSheet(
                            requestId,
                            'Preschedule',
                          );
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFORMATION ROW
  // ============================================================

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: Colors.grey,
        ),

        const SizedBox(width: 8),

        Text(
          '$title: ',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),

        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACTION BUTTON
  // ============================================================

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: Colors.teal.shade100,
        ),
        backgroundColor:
            Colors.teal.shade50.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 5,
        ),
      ),
      icon: Icon(
        icon,
        size: 16,
        color: primaryColor,
      ),
      label: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      onPressed: onPressed,
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryColor,
        ),
      );
    }

    if (errorMessage.isNotEmpty &&
        classesList.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),

          const Icon(
            Icons.error_outline,
            size: 45,
            color: Colors.grey,
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 15),

          Center(
            child: ElevatedButton.icon(
              onPressed: fetchStudentClasses,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (classesList.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 110),

          Icon(
            Icons.calendar_month_outlined,
            size: 55,
            color: Colors.grey,
          ),

          SizedBox(height: 15),

          Center(
            child: Text(
              'No classes found right now.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: 8),

          Center(
            child: Text(
              'Your accepted classes will appear here.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: classesList.length,
      itemBuilder: (context, index) {
        return _buildRequestCard(
          classesList[index],
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,

      backgroundColor: Colors.grey.shade50,

      drawer: const StudentDrawer(),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.menu,
            color: Colors.black87,
          ),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),

        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildLogo(),

            const SizedBox(width: 8),

            const Text(
              'House of Tutor',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),

        centerTitle: true,
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Classes',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              'Manage and view your upcoming tutoring sessions',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: RefreshIndicator(
                color: primaryColor,
                onRefresh: fetchStudentClasses,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: onTapBottom,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Schedule',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.add_box),
            label: 'Add Courses',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.request_page),
            label: 'Request',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.class_),
            label: 'Classes',
          ),
        ],
      ),
    );
  }
}