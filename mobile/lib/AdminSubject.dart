
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_of_tutor/AdminApprovedTutor.dart';
import 'package:house_of_tutor/AdminDrawer.dart';
import 'package:house_of_tutor/AdminHome.dart';
import 'package:house_of_tutor/AdminStudent.dart';
import 'package:house_of_tutor/services/api_client.dart';

// ================================================================
// COLORS
// ================================================================

class SubjectColors {
  static const Color primary = Color(0xff168F83);
  static const Color primaryDark = Color(0xff10776D);
  static const Color background = Color(0xffF5F7FA);
  static const Color text = Color(0xff202938);
  static const Color secondaryText = Color(0xff7B8494);
  static const Color border = Color(0xffE8ECF1);
  static const Color greenLight = Color(0xffE8F7F1);
  static const Color blueLight = Color(0xffEEF2FF);
  static const Color purpleLight = Color(0xffF3EEFF);
  static const Color orangeLight = Color(0xffFFF5E8);
  static const Color red = Color(0xffE04444);
  static const Color blue = Color(0xff5265CE);
  static const Color purple = Color(0xff8456C8);
  static const Color orange = Color(0xffD98924);
}

// ================================================================
// COURSE CODE MODEL
// ================================================================

class CourseCode {
  final int courseCodeId;
  final String institute;
  final String courseCode;
  final String program;
  final String description;

  const CourseCode({
    required this.courseCodeId,
    required this.institute,
    required this.courseCode,
    required this.program,
    required this.description,
  });

  factory CourseCode.fromJson(Map<String, dynamic> json) {
    return CourseCode(
      courseCodeId: _intValue(
        json['courseCodeId'] ?? json['CourseCodeId'],
      ),
      institute: _stringValue(
        json['institute'] ?? json['Institute'],
      ),
      courseCode: _stringValue(
        json['courseCode'] ?? json['CourseCode'],
      ),
      program: _stringValue(
        json['program'] ?? json['Program'],
      ),
      description: _stringValue(
        json['description'] ?? json['Description'],
      ),
    );
  }

  static int _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _stringValue(dynamic value) {
    return value?.toString() ?? '';
  }
}

// ================================================================
// SUBJECT MODEL
// ================================================================

class Subject {
  final int id;
  final String courseTitle;
  final double minRate;
  final double maxRate;
  final int standardDurationWeeks;
  final int standardClassesPerWeek;
  final int totalStandardClasses;
  final List<CourseCode> courseCodes;

  const Subject({
    required this.id,
    required this.courseTitle,
    required this.minRate,
    required this.maxRate,
    required this.standardDurationWeeks,
    required this.standardClassesPerWeek,
    required this.totalStandardClasses,
    required this.courseCodes,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    final codesJson =
        json['courseCodes'] ?? json['CourseCodes'];

    final codes = <CourseCode>[];

    if (codesJson is List) {
      for (final item in codesJson) {
        if (item is Map) {
          codes.add(
            CourseCode.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    final duration = _intValue(
      json['standardDurationWeeks'] ??
          json['StandardDurationWeeks'],
    );

    final classes = _intValue(
      json['standardClassesPerWeek'] ??
          json['StandardClassesPerWeek'],
    );

    final total = _intValue(
      json['totalStandardClasses'] ??
          json['TotalStandardClasses'],
    );

    return Subject(
      id: _intValue(
        json['id'] ??
            json['courseId'] ??
            json['course_id'] ??
            json['CourseId'],
      ),
      courseTitle: _stringValue(
        json['courseTitle'] ??
            json['CourseTitle'] ??
            json['course_title'],
      ),
      minRate: _doubleValue(
        json['minRate'] ??
            json['MinRate'] ??
            json['adminSetMinHourlyRate'] ??
            json['AdminSetMinHourlyRate'],
      ),
      maxRate: _doubleValue(
        json['maxRate'] ??
            json['MaxRate'] ??
            json['adminSetMaxHourlyRate'] ??
            json['AdminSetMaxHourlyRate'],
      ),
      standardDurationWeeks: duration,
      standardClassesPerWeek: classes,
      totalStandardClasses:
          total > 0 ? total : duration * classes,
      courseCodes: codes,
    );
  }

  static int _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _stringValue(dynamic value) {
    return value?.toString() ?? '';
  }
}

// ================================================================
// FORM MODES
// ==============================================================

enum SubjectFormMode {
  add,
  editCourseCode,
}

// ================================================================
// ADMIN SUBJECT SCREEN
// ================================================================

class AdminSubject extends StatefulWidget {
  const AdminSubject({super.key});

  @override
  State<AdminSubject> createState() => _AdminSubjectState();
}

class _AdminSubjectState extends State<AdminSubject> {
  int _selectedIndex = 3;

  List<Subject> subjects = [];
  List<Subject> filteredSubjects = [];

  bool isLoading = true;

  final TextEditingController searchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchSubjects();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ==============================================================
  // GET ALL SUBJECTS
  // ==============================================================

  Future<void> fetchSubjects() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final response = await ApiClient.get(
        "/api/Admin/all-subjects",
      );

      debugPrint("SUBJECT STATUS: ${response.statusCode}");
      debugPrint("SUBJECT BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        if (decoded is! List) {
          throw const FormatException(
            "Invalid subjects response.",
          );
        }

        final loaded = decoded.map((item) {
          return Subject.fromJson(
            Map<String, dynamic>.from(item),
          );
        }).toList();

        if (!mounted) return;

        setState(() {
          subjects = loaded;
          _applySearch(searchController.text);
        });
      } else {
        _showMessage(
          _getErrorMessage(
            response.body,
            "Unable to load subjects.",
          ),
          SubjectColors.red,
        );
      }
    } catch (e) {
      debugPrint("FETCH SUBJECT ERROR: $e");

      if (mounted) {
        _showMessage(
          "Something went wrong while loading subjects.",
          SubjectColors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ==============================================================
  // SEARCH
  // ==============================================================

  void _applySearch(String query) {
    final search = query.trim().toLowerCase();

    if (search.isEmpty) {
      filteredSubjects = List.from(subjects);
      return;
    }

    filteredSubjects = subjects.where((subject) {
      final titleMatch =
          subject.courseTitle.toLowerCase().contains(search);

      final codeMatch = subject.courseCodes.any((code) {
        return code.institute.toLowerCase().contains(search) ||
            code.courseCode.toLowerCase().contains(search) ||
            code.program.toLowerCase().contains(search) ||
            code.description.toLowerCase().contains(search);
      });

      return titleMatch || codeMatch;
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() => _applySearch(value));
  }

  // ==============================================================
  // ADD SUBJECT API
  // ==============================================================

  Future<bool> addSubjectApi(
    Map<String, dynamic> requestBody,
  ) async {
    try {
      debugPrint("ADD SUBJECT REQUEST: $requestBody");

      final response = await ApiClient.post(
        "/api/Admin/add-subject",
        requestBody,
      );

      debugPrint("ADD STATUS: ${response.statusCode}");
      debugPrint("ADD BODY: ${response.body}");

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        return true;
      }

      if (mounted) {
        _showMessage(
          _getErrorMessage(
            response.body,
            "Unable to add subject.",
          ),
          SubjectColors.red,
        );
      }

      return false;
    } catch (e) {
      debugPrint("ADD SUBJECT ERROR: $e");

      if (mounted) {
        _showMessage(
          "Error adding subject. Please try again.",
          SubjectColors.red,
        );
      }

      return false;
    }
  }

  // ==============================================================
  // UPDATE SUBJECT API
  // ==============================================================
  // This API updates:
  // 1. Common subject details
  // 2. Selected university course details
  // ==============================================================

  Future<bool> updateSubjectApi({
    required int courseId,
    required Map<String, dynamic> requestBody,
  }) async {
    try {
      debugPrint("UPDATE COURSE ID: $courseId");
      debugPrint("UPDATE REQUEST: $requestBody");

      final response = await ApiClient.put(
        "/api/Admin/update-subject/$courseId",
        requestBody,
      );

      debugPrint("UPDATE STATUS: ${response.statusCode}");
      debugPrint("UPDATE BODY: ${response.body}");

      if (response.statusCode == 200) {
        return true;
      }

      if (mounted) {
        _showMessage(
          _getErrorMessage(
            response.body,
            "Unable to update subject.",
          ),
          SubjectColors.red,
        );
      }

      return false;
    } catch (e) {
      debugPrint("UPDATE SUBJECT ERROR: $e");

      if (mounted) {
        _showMessage(
          "Error updating subject. Please try again.",
          SubjectColors.red,
        );
      }

      return false;
    }
  }

  // ==============================================================
  // ADD SUBJECT
  // ==============================================================

  Future<void> addSubject() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _SubjectFormSheet(
          mode: SubjectFormMode.add,
          onSave: addSubjectApi,
        );
      },
    );

    if (result == true && mounted) {
      await fetchSubjects();

      if (!mounted) return;

      _showMessage(
        "Subject added successfully.",
        SubjectColors.primary,
      );
    }
  }

  // ==============================================================
  // EDIT UNIVERSITY DETAILS
  // ==============================================================

  Future<void> editUniversityDetails(
    Subject subject,
    CourseCode courseCode,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _SubjectFormSheet(
          mode: SubjectFormMode.editCourseCode,
          subject: subject,
          courseCode: courseCode,
          onSave: (requestBody) {
            return updateSubjectApi(
              courseId: subject.id,
              requestBody: requestBody,
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      await fetchSubjects();

      if (!mounted) return;

      _showMessage(
        "Subject and university details updated successfully.",
        SubjectColors.primary,
      );
    }
  }

  // ==============================================================
  // ERROR MESSAGE
  // ==============================================================

  String _getErrorMessage(
    String body,
    String defaultMessage,
  ) {
    if (body.trim().isEmpty) return defaultMessage;

    try {
      final data = jsonDecode(body);

      if (data is Map) {
        for (final key in [
          'message',
          'error',
          'title',
          'detail',
        ]) {
          final value = data[key];

          if (value != null &&
              value.toString().trim().isNotEmpty) {
            return value.toString();
          }
        }

        if (data['errors'] is Map) {
          final errors = data['errors'] as Map;
          final messages = <String>[];

          for (final value in errors.values) {
            if (value is List) {
              messages.addAll(
                value.map((e) => e.toString()),
              );
            }
          }

          if (messages.isNotEmpty) {
            return messages.join("\n");
          }
        }
      }
    } catch (_) {
      return defaultMessage;
    }

    return defaultMessage;
  }

  // ==============================================================
  // SNACKBAR
  // ==============================================================

  void _showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(14),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ==============================================================
  // INITIALS
  // ==============================================================

  String getInitials(String title) {
    final parts = title.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty || parts.first.isEmpty) return "?";

    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }

    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  // ==============================================================
  // NAVIGATION
  // ==============================================================

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminHome(),
        ),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminApprovedTutor(),
        ),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminStudent(),
        ),
      );
    }
  }

  // ==============================================================
  // INFORMATION PILL
  // ==============================================================

  Widget _infoPill({
    required IconData icon,
    required String title,
    required String value,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // EDIT UNIVERSITY DETAILS BUTTON
  // ==============================================================

  Widget _editUniversityButton({
    required Subject subject,
    required CourseCode code,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 43,
      child: OutlinedButton.icon(
        onPressed: () {
          editUniversityDetails(subject, code);
        },
        icon: const Icon(
          Icons.edit_outlined,
          size: 17,
        ),
        label: const Text(
          "Edit University Details",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: SubjectColors.primary,
          backgroundColor: SubjectColors.greenLight,
          side: const BorderSide(
            color: Color(0xffCDE9DF),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // COURSE CODE CARD
  // ==============================================================

  Widget _courseCodeCard(
    Subject subject,
    CourseCode code,
    int index,
  ) {
    final colors = [
      SubjectColors.primary,
      SubjectColors.blue,
      SubjectColors.purple,
    ];

    final backgrounds = [
      SubjectColors.greenLight,
      SubjectColors.blueLight,
      SubjectColors.purpleLight,
    ];

    final foreground = colors[index % colors.length];
    final background = backgrounds[index % backgrounds.length];

    return Container(
      margin: const EdgeInsets.only(top: 11),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xffFAFBFD),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: SubjectColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  code.courseCode.isEmpty
                      ? "No Code"
                      : code.courseCode,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  code.institute.isEmpty
                      ? "Institute not specified"
                      : code.institute,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SubjectColors.text,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (code.program.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.school_outlined,
                  size: 15,
                  color: SubjectColors.secondaryText,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    code.program,
                    style: const TextStyle(
                      fontSize: 11,
                      color: SubjectColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (code.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              code.description,
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                color: SubjectColors.secondaryText,
              ),
            ),
          ],

          const SizedBox(height: 13),

          // ONLY EDIT BUTTON
          _editUniversityButton(
            subject: subject,
            code: code,
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // SUBJECT CARD
  // ==============================================================

  Widget _subjectCard(Subject subject) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SubjectColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff182A3D).withOpacity(0.035),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SUBJECT HEADER
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SubjectColors.greenLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  getInitials(subject.courseTitle),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: SubjectColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.courseTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: SubjectColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Subject ID: ${subject.id}",
                      style: const TextStyle(
                        fontSize: 10,
                        color: SubjectColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // HOURLY RATES
          Row(
            children: [
              Expanded(
                child: _infoPill(
                  icon: Icons.trending_down,
                  title: "MINIMUM RATE",
                  value: "Rs. ${subject.minRate.toStringAsFixed(0)}",
                  background: SubjectColors.greenLight,
                  foreground: SubjectColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoPill(
                  icon: Icons.trending_up,
                  title: "MAXIMUM RATE",
                  value: "Rs. ${subject.maxRate.toStringAsFixed(0)}",
                  background: SubjectColors.blueLight,
                  foreground: SubjectColors.blue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 11),

          // DURATION AND CLASSES
          Row(
            children: [
              Expanded(
                child: _infoPill(
                  icon: Icons.calendar_month_outlined,
                  title: "DURATION",
                  value: "${subject.standardDurationWeeks} Weeks",
                  background: SubjectColors.purpleLight,
                  foreground: SubjectColors.purple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoPill(
                  icon: Icons.event_available_outlined,
                  title: "CLASSES / WEEK",
                  value: "${subject.standardClassesPerWeek}",
                  background: SubjectColors.orangeLight,
                  foreground: SubjectColors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // TOTAL CLASSES
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xffF1F8F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xffDDEFEA),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: SubjectColors.primary,
                  size: 19,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    "Total Standard Classes",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SubjectColors.text,
                    ),
                  ),
                ),
                Text(
                  "${subject.totalStandardClasses} Classes",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: SubjectColors.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 19),

          // UNIVERSITY DETAILS HEADER
          Row(
            children: [
              const Icon(
                Icons.account_balance_outlined,
                color: SubjectColors.primary,
                size: 19,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "University Course Details",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: SubjectColors.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: SubjectColors.greenLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${subject.courseCodes.length} Codes",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: SubjectColors.primary,
                  ),
                ),
              ),
            ],
          ),

          // UNIVERSITY COURSE CODE LIST
          if (subject.courseCodes.isNotEmpty)
            ...List.generate(
              subject.courseCodes.length,
              (index) => _courseCodeCard(
                subject,
                subject.courseCodes[index],
                index,
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 17,
                    color: SubjectColors.secondaryText,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "No university course details available.",
                      style: TextStyle(
                        fontSize: 11,
                        color: SubjectColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==============================================================
  // SEARCH BAR
  // ==============================================================

  Widget _searchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: SubjectColors.border),
      ),
      child: TextField(
        controller: searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(
          fontSize: 13,
          color: SubjectColors.text,
        ),
        decoration: InputDecoration(
          hintText: "Search subject, institute or course code...",
          hintStyle: const TextStyle(
            fontSize: 11,
            color: SubjectColors.secondaryText,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: SubjectColors.primary,
          ),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    searchController.clear();
                    _onSearchChanged("");
                  },
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // SUMMARY CARD
  // ==============================================================

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SubjectColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SubjectColors.greenLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.library_books_rounded,
              color: SubjectColors.primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${subjects.length}",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: SubjectColors.text,
                  ),
                ),
                const Text(
                  "Total Subjects",
                  style: TextStyle(
                    fontSize: 11,
                    color: SubjectColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: addSubject,
            style: ElevatedButton.styleFrom(
              backgroundColor: SubjectColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            icon: const Icon(Icons.add, size: 17),
            label: const Text(
              "Add Subject",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // EMPTY STATE
  // ==============================================================

  Widget _emptyState() {
    final searching = searchController.text.trim().isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 75),
        Icon(
          searching
              ? Icons.search_off_rounded
              : Icons.menu_book_outlined,
          size: 65,
          color: const Color(0xffC5CDD7),
        ),
        const SizedBox(height: 15),
        Center(
          child: Text(
            searching
                ? "No matching subjects found"
                : "No subjects available",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: SubjectColors.text,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Center(
          child: Text(
            searching
                ? "Try another subject name or course code."
                : "Start by adding your first subject.",
            style: const TextStyle(
              fontSize: 12,
              color: SubjectColors.secondaryText,
            ),
          ),
        ),
        if (!searching) ...[
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: addSubject,
              style: ElevatedButton.styleFrom(
                backgroundColor: SubjectColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              label: const Text("Add Subject"),
            ),
          ),
        ],
      ],
    );
  }

  // ==============================================================
  // MAIN SCREEN
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SubjectColors.background,
      drawer: const AdminDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // TOP BAR
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      return IconButton(
                        onPressed: () {
                          Scaffold.of(context).openDrawer();
                        },
                        icon: const Icon(
                          Icons.menu_rounded,
                          color: SubjectColors.primary,
                          size: 26,
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  Image.asset(
                    "assets/images/logo.png",
                    height: 43,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return const Icon(
                        Icons.school_rounded,
                        size: 35,
                        color: SubjectColors.primary,
                      );
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: isLoading ? null : fetchSubjects,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: SubjectColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            // PAGE HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Subject Management",
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: SubjectColors.text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Manage courses, university codes, duration and tutor hourly rates.",
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: SubjectColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 17),
                  _summaryCard(),
                  const SizedBox(height: 13),
                  _searchBar(),
                  const SizedBox(height: 17),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "All Subjects",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: SubjectColors.text,
                          ),
                        ),
                      ),
                      Text(
                        "${filteredSubjects.length} found",
                        style: const TextStyle(
                          fontSize: 11,
                          color: SubjectColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                ],
              ),
            ),

            // SUBJECT LIST
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: SubjectColors.primary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchSubjects,
                      color: SubjectColors.primary,
                      child: filteredSubjects.isEmpty
                          ? _emptyState()
                          : ListView.builder(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                16, 0, 16, 22,
                              ),
                              itemCount: filteredSubjects.length,
                              itemBuilder: (context, index) {
                                return _subjectCard(
                                  filteredSubjects[index],
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),

      // BOTTOM NAVIGATION
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 10,
        selectedItemColor: SubjectColors.primary,
        unselectedItemColor: SubjectColors.secondaryText,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people_rounded),
            label: "Tutors",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            activeIcon: Icon(Icons.school_rounded),
            label: "Student",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book_rounded),
            label: "Subject",
          ),
        ],
      ),
    );
  }
}

// ================================================================
// ADD / EDIT UNIVERSITY DETAILS FORM
// ================================================================

class _SubjectFormSheet extends StatefulWidget {
  final SubjectFormMode mode;
  final Subject? subject;
  final CourseCode? courseCode;

  final Future<bool> Function(
    Map<String, dynamic> requestBody,
  ) onSave;

  const _SubjectFormSheet({
    required this.mode,
    required this.onSave,
    this.subject,
    this.courseCode,
  });

  @override
  State<_SubjectFormSheet> createState() =>
      _SubjectFormSheetState();
}

class _SubjectFormSheetState extends State<_SubjectFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final courseController = TextEditingController();
  final instituteController = TextEditingController();
  final codeController = TextEditingController();
  final programController = TextEditingController();
  final descriptionController = TextEditingController();

  final minController = TextEditingController();
  final maxController = TextEditingController();

  final durationController = TextEditingController();
  final classesController = TextEditingController();

  bool saving = false;

  bool get isAdd => widget.mode == SubjectFormMode.add;

  @override
  void initState() {
    super.initState();

    final subject = widget.subject;
    final code = widget.courseCode;

    courseController.text = subject?.courseTitle ?? '';

    instituteController.text = code?.institute ?? '';
    codeController.text = code?.courseCode ?? '';
    programController.text = code?.program ?? '';
    descriptionController.text = code?.description ?? '';

    minController.text =
        subject != null && subject.minRate > 0
            ? subject.minRate.toStringAsFixed(0)
            : '';

    maxController.text =
        subject != null && subject.maxRate > 0
            ? subject.maxRate.toStringAsFixed(0)
            : '';

    durationController.text =
        (subject?.standardDurationWeeks ?? 16).toString();

    classesController.text =
        (subject?.standardClassesPerWeek ?? 1).toString();
  }

  @override
  void dispose() {
    courseController.dispose();
    instituteController.dispose();
    codeController.dispose();
    programController.dispose();
    descriptionController.dispose();
    minController.dispose();
    maxController.dispose();
    durationController.dispose();
    classesController.dispose();
    super.dispose();
  }

  // ==============================================================
  // FIELD DECORATION
  // ==============================================================

  InputDecoration _decoration(
    String hint,
    IconData icon,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 12,
        color: Color(0xffA0A8B5),
      ),
      prefixIcon: Icon(
        icon,
        size: 19,
        color: SubjectColors.secondaryText,
      ),
      filled: true,
      fillColor: const Color(0xffF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: SubjectColors.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: SubjectColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: SubjectColors.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: SubjectColors.red,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: SubjectColors.red,
        ),
      ),
    );
  }

  // ==============================================================
  // FIELD LABEL
  // ==============================================================

  Widget _fieldLabel(String label, bool requiredField) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: SubjectColors.text,
        ),
        children: [
          if (requiredField)
            const TextSpan(
              text: " *",
              style: TextStyle(
                color: SubjectColors.red,
              ),
            ),
        ],
      ),
    );
  }

  // ==============================================================
  // TEXT FIELD
  // ==============================================================

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool requiredField = true,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, requiredField),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          decoration: _decoration(hint, icon),
          validator: (value) {
            if (requiredField &&
                (value == null || value.trim().isEmpty)) {
              return "$label is required.";
            }

            return null;
          },
        ),
      ],
    );
  }

  // ==============================================================
  // NUMBER FIELD
  // ==============================================================

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool decimal = false,
    bool requiredField = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, requiredField),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(
            decimal: decimal,
          ),
          inputFormatters: decimal
              ? [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,2}$'),
                  ),
                ]
              : [
                  FilteringTextInputFormatter.digitsOnly,
                ],
          decoration: _decoration(hint, icon),
          validator: (value) {
            final text = value?.trim() ?? '';

            if (text.isEmpty) {
              return requiredField ? "Required." : null;
            }

            final number = decimal
                ? double.tryParse(text)
                : int.tryParse(text);

            if (number == null) {
              return "Enter a valid number.";
            }

            if (number <= 0) {
              return "Value must be greater than zero.";
            }

            return null;
          },
        ),
      ],
    );
  }

  // ==============================================================
  // SECTION HEADING
  // ==============================================================

  Widget _sectionHeading(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SubjectColors.greenLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: SubjectColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: SubjectColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: SubjectColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // INFORMATION BOX
  // ==============================================================

  Widget _infoBox({
    required String message,
    IconData icon = Icons.info_outline,
    Color background = SubjectColors.blueLight,
    Color foreground = SubjectColors.blue,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // TOTAL CLASSES PREVIEW
  // ==============================================================

  Widget _totalClassesPreview() {
    final duration =
        int.tryParse(durationController.text) ?? 0;

    final classes =
        int.tryParse(classesController.text) ?? 0;

    final total = duration * classes;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SubjectColors.greenLight,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xffD2EDE3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.calculate_outlined,
              color: SubjectColors.primary,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total Standard Classes",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SubjectColors.text,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "Duration × Classes per week",
                  style: TextStyle(
                    fontSize: 10,
                    color: SubjectColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "$total",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: SubjectColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // VALIDATE AND SAVE
  // ==============================================================

  Future<void> _save() async {
    if (saving) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final duration = int.tryParse(
      durationController.text.trim(),
    );

    final classes = int.tryParse(
      classesController.text.trim(),
    );

    if (duration == null ||
        duration <= 0 ||
        classes == null ||
        classes <= 0) {
      return;
    }

    final minText = minController.text.trim();
    final maxText = maxController.text.trim();

    final minRate = double.tryParse(minText);
    final maxRate = double.tryParse(maxText);

    if (minRate == null || maxRate == null) {
      _showMessage(
        "Enter both minimum and maximum rates.",
      );
      return;
    }

    if (minRate <= 0 || maxRate <= 0) {
      _showMessage("Rates must be greater than zero.");
      return;
    }

    if (minRate > maxRate) {
      _showMessage(
        "Minimum rate cannot be greater than maximum rate.",
      );
      return;
    }

    if (instituteController.text.trim().isEmpty ||
        codeController.text.trim().isEmpty) {
      _showMessage(
        "Institute and course code are required.",
      );
      return;
    }

    // COMMON SUBJECT DETAILS + UNIVERSITY DETAILS
    final Map<String, dynamic> requestBody = {
      "courseTitle": courseController.text.trim(),
      "minRate": minRate,
      "maxRate": maxRate,
      "standardDurationWeeks": duration,
      "standardClassesPerWeek": classes,

      "institute": instituteController.text.trim(),
      "courseCode": codeController.text.trim().toUpperCase(),
      "program": programController.text.trim().isEmpty
          ? null
          : programController.text.trim(),
      "description": descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
    };

    // When editing, send the selected university course code ID.
    if (!isAdd) {
      final code = widget.courseCode!;

      if (code.courseCodeId <= 0) {
        _showMessage(
          "Invalid university course code ID.",
        );
        return;
      }

      requestBody["courseCodeId"] = code.courseCodeId;
    }

    debugPrint("FINAL SUBJECT REQUEST: $requestBody");

    setState(() => saving = true);

    final success = await widget.onSave(requestBody);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => saving = false);
    }
  }

  // ==============================================================
  // FORM MESSAGE
  // ==============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: SubjectColors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
        ),
      );
  }

  // ==============================================================
  // BUILD FORM
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    final title = isAdd
        ? "Add New Subject"
        : "Edit Subject & University Details";

    final subtitle = isAdd
        ? "Create a course and university code"
        : "Update subject information and selected university details";

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.93,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20, 18, 16, 16,
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: SubjectColors.greenLight,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      isAdd
                          ? Icons.menu_book_rounded
                          : Icons.edit_note_rounded,
                      color: SubjectColors.primary,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: SubjectColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 10,
                            color: SubjectColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(
                      Icons.close,
                      color: SubjectColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(
              height: 1,
              color: SubjectColors.border,
            ),

            // FORM CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20, 20, 20, 25,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SUBJECT INFORMATION
                      _sectionHeading(
                        "Subject Information",
                        "Update the common course details",
                        Icons.menu_book_outlined,
                      ),

                      _textField(
                        controller: courseController,
                        label: "Course Name",
                        hint: "e.g. Object Oriented Programming",
                        icon: Icons.book_outlined,
                      ),

                      const SizedBox(height: 23),

                      // UNIVERSITY INFORMATION
                      _sectionHeading(
                        "University Course Details",
                        "Update the selected university's course information",
                        Icons.account_balance_outlined,
                      ),

                      _textField(
                        controller: instituteController,
                        label: "Institute / University",
                        hint: "e.g. COMSATS University",
                        icon: Icons.account_balance_outlined,
                      ),

                      const SizedBox(height: 15),

                      _textField(
                        controller: codeController,
                        label: "Course Code",
                        hint: "e.g. CSC201",
                        icon: Icons.numbers_rounded,
                      ),

                      const SizedBox(height: 15),

                      _textField(
                        controller: programController,
                        label: "Program",
                        hint: "e.g. BS Software Engineering",
                        icon: Icons.school_outlined,
                        requiredField: false,
                      ),

                      const SizedBox(height: 15),

                      _textField(
                        controller: descriptionController,
                        label: "Description",
                        hint: "Enter course description",
                        icon: Icons.description_outlined,
                        requiredField: false,
                        maxLines: 3,
                      ),

                      const SizedBox(height: 24),

                      // COURSE PLAN
                      _sectionHeading(
                        "Standard Course Plan",
                        "Update the normal learning schedule",
                        Icons.calendar_month_outlined,
                      ),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _numberField(
                              controller: durationController,
                              label: "Duration (Weeks)",
                              hint: "16",
                              icon: Icons.date_range_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _numberField(
                              controller: classesController,
                              label: "Classes / Week",
                              hint: "1",
                              icon: Icons.event_available_outlined,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 13),

                      AnimatedBuilder(
                        animation: Listenable.merge([
                          durationController,
                          classesController,
                        ]),
                        builder: (context, child) {
                          return _totalClassesPreview();
                        },
                      ),

                      const SizedBox(height: 24),

                      // RATE CONFIGURATION
                      _sectionHeading(
                        "Hourly Rate Configuration",
                        "Update the allowed tutor hourly rates",
                        Icons.payments_outlined,
                      ),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _numberField(
                              controller: minController,
                              label: "Minimum Rate",
                              hint: "500",
                              icon: Icons.trending_down,
                              decimal: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _numberField(
                              controller: maxController,
                              label: "Maximum Rate",
                              hint: "2500",
                              icon: Icons.trending_up,
                              decimal: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      _infoBox(
                        icon: Icons.info_outline,
                        message:
                            "When you save, the subject information and the selected university course details will be sent together to the update API.",
                      ),

                      const SizedBox(height: 12),

                      _infoBox(
                        icon: Icons.lightbulb_outline,
                        background: SubjectColors.greenLight,
                        foreground: SubjectColors.primary,
                        message:
                            "Total classes are calculated automatically: duration in weeks × classes per week.",
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // BOTTOM ACTIONS
            Container(
              padding: const EdgeInsets.fromLTRB(
                20, 12, 20, 16,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: SubjectColors.border,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 49,
                      child: OutlinedButton(
                        onPressed: saving
                            ? null
                            : () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SubjectColors.text,
                          side: const BorderSide(
                            color: SubjectColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 49,
                      child: ElevatedButton.icon(
                        onPressed: saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SubjectColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: saving
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isAdd
                                    ? Icons.add_circle_outline
                                    : Icons.save_outlined,
                                size: 19,
                              ),
                        label: Text(
                          saving
                              ? "Please wait..."
                              : isAdd
                                  ? "Add Subject"
                                  : "Save Changes",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}