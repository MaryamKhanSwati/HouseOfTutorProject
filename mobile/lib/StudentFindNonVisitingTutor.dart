import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:house_of_tutor/services/api_client.dart';

// Result of POST /api/Student/create-request
class _BookingResult {
  final bool success;
  final String message;
  final Map<String, dynamic> data;

  const _BookingResult({
    required this.success,
    required this.message,
    this.data = const {},
  });
}

class StudentFindTutorNonVisiting extends StatefulWidget {
  final int courseId;
  final String courseName;

  const StudentFindTutorNonVisiting({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<StudentFindTutorNonVisiting> createState() =>
      _StudentFindTutorNonVisitingState();
}

class _StudentFindTutorNonVisitingState
    extends State<StudentFindTutorNonVisiting> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryColor = Color(0xff1E8E7E);
  static const Color darkPrimaryColor = Color(0xff176F64);
  static const Color backgroundColor = Color(0xffF4F6F7);

  // ============================================================
  // STATE
  // ============================================================

  bool isLoading = false;
  bool isSubmitting = false;

  String errorMessage = '';
  bool errorIsNotFound = false;

  List<dynamic> tutorsList = [];
  List<dynamic> filteredTutors = [];

  // LinkedHashSet (default) keeps insertion order.
  // The order = tutor queue order on the backend (first = Pending, rest = Queued).
  final Set<int> selectedTutorIds = {};

  String selectedSort = 'feedback';

  String? selectedDay;
  String? selectedTime;

  final TextEditingController searchController = TextEditingController();

  // ============================================================
  // INIT / DISPOSE
  // ============================================================

  @override
  void initState() {
    super.initState();

    searchController.addListener(_filterTutors);

    fetchTutors();
  }

  @override
  void dispose() {
    searchController.removeListener(_filterTutors);
    searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // FETCH NON-VISITING TUTORS
  // GET /api/Student/search-non-visiting-tutors
  // ============================================================

  Future<void> fetchTutors({String? sort}) async {
    if (!mounted) return;

    final String sortValue = (sort ?? selectedSort).trim().toLowerCase();

    setState(() {
      isLoading = true;
      errorMessage = '';
      errorIsNotFound = false;
    });

    try {
      final Uri uri = Uri(
        path: '/api/Student/search-non-visiting-tutors',
        queryParameters: {
          'courseId': widget.courseId.toString(),
          'sortBy': sortValue,
        },
      );

      final response = await ApiClient.get(uri.toString());

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic data = await ApiClient.decodeJson(response);

        List<dynamic> tutors = [];

        if (data is Map) {
          final dynamic responseTutors = data['tutors'] ?? data['Tutors'];

          if (responseTutors is List) {
            tutors = responseTutors;
          }
        } else if (data is List) {
          tutors = data;
        }

        final List<dynamic> cleanedTutors = _prepareTutors(tutors);

        setState(() {
          selectedSort = sortValue;
          tutorsList = cleanedTutors;
          filteredTutors = cleanedTutors;
          errorMessage = '';
          errorIsNotFound = false;
          isLoading = false;

          _clearAllSelection();
        });

        _filterTutors();
      } else {
        final String message =
            ApiClient.messageFromBody(response.body) ??
                'Unable to find tutors.';

        setState(() {
          tutorsList = [];
          filteredTutors = [];
          errorIsNotFound = response.statusCode == 404;
          errorMessage = response.statusCode == 404
              ? message
              : 'Request failed (${response.statusCode}). $message';

          isLoading = false;
          _clearAllSelection();
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        tutorsList = [];
        filteredTutors = [];
        errorIsNotFound = false;
        errorMessage = 'Unable to load tutors.\n$e';

        _clearAllSelection();
      });
    }
  }

  // ============================================================
  // PREPARE TUTORS
  // ============================================================

  List<dynamic> _prepareTutors(List<dynamic> input) {
    final Map<int, Map<String, dynamic>> uniqueTutors = {};

    for (final item in input) {
      if (item is! Map) continue;

      final Map<String, dynamic> tutor = Map<String, dynamic>.from(item);

      final int? tutorId = _toIntNullable(
        tutor['tutor_id'] ?? tutor['tutorId'],
      );

      if (tutorId == null) continue;

      // Backend may also return slots with is_available = false
      // (reschedule / preschedule). Keep only truly available slots.
      final List<dynamic> slots = _getAvailableSlots(tutor);

      if (slots.isEmpty) continue;

      tutor['common_slots'] = slots;

      uniqueTutors[tutorId] = tutor;
    }

    return uniqueTutors.values.toList();
  }

  // ============================================================
  // SEARCH FILTER
  // ============================================================

  void _filterTutors() {
    if (!mounted) return;

    final String query = searchController.text.trim().toLowerCase();

    final List<dynamic> result = tutorsList.where((tutor) {
      if (tutor is! Map) return false;

      final String name = _value(tutor['tutor_name']).toLowerCase();
      final String institute = _value(tutor['institute']).toLowerCase();

      return name.contains(query) || institute.contains(query);
    }).toList();

    setState(() {
      filteredTutors = result;
    });
  }

  // ============================================================
  // TUTOR HELPERS
  // ============================================================

  int? _getTutorId(dynamic tutor) {
    if (tutor is! Map) return null;

    return _toIntNullable(
      tutor['tutor_id'] ?? tutor['tutorId'],
    );
  }

  dynamic _findTutorById(int tutorId) {
    for (final tutor in tutorsList) {
      if (_getTutorId(tutor) == tutorId) {
        return tutor;
      }
    }

    return null;
  }

  String _tutorName(int tutorId) {
    final dynamic tutor = _findTutorById(tutorId);

    if (tutor is Map) {
      return _value(tutor['tutor_name'], 'Tutor');
    }

    return 'Tutor';
  }

  String _value(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;

    final String text = value.toString().trim();

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return fallback;
    }

    return text;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _toIntNullable(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString());
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _toBool(dynamic value) {
    if (value == true) return true;
    if (value is num) return value == 1;

    final String text = value?.toString().trim().toLowerCase() ?? '';

    return text == 'true' || text == '1';
  }

  String _formatRate(dynamic value) {
    final double rate = _toDouble(value);

    if (rate == rate.roundToDouble()) {
      return rate.toInt().toString();
    }

    return rate.toStringAsFixed(2);
  }

  String _getInitials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'T';

    if (parts.length == 1) {
      return parts.first
          .substring(
            0,
            parts.first.length > 1 ? 2 : 1,
          )
          .toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // ============================================================
  // AVAILABLE SLOTS
  // ============================================================

  List<dynamic> _getAvailableSlots(dynamic tutor) {
    if (tutor is! Map) return [];

    final dynamic raw = tutor['common_slots'] ?? tutor['commonSlots'];

    if (raw is! List) return [];

    return raw.where((slot) {
      if (slot is! Map) return false;

      final bool available =
          _toBool(slot['is_available'] ?? slot['isAvailable']);

      final String day = _value(slot['day']);
      final String time = _value(slot['time']);

      return available && day.isNotEmpty && time.isNotEmpty;
    }).toList();
  }

  // Normalizes day/time text so "09:00 - 10:00" == "9:00-10:00".
  // (Backend compares with NormalizeDay / NormalizeTime.)
  String _normalizeSlotText(String value) {
    String text = value.trim().toLowerCase();

    text = text.replaceAll(RegExp(r'[\u2013\u2014]'), '-');
    text = text.replaceAll(RegExp(r'\s+'), '');
    text = text.replaceAllMapped(
      RegExp(r'(^|-)0(\d)'),
      (m) => '${m[1]}${m[2]}',
    );

    return text;
  }

  bool _sameSlot(
    String day1,
    String time1,
    String day2,
    String time2,
  ) {
    return _normalizeSlotText(day1) == _normalizeSlotText(day2) &&
        _normalizeSlotText(time1) == _normalizeSlotText(time2);
  }

  Map<String, dynamic>? _findSlot(
    int tutorId,
    String day,
    String time,
  ) {
    final dynamic tutor = _findTutorById(tutorId);

    if (tutor == null) return null;

    for (final slot in _getAvailableSlots(tutor)) {
      if (slot is! Map) continue;

      if (_sameSlot(
        _value(slot['day']),
        _value(slot['time']),
        day,
        time,
      )) {
        return Map<String, dynamic>.from(slot);
      }
    }

    return null;
  }

  // ============================================================
  // SELECT TUTORS
  // ============================================================

  void _toggleTutorSelection(int tutorId) {
    setState(() {
      if (selectedTutorIds.contains(tutorId)) {
        selectedTutorIds.remove(tutorId);
      } else {
        selectedTutorIds.add(tutorId);
      }

      // Slot must be chosen again after changing tutor selection.
      selectedDay = null;
      selectedTime = null;
    });
  }

  bool _isTutorSelected(int? tutorId) {
    if (tutorId == null) return false;

    return selectedTutorIds.contains(tutorId);
  }

  int _tutorQueueNumber(int? tutorId) {
    if (tutorId == null) return 0;

    return selectedTutorIds.toList().indexOf(tutorId) + 1;
  }

  void _clearAllSelection() {
    selectedTutorIds.clear();

    selectedDay = null;
    selectedTime = null;
  }

  void _clearSelection() {
    setState(() {
      _clearAllSelection();
    });
  }

  // ============================================================
  // CHECK SLOT FOR ALL SELECTED TUTORS
  // ============================================================

  bool _isSlotAvailableForAll(
    String day,
    String time,
  ) {
    if (selectedTutorIds.isEmpty) return false;

    for (final tutorId in selectedTutorIds) {
      final Map<String, dynamic>? slot = _findSlot(tutorId, day, time);

      if (slot == null) return false;
    }

    return true;
  }

  bool _selectedSlotAvailableForAllTutors() {
    if (selectedDay == null || selectedTime == null) {
      return false;
    }

    return _isSlotAvailableForAll(
      selectedDay!,
      selectedTime!,
    );
  }

  // LT room of each selected tutor for the selected slot.
  List<String> _selectedLtLines() {
    final List<String> lines = [];

    if (selectedDay == null || selectedTime == null) return lines;

    for (final tutorId in selectedTutorIds) {
      final Map<String, dynamic>? slot =
          _findSlot(tutorId, selectedDay!, selectedTime!);

      if (slot == null) continue;

      final String room = _value(slot['lt_room_name'], 'LT Room');
      final int remaining = _toInt(slot['lt_remaining_capacity']);
      final int capacity = _toInt(slot['lt_room_capacity']);

      lines.add(
        '${_tutorName(tutorId)}: $room ($remaining/$capacity places left)',
      );
    }

    return lines;
  }

  // ============================================================
  // SELECT SLOT
  // ============================================================

  void _selectSlot({
    required String day,
    required String time,
  }) {
    if (selectedTutorIds.isEmpty) {
      _showMessage('Please select at least one tutor first.');
      return;
    }

    if (!_isSlotAvailableForAll(day, time)) {
      _showMessage(
        'This slot is not available for every selected tutor. '
        'Please select another common slot.',
      );
      return;
    }

    setState(() {
      selectedDay = day;
      selectedTime = time;
    });
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  String _formatDeadline(String raw) {
    final DateTime? dt = DateTime.tryParse(raw);

    if (dt == null) return raw;

    final String h = dt.hour.toString().padLeft(2, '0');
    final String m = dt.minute.toString().padLeft(2, '0');

    return '${_formatDate(dt)} $h:$m';
  }

  // ============================================================
  // BACKEND MESSAGE HELPER
  // ============================================================

  String _extractErrorMessage(
    dynamic data,
    String rawBody,
    String fallback,
  ) {
    if (data is Map) {
      final StringBuffer buffer = StringBuffer(
        _value(
          data['message'] ?? data['Message'] ?? data['title'],
          fallback,
        ),
      );

      // Accelerated plan mismatch details from backend.
      final dynamic originalTotal = data['original_total_classes'];
      final dynamic requestedTotal = data['requested_total_classes'];

      if (originalTotal != null && requestedTotal != null) {
        buffer.write(
          '\nOriginal total classes: $originalTotal'
          '\nRequested total classes: $requestedTotal',
        );
      }

      final String error = _value(data['error']);

      if (error.isNotEmpty) {
        buffer.write('\n$error');
      }

      return buffer.toString();
    }

    return ApiClient.messageFromBody(rawBody) ?? fallback;
  }

  // ============================================================
  // BOOKING DIALOG
  // ============================================================

  Future<void> _showBookingDialog() async {
    if (selectedTutorIds.isEmpty) {
      _showMessage('Please select at least one tutor.');
      return;
    }

    if (selectedDay == null || selectedTime == null) {
      _showMessage('Please select a common available slot.');
      return;
    }

    if (!_selectedSlotAvailableForAllTutors()) {
      _showMessage(
        'Selected slot is no longer available for all selected tutors.',
      );
      return;
    }

    String dialogLearningMode = 'SpecificTime';
    String dialogDurationUnit = 'Hours';
    String dialogPlanType = 'Normal';

    bool dialogSubmitting = false;
    String? dialogError;

    final TextEditingController durationController = TextEditingController();
    final TextEditingController weeksController = TextEditingController();
    final TextEditingController classesController = TextEditingController();

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    DateTime selectedStartDate = today;

    // Selection can not change while the dialog is open.
    final List<int> orderedIds = selectedTutorIds.toList();

    final String tutorOrderText = [
      for (int i = 0; i < orderedIds.length; i++)
        '${i + 1}. ${_tutorName(orderedIds[i])}'
            '${i == 0 ? '  (receives request first)' : ''}',
    ].join('\n');

    final List<String> ltLines = _selectedLtLines();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.event_available,
                    color: primaryColor,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Confirm Tutor Request',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // SELECTED TUTORS
                      _dialogSectionTitle(
                        'Selected Tutors (${orderedIds.length})',
                      ),

                      _dialogInfoBox(
                        Icons.people_outline,
                        tutorOrderText,
                      ),

                      const SizedBox(height: 15),

                      // SELECTED SLOT
                      _dialogSectionTitle('Selected Schedule'),

                      _dialogInfoBox(
                        Icons.calendar_month_outlined,
                        '$selectedDay  •  $selectedTime',
                      ),

                      const SizedBox(height: 12),

                      // LT ROOMS
                      if (ltLines.isNotEmpty) ...[
                        _dialogSectionTitle('LT Room'),

                        _dialogInfoBox(
                          Icons.meeting_room_outlined,
                          ltLines.join('\n'),
                        ),

                        const SizedBox(height: 15),
                      ],

                      // LEARNING MODE
                      _dialogSectionTitle('Learning Mode'),

                      DropdownButtonFormField<String>(
                        value: dialogLearningMode,
                        isExpanded: true,
                        decoration: _dialogInputDecoration(
                          'Select learning mode',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'SpecificTime',
                            child: Text('Specific Time'),
                          ),
                          DropdownMenuItem(
                            value: 'FullTime',
                            child: Text('Full Time'),
                          ),
                        ],
                        onChanged: dialogSubmitting
                            ? null
                            : (value) {
                                if (value == null) return;

                                setDialogState(() {
                                  dialogLearningMode = value;
                                });
                              },
                      ),

                      if (dialogLearningMode == 'SpecificTime') ...[
                        const SizedBox(height: 13),

                        _dialogSectionTitle('Learning Duration'),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: durationController,
                                enabled: !dialogSubmitting,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: _dialogInputDecoration(
                                  'Enter duration',
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: dialogDurationUnit,
                                isExpanded: true,
                                decoration: _dialogInputDecoration('Unit'),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Hours',
                                    child: Text('Hours'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Days',
                                    child: Text('Days'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Weeks',
                                    child: Text('Weeks'),
                                  ),
                                ],
                                onChanged: dialogSubmitting
                                    ? null
                                    : (value) {
                                        if (value == null) return;

                                        setDialogState(() {
                                          dialogDurationUnit = value;
                                        });
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 18),

                      // COURSE PLAN
                      _dialogSectionTitle('Course Plan'),

                      DropdownButtonFormField<String>(
                        value: dialogPlanType,
                        isExpanded: true,
                        decoration: _dialogInputDecoration(
                          'Select course plan',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Normal',
                            child: Text('Normal Course Plan'),
                          ),
                          DropdownMenuItem(
                            value: 'Accelerated',
                            child: Text('Accelerated Course Plan'),
                          ),
                        ],
                        onChanged: dialogSubmitting
                            ? null
                            : (value) {
                                if (value == null) return;

                                setDialogState(() {
                                  dialogPlanType = value;
                                });
                              },
                      ),

                      if (dialogPlanType == 'Normal') ...[
                        const SizedBox(height: 8),
                        const Text(
                          'The normal plan uses the duration and classes per '
                          'week configured by the admin for this course.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],

                      if (dialogPlanType == 'Accelerated') ...[
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.orange.shade200,
                            ),
                          ),
                          child: Text(
                            'Accelerated plan must finish in fewer weeks than '
                            'the standard course, while keeping the same total '
                            'number of classes (weeks × classes per week).',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        _dialogSectionTitle('Requested Duration (Weeks)'),

                        TextField(
                          controller: weeksController,
                          enabled: !dialogSubmitting,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _dialogInputDecoration(
                            'Example: 8',
                          ),
                        ),

                        const SizedBox(height: 12),

                        _dialogSectionTitle('Classes Per Week'),

                        TextField(
                          controller: classesController,
                          enabled: !dialogSubmitting,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _dialogInputDecoration(
                            'Example: 2',
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // START DATE
                      _dialogSectionTitle('Course Start Date'),

                      InkWell(
                        onTap: dialogSubmitting
                            ? null
                            : () async {
                                final DateTime? picked = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: selectedStartDate,
                                  firstDate: today,
                                  lastDate: DateTime(2100),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: primaryColor,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );

                                if (picked != null) {
                                  setDialogState(() {
                                    selectedStartDate = picked;
                                  });
                                }
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _formatDate(selectedStartDate),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.edit_calendar_outlined,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // INLINE ERROR (snackbar would be hidden behind dialog)
                      if (dialogError != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 17,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dialogError!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogSubmitting
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: dialogSubmitting
                      ? null
                      : () async {
                          // ---------- Validate learning duration ----------
                          int? duration;

                          if (dialogLearningMode == 'SpecificTime') {
                            duration = int.tryParse(
                              durationController.text.trim(),
                            );

                            if (duration == null || duration <= 0) {
                              setDialogState(() {
                                dialogError =
                                    'Please enter a valid learning duration.';
                              });
                              return;
                            }
                          }

                          // ---------- Validate accelerated plan ----------
                          int? requestedWeeks;
                          int? requestedClasses;

                          if (dialogPlanType == 'Accelerated') {
                            requestedWeeks = int.tryParse(
                              weeksController.text.trim(),
                            );

                            requestedClasses = int.tryParse(
                              classesController.text.trim(),
                            );

                            if (requestedWeeks == null || requestedWeeks <= 0) {
                              setDialogState(() {
                                dialogError =
                                    'Please enter a valid accelerated duration.';
                              });
                              return;
                            }

                            if (requestedClasses == null ||
                                requestedClasses <= 0) {
                              setDialogState(() {
                                dialogError =
                                    'Please enter valid classes per week.';
                              });
                              return;
                            }
                          }

                          // ---------- Recheck slot ----------
                          if (!_selectedSlotAvailableForAllTutors()) {
                            setDialogState(() {
                              dialogError =
                                  'Selected time is not available for all tutors.';
                            });
                            return;
                          }

                          setDialogState(() {
                            dialogSubmitting = true;
                            dialogError = null;
                          });

                          final _BookingResult result =
                              await _submitRequest(
                            learningMode: dialogLearningMode,
                            learningDuration: duration,
                            learningDurationUnit:
                                dialogLearningMode == 'SpecificTime'
                                    ? dialogDurationUnit
                                    : null,
                            planType: dialogPlanType,
                            requestedDurationWeeks: requestedWeeks,
                            requestedClassesPerWeek: requestedClasses,
                            startDate: selectedStartDate,
                          );

                          if (result.success) {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            if (!mounted) return;

                            setState(() {
                              _clearAllSelection();
                            });

                            _showSuccessDialog(
                              result.data,
                              ltLines,
                              orderedIds.length,
                            );
                          } else {
                            if (!dialogContext.mounted) return;

                            setDialogState(() {
                              dialogSubmitting = false;
                              dialogError = result.message;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: dialogSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send Request'),
                ),
              ],
            );
          },
        );
      },
    );

    // Dispose after the dialog exit animation has finished.
    Future.delayed(const Duration(milliseconds: 500), () {
      durationController.dispose();
      weeksController.dispose();
      classesController.dispose();
    });
  }

  // ============================================================
  // DIALOG UI HELPERS
  // ============================================================

  Widget _dialogSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _dialogInfoBox(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xffEFF8F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: darkPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dialogInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 13,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: primaryColor,
        ),
      ),
    );
  }

  // ============================================================
  // CREATE REQUEST
  // POST /api/Student/create-request
  // ============================================================

  Future<_BookingResult> _submitRequest({
    required String learningMode,
    required int? learningDuration,
    required String? learningDurationUnit,
    required String planType,
    required int? requestedDurationWeeks,
    required int? requestedClassesPerWeek,
    required DateTime startDate,
  }) async {
    if (selectedTutorIds.isEmpty ||
        selectedDay == null ||
        selectedTime == null) {
      return const _BookingResult(
        success: false,
        message: 'Please select tutors and an available slot.',
      );
    }

    if (!_selectedSlotAvailableForAllTutors()) {
      return const _BookingResult(
        success: false,
        message: 'The selected slot is not available for all selected tutors.',
      );
    }

    if (mounted) {
      setState(() {
        isSubmitting = true;
      });
    }

    try {
      final bool isSpecific = learningMode == 'SpecificTime';
      final bool isAccelerated = planType == 'Accelerated';

      final Map<String, dynamic> requestBody = {
        // Order matters: first tutor = Pending, others = Queued.
        'tutor_ids': selectedTutorIds.toList(),
        'course_id': widget.courseId,
        'day': selectedDay!.trim(),
        'time': selectedTime!.trim(),

        'learning_mode': learningMode,
        'learning_duration': isSpecific ? learningDuration : null,
        'learning_duration_unit': isSpecific ? learningDurationUnit : null,

        'plan_type': planType,
        'requested_duration_weeks':
            isAccelerated ? requestedDurationWeeks : null,
        'requested_classes_per_week':
            isAccelerated ? requestedClassesPerWeek : null,

        'start_date': _formatDate(startDate),
      };

      debugPrint('CREATE REQUEST BODY: $requestBody');

      final response = await ApiClient.post(
        '/api/Student/create-request',
        requestBody,
      );

      dynamic responseData;

      try {
        responseData = await ApiClient.decodeJson(response);
      } catch (_) {
        responseData = null;
      }

      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> result = responseData is Map
            ? Map<String, dynamic>.from(responseData)
            : {};

        return _BookingResult(
          success: true,
          message: _value(
            result['message'],
            'Tutor request created successfully.',
          ),
          data: result,
        );
      }

      return _BookingResult(
        success: false,
        message: _extractErrorMessage(
          responseData,
          response.body,
          'Failed to create tutor request.',
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }

      return _BookingResult(
        success: false,
        message: 'Error creating tutor request:\n$e',
      );
    }
  }

  // ============================================================
  // SUCCESS DIALOG
  // ============================================================

  void _showSuccessDialog(
    Map<String, dynamic> result,
    List<String> ltLines,
    int selectedCount,
  ) {
    final String planType = _value(result['plan_type'], 'Normal');

    final String originalWeeks =
        _value(result['original_duration_weeks'], '-');

    final String originalClasses =
        _value(result['original_classes_per_week'], '-');

    final String requestedWeeks =
        _value(result['requested_duration_weeks'], '-');

    final String requestedClasses =
        _value(result['requested_classes_per_week'], '-');

    final String totalClasses = _value(result['total_classes'], '-');

    final String startDate = _value(result['start_date'], '-');

    final String totalTutors =
        _value(result['total_tutors'], selectedCount.toString());

    final String deadlineRaw = _value(result['response_deadline']);

    final String message = _value(
      result['message'],
      'Tutor request created successfully.',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.check_circle,
                color: primaryColor,
                size: 28,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Request Sent',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),

                const SizedBox(height: 14),

                _successRow('Selected tutors', totalTutors),

                _successRow('Plan type', planType),

                _successRow(
                  'Original course',
                  '$originalWeeks weeks • $originalClasses classes/week',
                ),

                _successRow(
                  'Requested course',
                  '$requestedWeeks weeks • $requestedClasses classes/week',
                ),

                _successRow('Total classes', totalClasses),

                _successRow('Start date', startDate),

                if (deadlineRaw.isNotEmpty)
                  _successRow(
                    'First tutor must reply by',
                    _formatDeadline(deadlineRaw),
                  ),

                for (final String line in ltLines)
                  _successRow('LT Room', line),

                const SizedBox(height: 13),

                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'The first tutor receives your request first. '
                    'If that tutor does not respond within the allowed time, '
                    'the request moves to the next tutor in the queue.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Widget _successRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 19,
            color: Colors.black87,
          ),
        ),
        title: Column(
          children: [
            const Text(
              'FIND NON-VISITING TUTORS',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              widget.courseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: isLoading ? null : () => fetchTutors(),
            icon: const Icon(
              Icons.refresh,
              color: primaryColor,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: primaryColor,
              onRefresh: () => fetchTutors(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInformationBanner(),
                          const SizedBox(height: 13),
                          _buildSearchField(),
                          const SizedBox(height: 12),
                          _buildSortSection(),
                          const SizedBox(height: 13),
                          _buildListHeading(),
                        ],
                      ),
                    ),
                  ),
                  if (isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: primaryColor,
                        ),
                      ),
                    )
                  else if (errorMessage.isNotEmpty && filteredTutors.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildErrorView(),
                    )
                  else if (filteredTutors.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyView(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _buildTutorCard(
                              filteredTutors[index],
                            );
                          },
                          childCount: filteredTutors.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (selectedTutorIds.isNotEmpty) _buildBottomBookingBar(),
        ],
      ),
    );
  }

  // ============================================================
  // INFORMATION BANNER
  // ============================================================

  Widget _buildInformationBanner() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xffE8F5F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xffC9E7E0),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.meeting_room_outlined,
            color: primaryColor,
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Non-Visiting tutors teach in an LT room. Only slots that match '
              'your schedule and have free LT capacity are shown. '
              'Select one or more tutors, then choose a common day and time. '
              'Tutors are contacted one by one in the order you select them.',
              style: TextStyle(
                color: darkPrimaryColor,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH FIELD
  // ============================================================

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          icon: const Icon(
            Icons.search,
            color: primaryColor,
          ),
          hintText: 'Search tutor by name or institute...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
          border: InputBorder.none,
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    searchController.clear();
                  },
                  icon: const Icon(Icons.close),
                )
              : null,
        ),
      ),
    );
  }

  // ============================================================
  // SORT SECTION
  // ============================================================

  Widget _buildSortSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _sortButton('feedback', 'Feedback', Icons.star_outline),
          const SizedBox(width: 8),
          _sortButton('fee', 'Payment', Icons.payments_outlined),
          const SizedBox(width: 8),
          _sortButton('institute', 'Institute', Icons.school_outlined),
          const SizedBox(width: 8),
          _sortButton('grade', 'Grade', Icons.menu_book_outlined),
        ],
      ),
    );
  }

  Widget _sortButton(
    String value,
    String label,
    IconData icon,
  ) {
    final bool active = selectedSort == value;

    return OutlinedButton.icon(
      onPressed: isLoading || active
          ? null
          : () {
              fetchTutors(sort: value);
            },
      icon: Icon(
        icon,
        size: 16,
        color: active ? Colors.white : primaryColor,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : Colors.black87,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? primaryColor : Colors.white,
        disabledBackgroundColor: active ? primaryColor : Colors.white,
        side: BorderSide(
          color: active ? primaryColor : Colors.grey.shade300,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  // ============================================================
  // LIST HEADING
  // ============================================================

  Widget _buildListHeading() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Available Tutors',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Text(
          '${filteredTutors.length} found',
          style: const TextStyle(
            fontSize: 12,
            color: primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY / ERROR VIEW
  // ============================================================

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 55,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'No tutors found',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try another search or refresh the tutor list.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              errorIsNotFound ? Icons.info_outline : Icons.error_outline,
              size: 50,
              color: errorIsNotFound
                  ? Colors.orange.shade400
                  : Colors.red.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: () => fetchTutors(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TUTOR CARD
  // ============================================================

  Widget _buildTutorCard(dynamic tutor) {
    if (tutor is! Map) return const SizedBox.shrink();

    final int? tutorId = _getTutorId(tutor);

    final String name = _value(tutor['tutor_name'], 'Tutor');

    final String qualification =
        _value(tutor['qualification'], 'Not specified');

    final String experience = _value(tutor['experience'], 'Not specified');

    final String institute = _value(tutor['institute'], 'Not specified');

    final String grade = _value(tutor['grade'], 'Not specified');

    final String location = _value(tutor['location'], 'Not specified');

    final String teachingMode = _value(tutor['teaching_mode'], 'Non-Visiting');

    final double rating = _toDouble(tutor['average_rating']);

    final int reviews = _toInt(tutor['total_reviews']);

    final String fee = _formatRate(tutor['hourly_rate']);

    final bool selected = _isTutorSelected(tutorId);

    final int queueNumber = _tutorQueueNumber(tutorId);

    final bool labCompleted = _toBool(tutor['lab_completed']);

    final List<dynamic> slots = _getAvailableSlots(tutor);

    final List<dynamic> previousTeachers =
        tutor['previous_teachers'] is List ? tutor['previous_teachers'] : [];

    final List<dynamic> programmingLanguages =
        tutor['programming_languages'] is List
            ? tutor['programming_languages']
            : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: selected ? primaryColor : Colors.grey.shade200,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            children: [
              Checkbox(
                value: selected,
                activeColor: primaryColor,
                onChanged: tutorId == null || isSubmitting
                    ? null
                    : (_) {
                        _toggleTutorSelection(tutorId);
                      },
              ),
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  color: const Color(0xffE8F5F2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    _getInitials(name),
                    style: const TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${rating.toStringAsFixed(1)} ($reviews reviews)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (selected)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xffE8F5F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 14,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    queueNumber == 1
                        ? 'Selected • Request order #1 (contacted first)'
                        : 'Selected • Request order #$queueNumber',
                    style: const TextStyle(
                      color: darkPrimaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 13),

          // TEACHING MODE
          _buildTag(
            Icons.meeting_room_outlined,
            teachingMode,
            const Color(0xffEAF2FF),
            const Color(0xff2457A6),
          ),

          const SizedBox(height: 12),

          // BASIC INFORMATION
          _buildInfoRow(Icons.school_outlined, qualification),
          const SizedBox(height: 7),
          _buildInfoRow(Icons.work_outline, experience),
          const SizedBox(height: 7),
          _buildInfoRow(Icons.location_on_outlined, location),

          const SizedBox(height: 13),

          // COURSE INFORMATION
          const Text(
            'Course Information',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 9),

          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _buildInfoChip(Icons.account_balance_outlined, institute),
              _buildInfoChip(Icons.menu_book_outlined, 'Grade: $grade'),
              _buildInfoChip(Icons.payments_outlined, 'Rs. $fee/hr'),
            ],
          ),

          const SizedBox(height: 14),

          // LAB STATUS
          _buildSectionTitle(
            Icons.science_outlined,
            'Lab Information',
          ),

          const SizedBox(height: 8),

          _buildStatusBox(
            labCompleted ? 'Lab completed' : 'Lab not marked as completed',
            labCompleted,
          ),

          const SizedBox(height: 14),

          // PREVIOUS TEACHERS
          _buildSectionTitle(
            Icons.person_search_outlined,
            'Previous Teachers',
          ),

          const SizedBox(height: 8),

          if (previousTeachers.isEmpty)
            _buildNoData('No previous teacher information added.')
          else
            ...previousTeachers.map((teacher) {
              if (teacher is! Map) {
                return const SizedBox.shrink();
              }

              return _buildPreviousTeacher(teacher);
            }),

          const SizedBox(height: 14),

          // PROGRAMMING LANGUAGES
          _buildSectionTitle(
            Icons.code,
            'Programming Languages',
          ),

          const SizedBox(height: 8),

          if (programmingLanguages.isEmpty)
            _buildNoData(
              'No programming language information added for this course.',
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: programmingLanguages.map((language) {
                if (language is! Map) {
                  return const SizedBox.shrink();
                }

                final String languageName =
                    _value(language['language_name'], 'Language');

                return _buildInfoChip(Icons.code, languageName);
              }).toList(),
            ),

          const SizedBox(height: 15),

          // AVAILABLE SLOTS
          _buildSectionTitle(
            Icons.schedule,
            'Available LT Time Slots',
          ),

          const SizedBox(height: 9),

          if (slots.isEmpty)
            _buildNoData('No available slots.')
          else
            ...slots.map((slot) {
              if (slot is! Map) {
                return const SizedBox.shrink();
              }

              return _buildSlotCard(
                tutorId: tutorId,
                slot: slot,
              );
            }),
        ],
      ),
    );
  }

  // ============================================================
  // PREVIOUS TEACHER CARD
  // ============================================================

  Widget _buildPreviousTeacher(Map teacher) {
    final String teacherName = _value(teacher['teacher_name'], 'Teacher');

    final String teacherInstitute =
        _value(teacher['institute'], 'Institute not specified');

    final String studyYear = _value(teacher['study_year'], '');

    final String description = _value(teacher['description'], '');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teacherName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            teacherInstitute,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
          if (studyYear.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Study year: $studyYear',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // SLOT CARD
  // ============================================================

  Widget _buildSlotCard({
    required int? tutorId,
    required dynamic slot,
  }) {
    final String day = _value(slot['day']);
    final String time = _value(slot['time']);

    final bool isSelected = selectedDay != null &&
        selectedTime != null &&
        _sameSlot(
          selectedDay!,
          selectedTime!,
          day,
          time,
        );

    final String roomName = _value(slot['lt_room_name'], 'LT Room');

    final int capacity = _toInt(slot['lt_room_capacity']);

    final int booked = _toInt(slot['lt_booked_count']);

    final int remaining = _toInt(slot['lt_remaining_capacity']);

    final bool canSelect =
        selectedTutorIds.isNotEmpty && _isSlotAvailableForAll(day, time);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xffE4F4EF) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isSelected ? primaryColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: primaryColor,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  day,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.access_time,
                size: 15,
                color: primaryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: !canSelect || isSubmitting
                      ? null
                      : () {
                          _selectSlot(
                            day: day,
                            time: time,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isSelected ? darkPrimaryColor : primaryColor,
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isSelected ? 'Selected' : 'Select',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.meeting_room_outlined,
                  size: 16,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    roomName,
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$remaining/$capacity left',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: remaining > 0 ? darkPrimaryColor : Colors.red,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 5),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Booked: $booked  •  Remaining: $remaining',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),

          if (selectedTutorIds.isNotEmpty && !canSelect)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Not available for all selected tutors',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  Widget _buildSectionTitle(
    IconData icon,
    String title,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: primaryColor,
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTag(
    IconData icon,
    String label,
    Color background,
    Color foreground,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xffF1F4F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: primaryColor,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBox(
    String label,
    bool completed,
  ) {
    final Color color = completed ? darkPrimaryColor : Colors.orange.shade800;

    final Color background =
        completed ? Colors.green.shade50 : Colors.orange.shade50;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoData(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.grey,
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM BOOKING BAR
  // ============================================================

  Widget _buildBottomBookingBar() {
    final bool hasSlot = selectedDay != null && selectedTime != null;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${selectedTutorIds.length} tutor(s) selected',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: isSubmitting ? null : _clearSelection,
                  child: const Text(
                    'Clear selection',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            if (selectedTutorIds.length > 1)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tutors are contacted one by one in the order you selected them.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),

            if (hasSlot)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xffE8F5F2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_available,
                      size: 17,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$selectedDay • $selectedTime',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: darkPrimaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(
              width: double.infinity,
              height: 49,
              child: ElevatedButton.icon(
                onPressed: isSubmitting
                    ? null
                    : hasSlot
                        ? _showBookingDialog
                        : null,
                icon: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  isSubmitting
                      ? 'Sending Request...'
                      : hasSlot
                          ? 'Continue & Send Request'
                          : 'Select a Common Day & Time',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor: Colors.grey.shade400,
                  foregroundColor: Colors.white,
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
    );
  }
}