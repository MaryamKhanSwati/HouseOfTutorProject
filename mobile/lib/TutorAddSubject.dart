import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:house_of_tutor/TutorDrawer.dart';
import 'package:house_of_tutor/services/api_client.dart';

class TutorAddSubject extends StatefulWidget {
  const TutorAddSubject({super.key});

  @override
  State<TutorAddSubject> createState() => _TutorAddSubjectState();
}

class _TutorAddSubjectState extends State<TutorAddSubject> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryColor = Color(0xFF1E8E7E);
  static const Color backgroundColor = Color(0xFFF4F7F9);
  static const Color textColor = Color(0xFF253238);
  static const Color secondaryTextColor = Color(0xFF78858C);
  static const Color successColor = Color(0xFF239B69);
  static const Color warningColor = Color(0xFFD28A26);
  static const Color errorColor = Color(0xFFD94B4B);

  // ============================================================
  // STATE
  // ============================================================

  bool isLoading = true;

  List<Map<String, dynamic>> myCourses = [];
  List<Map<String, dynamic>> availableCourses = [];

  static const int maxTranscriptSize = 10 * 1024 * 1024;

  static const List<String> allowedTranscriptExtensions = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
  ];

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  dynamic _decodeResponse(dynamic response) {
    if (response.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _toString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = _toString(value).toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'completed';
  }

  dynamic _readRaw(Map item, List<String> keys) {
    for (final key in keys) {
      if (item.containsKey(key) && item[key] != null) {
        return item[key];
      }
    }
    return null;
  }

  String _readAny(Map item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      final result = data['courses'] ??
          data['Courses'] ??
          data['data'] ??
          data['items'];

      if (result is List) return result;
    }

    return [];
  }

  String _formatRate(double rate) {
    return rate.toStringAsFixed(rate % 1 == 0 ? 0 : 2);
  }

  String _formatDate(dynamic value) {
    final raw = _toString(value);
    if (raw.isEmpty) return '';

    final date = DateTime.tryParse(raw);
    if (date == null) return raw;

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _displayValue(String value) {
    return value.isEmpty ? 'Not provided' : value;
  }

  // Snackbar on the main screen (use only when NO dialog is open).
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? errorColor : primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(14),
        ),
      );
  }

  // Dispose controllers AFTER the dialog close animation is finished.
  // Disposing right after showDialog() returns can crash with
  // "TextEditingController used after being disposed".
  void _disposeLater(List<ChangeNotifier> items) {
    Future.delayed(const Duration(milliseconds: 400), () {
      for (final item in items) {
        item.dispose();
      }
    });
  }

  // ============================================================
  // ADMIN RATE RANGE
  // ============================================================

  double _readAdminMinRate(Map item) {
    return _toDouble(
      _readRaw(item, [
            'admin_min_hourly_rate',
            'adminMinHourlyRate',
            'AdminMinHourlyRate',
            'admin_set_min_hourly_rate',
            'adminSetMinHourlyRate',
            'AdminSetMinHourlyRate',
            'min_hourly_rate',
            'minHourlyRate',
            'MinHourlyRate',
          ]) ??
          0,
    );
  }

  double _readAdminMaxRate(Map item) {
    return _toDouble(
      _readRaw(item, [
            'admin_max_hourly_rate',
            'adminMaxHourlyRate',
            'AdminMaxHourlyRate',
            'admin_set_max_hourly_rate',
            'adminSetMaxHourlyRate',
            'AdminSetMaxHourlyRate',
            'max_hourly_rate',
            'maxHourlyRate',
            'MaxHourlyRate',
          ]) ??
          0,
    );
  }

  bool _hasValidRateRange(double minRate, double maxRate) {
    return minRate > 0 && maxRate >= minRate;
  }

  // ============================================================
  // TRANSCRIPT FILE PICKER
  // Errors are sent to onError so the dialog can show them.
  // ============================================================

  Future<File?> _pickTranscript({
    required void Function(String message) onError,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedTranscriptExtensions,
        allowMultiple: false,
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final picked = result.files.first;

      if (picked.path == null) {
        onError('Unable to access selected file.');
        return null;
      }

      if (picked.size > maxTranscriptSize) {
        onError('Transcript must not exceed 10 MB.');
        return null;
      }

      final extension = picked.extension?.toLowerCase() ?? '';

      if (!allowedTranscriptExtensions.contains(extension)) {
        onError('Only PDF, JPG, JPEG and PNG files are allowed.');
        return null;
      }

      final file = File(picked.path!);

      if (!await file.exists()) {
        onError('Selected file does not exist.');
        return null;
      }

      return file;
    } catch (e) {
      debugPrint('TRANSCRIPT PICKER ERROR: $e');
      onError('Unable to select transcript.');
      return null;
    }
  }

  // ============================================================
  // LOAD COURSES
  // ============================================================

  Future<void> loadCourses({bool showLoader = true}) async {
    if (!mounted) return;

    if (showLoader) {
      setState(() => isLoading = true);
    }

    try {
      final responses = await Future.wait([
        ApiClient.get('/api/Tutor/my-courses'),
        ApiClient.get('/api/Tutor/all-courses'),
      ]);

      final myResponse = responses[0];
      final allResponse = responses[1];

      debugPrint('MY COURSES STATUS: ${myResponse.statusCode}');
      debugPrint('MY COURSES BODY: ${myResponse.body}');
      debugPrint('ALL COURSES STATUS: ${allResponse.statusCode}');
      debugPrint('ALL COURSES BODY: ${allResponse.body}');

      if (myResponse.statusCode == 401 ||
          allResponse.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }

      if (myResponse.statusCode != 200) {
        throw Exception(
          ApiClient.messageFromBody(myResponse.body) ??
              'Unable to load your courses.',
        );
      }

      if (allResponse.statusCode != 200) {
        throw Exception(
          ApiClient.messageFromBody(allResponse.body) ??
              'Unable to load available courses.',
        );
      }

      final myData = _decodeResponse(myResponse);
      final allData = _decodeResponse(allResponse);

      final Set<int> addedCourseIds = {};
      final List<Map<String, dynamic>> myList = [];

      // ========================================================
      // MY COURSES
      // ========================================================

      for (final item in _extractList(myData)) {
        if (item is! Map) continue;

        final id = _toInt(
          _readRaw(item, ['course_id', 'courseId', 'CourseId']),
        );

        if (id <= 0) continue;

        final verificationStatus = _readAny(item, [
          'grade_verification_status',
          'gradeVerificationStatus',
          'verification_status',
          'verificationStatus',
          'GradeVerificationStatus',
        ]);

        // Rejected courses can be submitted again.
        if (verificationStatus.toLowerCase() != 'rejected') {
          addedCourseIds.add(id);
        }

        dynamic evidence = _readRaw(item, [
          'transcript_evidence',
          'transcriptEvidence',
        ]);

        if (evidence is List) {
          evidence = evidence.isNotEmpty ? evidence.first : null;
        }

        myList.add({
          'course_id': id,
          'course_name': _readAny(item, [
            'course_name',
            'courseName',
            'CourseName',
          ]),
          'grade': _readAny(item, ['grade', 'Grade']),
          'institute': _readAny(item, [
            'institute',
            'Institute',
            'university',
            'university_name',
            'universityName',
          ]),
          'hourly_rate': _toDouble(
            _readRaw(item, [
                  'hourly_rate',
                  'hourlyRate',
                  'HourlyRate',
                ]) ??
                0,
          ),
          'admin_min_hourly_rate': _readAdminMinRate(item),
          'admin_max_hourly_rate': _readAdminMaxRate(item),
          'previous_teacher': _readAny(item, [
            'previous_teacher',
            'previousTeacher',
            'previous_teacher_name',
            'previousTeacherName',
            'tutor_name',
            'tutorName',
          ]),
          'previous_teacher_institute': _readAny(item, [
            'previous_teacher_institute',
            'previousTeacherInstitute',
            'previous_teacher_university',
            'previousTeacherUniversity',
          ]),
          'study_year': _readAny(item, [
            'study_year',
            'studyYear',
            'StudyYear',
          ]),
          'is_programming_subject': _toBool(
            _readRaw(item, [
                  'is_programming_subject',
                  'isProgrammingSubject',
                  'IsProgrammingSubject',
                ]) ??
                false,
          ),
          'programming_language': _readAny(item, [
            'programming_language',
            'programmingLanguage',
            'ProgrammingLanguage',
          ]),
          'lab_completed': _readRaw(item, [
            'lab_completed',
            'labCompleted',
            'LabCompleted',
          ]),
          'grade_verification_status': verificationStatus,
          'verified_by': _readAny(item, [
            'verified_by',
            'verifiedBy',
            'VerifiedBy',
          ]),
          'verified_date': _readAny(item, [
            'verified_date',
            'verifiedDate',
            'VerifiedDate',
          ]),
          'verification_remarks': _readAny(item, [
            'verification_remarks',
            'verificationRemarks',
            'remarks',
            'Remarks',
          ]),
          'transcript_evidence': evidence,
        });
      }

      // ========================================================
      // AVAILABLE COURSES
      // ========================================================

      final List<Map<String, dynamic>> availableList = [];

      for (final item in _extractList(allData)) {
        if (item is! Map) continue;

        final id = _toInt(
          _readRaw(item, ['course_id', 'courseId', 'CourseId']),
        );

        final name = _readAny(item, [
          'course_name',
          'courseName',
          'course_title',
          'courseTitle',
          'CourseName',
        ]);

        if (id <= 0 || name.isEmpty) continue;
        if (addedCourseIds.contains(id)) continue;

        availableList.add({
          'course_id': id,
          'course_name': name,
          'admin_min_hourly_rate': _readAdminMinRate(item),
          'admin_max_hourly_rate': _readAdminMaxRate(item),
        });
      }

      if (!mounted) return;

      setState(() {
        myCourses = myList;
        availableCourses = availableList;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('LOAD COURSES ERROR: $e');

      if (!mounted) return;

      setState(() => isLoading = false);

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  // ============================================================
  // ADD COURSE API - MULTIPART
  // Returns null on success, or an error message on failure.
  // The dialog shows the error message inside the dialog.
  // ============================================================

  Future<String?> _addCourse({
    required int courseId,
    required String grade,
    required double hourlyRate,
    required String institute,
    required String previousTeacher,
    required String previousTeacherInstitute,
    required int? studyYear,
    required bool isProgrammingSubject,
    required String? programmingLanguage,
    required bool labCompleted,
    required double adminMinRate,
    required double adminMaxRate,
    required File transcriptFile,
  }) async {
    if (!_hasValidRateRange(adminMinRate, adminMaxRate)) {
      return 'Admin hourly rate range is not configured for this course.';
    }

    if (hourlyRate < adminMinRate || hourlyRate > adminMaxRate) {
      return 'Hourly rate must be between Rs. ${_formatRate(adminMinRate)} '
          'and Rs. ${_formatRate(adminMaxRate)}.';
    }

    if (!await transcriptFile.exists()) {
      return 'Please select a valid transcript.';
    }

    final fileSize = await transcriptFile.length();

    if (fileSize == 0 || fileSize > maxTranscriptSize) {
      return 'Transcript must be greater than 0 bytes and not exceed 10 MB.';
    }

    String languageValue = '';

    if (isProgrammingSubject) {
      languageValue = programmingLanguage?.trim() ?? '';

      if (languageValue.isEmpty) {
        return 'Please enter the programming language.';
      }
    }

    // ASP.NET Core [FromForm] nested DTO fields.
    final Map<String, String> fields = {
      'Courses[0].CourseId': courseId.toString(),
      'Courses[0].Grade': grade,
      'Courses[0].HourlyRate': hourlyRate.toString(),
      'Courses[0].Institute': institute,
      'Courses[0].PreviousTeacher': previousTeacher,
      'Courses[0].PreviousTeacherInstitute':
          previousTeacherInstitute,
      'Courses[0].StudyYear': studyYear?.toString() ?? '',
      'Courses[0].IsProgrammingSubject':
          isProgrammingSubject.toString(),
      'Courses[0].ProgrammingLanguage': languageValue,
      'Courses[0].LabCompleted': labCompleted.toString(),
    };

    debugPrint('========================================');
    debugPrint('ADD COURSE FIELDS: ${jsonEncode(fields)}');
    debugPrint('TRANSCRIPT FILE: ${transcriptFile.path}');
    debugPrint('TRANSCRIPT SIZE: $fileSize bytes');

    try {
      final response = await ApiClient.uploadFile(
        '/api/Tutor/add-courses',
        file: transcriptFile,
        fields: fields,

        // TranscriptFile is inside AddTutorCourseItemDto.
        // Do not send only "TranscriptFile".
        fileFieldName: 'Courses[0].TranscriptFile',
      );

      debugPrint('========================================');
      debugPrint('ADD COURSE STATUS: ${response.statusCode}');
      debugPrint('ADD COURSE RESPONSE: ${response.body}');
      debugPrint('========================================');

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        if (mounted) {
          _showMessage(
            'Course submitted successfully. Transcript is pending Admin verification.',
          );
          await loadCourses(showLoader: false);
        }
        return null;
      }

      if (response.statusCode == 401) {
        return 'Session expired. Please login again.';
      }

      return ApiClient.messageFromBody(response.body) ??
          'Unable to add course. Please try again.';
    } catch (e) {
      debugPrint('ADD COURSE ERROR: $e');
      return 'Network error. Please check your internet connection.';
    }
  }

  // ============================================================
  // ADD COURSE DETAILS DIALOG
  // ============================================================

  Future<void> _showCourseDetailsDialog(
    int courseId,
    String courseName, {
    required double minRate,
    required double maxRate,
  }) async {
    final gradeController = TextEditingController();
    final instituteController = TextEditingController();
    final previousTeacherController = TextEditingController();
    final previousTeacherInstituteController =
        TextEditingController();
    final studyYearController = TextEditingController();
    final rateController = TextEditingController();
    final languageController = TextEditingController();

    bool isProgrammingSubject = false;
    bool labCompleted = false;
    bool isSaving = false;
    File? selectedTranscript;

    // Error text shown INSIDE the dialog (above the buttons).
    String? formError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void showFormError(String message) {
              setDialogState(() => formError = message);
            }

            Future<void> chooseTranscript() async {
              final file = await _pickTranscript(
                onError: (message) {
                  if (dialogContext.mounted) {
                    showFormError(message);
                  }
                },
              );

              if (file != null && dialogContext.mounted) {
                setDialogState(() {
                  selectedTranscript = file;
                  formError = null;
                });
              }
            }

            Future<void> submitCourse() async {
              if (isSaving) return;

              final grade =
                  gradeController.text.trim().toUpperCase();

              final institute = instituteController.text.trim();

              final previousTeacher =
                  previousTeacherController.text.trim();

              final previousTeacherInstitute =
                  previousTeacherInstituteController.text.trim();

              final studyYearText =
                  studyYearController.text.trim();

              final rate = double.tryParse(
                rateController.text.trim(),
              );

              final language = languageController.text.trim();

              const validGrades = ['A', 'B', 'C', 'D', 'F'];

              if (!validGrades.contains(grade)) {
                showFormError('Enter a valid grade: A, B, C, D or F.');
                return;
              }

              if (institute.isEmpty || institute.length > 150) {
                showFormError(
                  'Please enter a valid institute/university name.',
                );
                return;
              }

              if (previousTeacher.isEmpty ||
                  previousTeacher.length > 150) {
                showFormError('Please enter the previous teacher name.');
                return;
              }

              if (previousTeacherInstitute.isEmpty ||
                  previousTeacherInstitute.length > 150) {
                showFormError(
                  'Please enter the previous teacher institute.',
                );
                return;
              }

              int? studyYear;

              if (studyYearText.isNotEmpty) {
                studyYear = int.tryParse(studyYearText);

                if (studyYear == null ||
                    studyYear < 1900 ||
                    studyYear > DateTime.now().year) {
                  showFormError('Please enter a valid study year.');
                  return;
                }
              }

              if (!_hasValidRateRange(minRate, maxRate)) {
                showFormError(
                  'Admin hourly rate range is not configured.',
                );
                return;
              }

              if (rate == null || rate <= 0) {
                showFormError('Please enter a valid hourly rate.');
                return;
              }

              if (rate < minRate || rate > maxRate) {
                showFormError(
                  'Hourly rate must be between Rs. '
                  '${_formatRate(minRate)} and Rs. ${_formatRate(maxRate)}.',
                );
                return;
              }

              if (isProgrammingSubject && language.isEmpty) {
                showFormError('Please enter the programming language.');
                return;
              }

              if (isProgrammingSubject && language.length > 100) {
                showFormError(
                  'Programming language cannot exceed 100 characters.',
                );
                return;
              }

              if (selectedTranscript == null) {
                showFormError('Please upload your academic transcript.');
                return;
              }

              setDialogState(() {
                isSaving = true;
                formError = null;
              });

              final error = await _addCourse(
                courseId: courseId,
                grade: grade,
                hourlyRate: rate,
                institute: institute,
                previousTeacher: previousTeacher,
                previousTeacherInstitute:
                    previousTeacherInstitute,
                studyYear: studyYear,
                isProgrammingSubject: isProgrammingSubject,
                programmingLanguage:
                    isProgrammingSubject ? language : null,
                labCompleted: isProgrammingSubject
                    ? labCompleted
                    : false,
                adminMinRate: minRate,
                adminMaxRate: maxRate,
                transcriptFile: selectedTranscript!,
              );

              if (!dialogContext.mounted) return;

              if (error == null) {
                Navigator.pop(dialogContext);
              } else {
                setDialogState(() {
                  isSaving = false;
                  formError = error;
                });
              }
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _iconContainer(Icons.menu_book_rounded),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Add Course Details',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      _sectionHeading('Selected Course'),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(.08),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          courseName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      _adminRateRangeCard(minRate, maxRate),

                      const SizedBox(height: 20),

                      _sectionHeading('Course Information'),

                      _fieldLabel('Academic Grade'),
                      _textField(
                        controller: gradeController,
                        hint: 'A, B, C, D or F',
                        icon: Icons.school_outlined,
                        maxLength: 1,
                        capitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp('[a-zA-Z]'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      _fieldLabel('Institute / University'),
                      _textField(
                        controller: instituteController,
                        hint: 'e.g. COMSATS University',
                        icon: Icons.account_balance_outlined,
                        maxLength: 150,
                        capitalization: TextCapitalization.words,
                      ),

                      const SizedBox(height: 14),

                      _fieldLabel('Your Hourly Rate (PKR)'),
                      _textField(
                        controller: rateController,
                        hint: 'Enter your hourly rate',
                        icon: Icons.payments_outlined,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      _sectionHeading('Previous Teacher Information'),

                      _fieldLabel('Teacher / Tutor Name'),
                      _textField(
                        controller: previousTeacherController,
                        hint: 'e.g. Sir Munir',
                        icon: Icons.person_outline,
                        maxLength: 150,
                        capitalization: TextCapitalization.words,
                      ),

                      const SizedBox(height: 14),

                      _fieldLabel('Teacher Institute / University'),
                      _textField(
                        controller: previousTeacherInstituteController,
                        hint: 'e.g. COMSATS University',
                        icon: Icons.account_balance_outlined,
                        maxLength: 150,
                        capitalization: TextCapitalization.words,
                      ),

                      const SizedBox(height: 14),

                      _fieldLabel('Study Year'),
                      _textField(
                        controller: studyYearController,
                        hint: 'e.g. 2025',
                        icon: Icons.calendar_today_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                      ),

                      const SizedBox(height: 22),

                      _sectionHeading('Programming Information'),

                      _checkboxCard(
                        title: 'Programming Subject',
                        subtitle:
                            'Enable this if the course involves programming.',
                        value: isProgrammingSubject,
                        onChanged: isSaving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  isProgrammingSubject = value ?? false;

                                  if (!isProgrammingSubject) {
                                    languageController.clear();
                                    labCompleted = false;
                                  }
                                });
                              },
                      ),

                      if (isProgrammingSubject) ...[
                        const SizedBox(height: 14),

                        _fieldLabel('Programming Language'),
                        _textField(
                          controller: languageController,
                          hint: 'Java, C++, Python, etc.',
                          icon: Icons.code_rounded,
                          maxLength: 100,
                          capitalization: TextCapitalization.words,
                        ),

                        const SizedBox(height: 12),

                        _checkboxCard(
                          title: 'Lab Completed / Attended',
                          subtitle: labCompleted
                              ? 'You have completed or attended the lab.'
                              : 'You have not completed or attended the lab.',
                          value: labCompleted,
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    labCompleted = value ?? false;
                                  });
                                },
                        ),
                      ],

                      const SizedBox(height: 22),

                      _sectionHeading('Transcript Verification'),

                      _transcriptPicker(
                        selectedFile: selectedTranscript,
                        isSaving: isSaving,
                        onPick: chooseTranscript,
                        onRemove: () {
                          setDialogState(() {
                            selectedTranscript = null;
                          });
                        },
                      ),

                      // ERROR MESSAGE INSIDE THE DIALOG
                      if (formError != null) ...[
                        const SizedBox(height: 16),
                        _errorBanner(formError!),
                      ],

                      const SizedBox(height: 22),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(49),
                                foregroundColor: textColor,
                                side: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSaving ? null : submitCourse,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size.fromHeight(49),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Submit Course',
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
            );
          },
        );
      },
    );

    _disposeLater([
      gradeController,
      instituteController,
      previousTeacherController,
      previousTeacherInstituteController,
      studyYearController,
      rateController,
      languageController,
    ]);
  }

  // ============================================================
  // ERROR BANNER (used inside dialog)
  // ============================================================

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFF5C6C6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: errorColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TRANSCRIPT PICKER WIDGET
  // ============================================================

  Widget _transcriptPicker({
    required File? selectedFile,
    required VoidCallback onPick,
    required VoidCallback onRemove,
    required bool isSaving,
  }) {
    final fileName =
        selectedFile?.path.split(Platform.pathSeparator).last;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: selectedFile == null
              ? Colors.grey.shade300
              : const Color(0xFFCDE9DF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.upload_file_rounded,
                color: primaryColor,
                size: 21,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Academic Transcript',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Text(
                'Required',
                style: TextStyle(
                  color: errorColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Upload your transcript to verify your academic grade.',
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          if (selectedFile == null)
            OutlinedButton.icon(
              onPressed: isSaving ? null : onPick,
              icon: const Icon(Icons.attach_file_rounded),
              label: const Text('Choose Transcript'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: const BorderSide(color: primaryColor),
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            )
          else
            Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  color: primaryColor,
                  size: 27,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName ?? 'Transcript',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${(selectedFile.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
                        style: const TextStyle(
                          fontSize: 10,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: isSaving ? null : onRemove,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: errorColor,
                  ),
                ),
                IconButton(
                  onPressed: isSaving ? null : onPick,
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          const Text(
            'Allowed: PDF, JPG, JPEG, PNG | Maximum size: 10 MB',
            style: TextStyle(
              fontSize: 10,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AVAILABLE COURSES DIALOG
  // ============================================================

  Future<void> _showAvailableCourses() async {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> filteredCourses = [
      ...availableCourses,
    ];

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void filterCourses(String value) {
              final query = value.trim().toLowerCase();

              setDialogState(() {
                filteredCourses = availableCourses.where((course) {
                  final name =
                      _toString(course['course_name']).toLowerCase();
                  return name.contains(query);
                }).toList();
              });
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 30,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 480,
                  maxHeight: 650,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available Courses',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Select a course you want to teach.',
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      TextField(
                        controller: searchController,
                        onChanged: filterCourses,
                        decoration: InputDecoration(
                          hintText: 'Search course name...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: primaryColor,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F7F9),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 13,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        '${filteredCourses.length} courses available',
                        style: const TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Flexible(
                        child: filteredCourses.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(30),
                                  child: Text(
                                    'No courses found.',
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: filteredCourses.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 9),
                                itemBuilder: (context, index) {
                                  final course = filteredCourses[index];

                                  final id =
                                      _toInt(course['course_id']);
                                  final name =
                                      _toString(course['course_name']);

                                  final minRate = _toDouble(
                                    course['admin_min_hourly_rate'],
                                  );

                                  final maxRate = _toDouble(
                                    course['admin_max_hourly_rate'],
                                  );

                                  final validRange =
                                      _hasValidRateRange(
                                    minRate,
                                    maxRate,
                                  );

                                  return Material(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(13),
                                    child: InkWell(
                                      borderRadius:
                                          BorderRadius.circular(13),
                                      onTap: id <= 0
                                          ? null
                                          : () {
                                              Navigator.pop(
                                                dialogContext,
                                              );

                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                if (mounted) {
                                                  _showCourseDetailsDialog(
                                                    id,
                                                    name,
                                                    minRate: minRate,
                                                    maxRate: maxRate,
                                                  );
                                                }
                                              });
                                            },
                                      child: Container(
                                        padding: const EdgeInsets.all(13),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(13),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            _iconContainer(
                                              Icons.menu_book_rounded,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: textColor,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 5),
                                                  Text(
                                                    validRange
                                                        ? 'Admin Range: Rs. ${_formatRate(minRate)} - Rs. ${_formatRate(maxRate)}'
                                                        : 'Admin rate range not configured',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: validRange
                                                          ? primaryColor
                                                          : warningColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              size: 15,
                                              color: primaryColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    _disposeLater([searchController]);
  }

  // ============================================================
  // ADMIN RATE RANGE CARD
  // ============================================================

  Widget _adminRateRangeCard(double minRate, double maxRate) {
    final valid = _hasValidRateRange(minRate, maxRate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: valid
            ? const Color(0xFFEDF8F5)
            : const Color(0xFFFFF5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: valid
              ? const Color(0xFFCDE9DF)
              : const Color(0xFFF2DDBD),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                color: primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Admin Approved Hourly Rate',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (valid)
            Text(
              'Rs. ${_formatRate(minRate)} - Rs. ${_formatRate(maxRate)}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            )
          else
            const Text(
              'Admin has not configured a valid hourly rate range for this course.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF91651F),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // REUSABLE UI WIDGETS
  // ============================================================

  Widget _iconContainer(IconData icon) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: primaryColor,
        size: 23,
      ),
    );
  }

  Widget _sectionHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      style: const TextStyle(
        color: textColor,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 12,
        ),
        counterText: '',
        prefixIcon: Icon(
          icon,
          color: primaryColor,
          size: 20,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: primaryColor,
            width: 1.5,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _checkboxCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?>? onChanged,
  }) {
    return Material(
      color: const Color(0xFFF7F9FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 5,
        ),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: primaryColor,
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: secondaryTextColor,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _verificationBadge(String status) {
    final value = status.isEmpty ? 'Pending' : status;

    Color color;
    IconData icon;

    switch (value.toLowerCase()) {
      case 'verified':
      case 'approved':
        color = successColor;
        icon = Icons.verified_rounded;
        break;
      case 'rejected':
        color = errorColor;
        icon = Icons.cancel_outlined;
        break;
      default:
        color = warningColor;
        icon = Icons.pending_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COURSE CARD
  // ============================================================

  Widget _courseCard(Map<String, dynamic> course) {
    final name = _toString(course['course_name']);
    final grade = _toString(course['grade']);
    final institute = _toString(course['institute']);
    final rate = _toDouble(course['hourly_rate']);

    final previousTeacher =
        _toString(course['previous_teacher']);

    final previousTeacherInstitute =
        _toString(course['previous_teacher_institute']);

    final studyYear = _toString(course['study_year']);

    final isProgramming =
        _toBool(course['is_programming_subject']);

    final language =
        _toString(course['programming_language']);

    final labCompleted = _toBool(course['lab_completed']);

    final verificationStatus =
        _toString(course['grade_verification_status']);

    final verifiedBy = _toString(course['verified_by']);
    final verifiedDate = _formatDate(course['verified_date']);
    final remarks = _toString(course['verification_remarks']);

    final evidence = course['transcript_evidence'];

    final isRejected =
        verificationStatus.toLowerCase() == 'rejected';

    String evidenceFileName = '';
    String evidenceStatus = '';
    String evidenceUploadedDate = '';

    if (evidence is Map) {
      evidenceFileName = _readAny(evidence, [
        'file_name',
        'fileName',
        'FileName',
      ]);

      evidenceStatus = _readAny(evidence, [
        'verification_status',
        'verificationStatus',
        'VerificationStatus',
      ]);

      evidenceUploadedDate = _formatDate(
        _readRaw(evidence, [
          'uploaded_date',
          'uploadedDate',
          'UploadedDate',
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE9EEF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconContainer(Icons.menu_book_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Course' : name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Rs. ${_formatRate(rate)} / hour',
                      style: const TextStyle(
                        fontSize: 13,
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _verificationBadge(verificationStatus),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200),

          if (isRejected) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: errorColor,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your transcript was rejected. Select this course again and upload a corrected transcript.',
                      style: TextStyle(
                        fontSize: 11,
                        color: errorColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          _sectionHeading('Course Information'),
          _informationRow('Academic Grade', grade),
          _informationRow('Institute / University', institute),
          _informationRow('Hourly Rate', 'Rs. ${_formatRate(rate)}'),

          const SizedBox(height: 16),
          _sectionHeading('Previous Teacher Information'),
          _informationRow('Teacher Name', previousTeacher),
          _informationRow(
            'Teacher Institute',
            previousTeacherInstitute,
          ),
          _informationRow('Study Year', studyYear),

          const SizedBox(height: 16),
          _sectionHeading('Programming Information'),
          _informationRow(
            'Programming Subject',
            isProgramming ? 'Yes' : 'No',
          ),
          if (isProgramming) ...[
            _informationRow('Programming Language', language),
            _informationRow(
              'Lab Completed',
              labCompleted ? 'Yes' : 'No',
            ),
          ],

          const SizedBox(height: 16),
          _sectionHeading('Grade Verification'),
          _informationRow('Verified By', verifiedBy),
          _informationRow('Verified Date', verifiedDate),

          if (remarks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Admin Remarks: $remarks',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF91651F),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          _sectionHeading('Transcript Information'),

          _informationRow(
            'File Name',
            evidenceFileName.isEmpty
                ? 'No transcript information returned'
                : evidenceFileName,
          ),

          _informationRow('Uploaded Date', evidenceUploadedDate),

          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Transcript Status',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                _verificationBadge(evidenceStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _informationRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF56646B),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: const TextStyle(
                fontSize: 12,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyCourses() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 75),
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'No Courses Added Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 35),
          child: Text(
            'Start building your teaching profile by adding the courses you can teach.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 25),
        Center(
          child: ElevatedButton.icon(
            onPressed: _showAvailableCourses,
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Course'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: textColor),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 27,
            errorBuilder: (_, __, ___) {
              return const Icon(
                Icons.school_rounded,
                color: primaryColor,
                size: 25,
              );
            },
          ),
          const SizedBox(width: 8),
          const Text(
            'House of Tutor',
            style: TextStyle(
              color: primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      drawer: const TutorDrawer(),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: () => loadCourses(showLoader: false),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Courses',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Manage the subjects you teach.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(.09),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${myCourses.length}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const Text(
                                'Courses',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 19,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Expanded(
                          child: Text(
                            'Your Teaching Subjects',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        Text(
                          '${myCourses.length} total',
                          style: const TextStyle(
                            fontSize: 11,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Expanded(
                      child: myCourses.isEmpty
                          ? _emptyCourses()
                          : ListView.separated(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(
                                bottom: 100,
                              ),
                              itemCount: myCourses.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 13),
                              itemBuilder: (context, index) {
                                return _courseCard(myCourses[index]);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading ? null : _showAvailableCourses,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Course',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}