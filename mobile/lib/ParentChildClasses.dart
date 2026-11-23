

















import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:house_of_tutor/services/api_client.dart';

class ParentChildClasses extends StatefulWidget {
  final int studentId;
  final int courseId;
  final String courseTitle;

  const ParentChildClasses({
    Key? key,
    required this.studentId,
    required this.courseId,
    required this.courseTitle,
  }) : super(key: key);

  @override
  State<ParentChildClasses> createState() => _ParentChildClassesState();
}

class _ParentChildClassesState extends State<ParentChildClasses> {
  // =====================================================
  // COLORS
  // =====================================================

  static const Color primaryColor = Color(0xFF1E8E7E);
  static const Color backgroundColor = Color(0xFFF5F7F8);
  static const Color textColor = Color(0xFF263238);

  // =====================================================
  // VARIABLES
  // =====================================================

  List<dynamic> classesList = [];
  bool isLoading = true;

  // Fixed days - no horizontal scrolling
  final List<String> weekDaysShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  // Time slots: 8 AM to 10 PM
  final List<String> timeSlotLabels = [
    '8-9 AM',
    '9-10 AM',
    '10-11 AM',
    '11-12 PM',
    '12-1 PM',
    '1-2 PM',
    '2-3 PM',
    '3-4 PM',
    '4-5 PM',
    '5-6 PM',
    '6-7 PM',
    '7-8 PM',
    '8-9 PM',
    '9-10 PM',
  ];

  static const int gridStartHour = 8;
  static const int gridSlotCount = 14;

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();
    fetchChildClasses();
  }

  // =====================================================
  // FETCH CHILD CLASSES
  // =====================================================

  Future<void> fetchChildClasses() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiClient.get(
        '/api/Parent/child-classes/${widget.studentId}/${widget.courseId}',
      );

      debugPrint('CHILD CLASSES STATUS: ${response.statusCode}');
      debugPrint('CHILD CLASSES BODY: ${response.body}');

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        List<dynamic> result = [];

        // Direct list response
        if (decodedData is List) {
          result = List<dynamic>.from(decodedData);
        }

        // Object response
        else if (decodedData is Map<String, dynamic>) {
          if (decodedData['classes'] is List) {
            result = List<dynamic>.from(decodedData['classes']);
          } else if (decodedData['data'] is List) {
            result = List<dynamic>.from(decodedData['data']);
          } else if (decodedData['result'] is List) {
            result = List<dynamic>.from(decodedData['result']);
          }
        }

        // Filter selected course
        result = result.where((item) {
          if (item is! Map) return false;

          final itemCourseId =
              item['courseId'] ?? item['course_id'];

          return itemCourseId != null &&
              itemCourseId.toString().trim() ==
                  widget.courseId.toString();
        }).toList();

        // Only accepted and active classes
        result = result.where((item) {
          if (item is! Map) return false;

          final status = (item['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

          return status == 'accepted' || status == 'active';
        }).toList();

        // Sort by day
        result.sort((a, b) {
          return _getDayIndex(
            _getItemValue(a, ['day']),
          ).compareTo(
            _getDayIndex(
              _getItemValue(b, ['day']),
            ),
          );
        });

        if (!mounted) return;

        setState(() {
          classesList = result;
          isLoading = false;
        });
      } else {
        if (!mounted) return;

        setState(() {
          classesList = [];
          isLoading = false;
        });

        _showSnackBar('Failed to load class sessions.');
      }
    } catch (e) {
      debugPrint('CHILD CLASSES ERROR: $e');

      if (!mounted) return;

      setState(() {
        classesList = [];
        isLoading = false;
      });

      _showSnackBar('An error occurred while loading classes.');
    }
  }

  // =====================================================
  // SAFE API VALUE
  // =====================================================

  String _getItemValue(dynamic item, List<String> keys) {
    if (item is! Map) return '';

    for (final key in keys) {
      final value = item[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  // =====================================================
  // DAY INDEX
  // =====================================================

  int _getDayIndex(String day) {
    switch (day.toLowerCase().trim()) {
      case 'monday':
      case 'mon':
        return 1;
      case 'tuesday':
      case 'tue':
      case 'tues':
        return 2;
      case 'wednesday':
      case 'wed':
        return 3;
      case 'thursday':
      case 'thu':
      case 'thur':
      case 'thurs':
        return 4;
      case 'friday':
      case 'fri':
        return 5;
      case 'saturday':
      case 'sat':
        return 6;
      case 'sunday':
      case 'sun':
        return 7;
      default:
        return 8;
    }
  }

  // =====================================================
  // FULL DAY NAME
  // =====================================================

  String _getFullDayName(String day) {
    switch (day.toLowerCase().trim()) {
      case 'monday':
      case 'mon':
        return 'Monday';
      case 'tuesday':
      case 'tue':
      case 'tues':
        return 'Tuesday';
      case 'wednesday':
      case 'wed':
        return 'Wednesday';
      case 'thursday':
      case 'thu':
      case 'thur':
      case 'thurs':
        return 'Thursday';
      case 'friday':
      case 'fri':
        return 'Friday';
      case 'saturday':
      case 'sat':
        return 'Saturday';
      case 'sunday':
      case 'sun':
        return 'Sunday';
      default:
        return day.isEmpty ? 'Day Not Available' : day;
    }
  }

  // =====================================================
  // EXTRACT CLASS START HOUR
  // =====================================================

  int? _extractStartHour(String time) {
    if (time.isEmpty) return null;

    final match = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
      caseSensitive: false,
    ).firstMatch(time);

    if (match == null) return null;

    int? hour = int.tryParse(match.group(1) ?? '');

    if (hour == null) return null;

    final meridiem = match.group(3)?.toLowerCase();

    if (meridiem == 'pm' && hour != 12) {
      hour += 12;
    } else if (meridiem == 'am' && hour == 12) {
      hour = 0;
    }

    return hour;
  }

  int? _getSlotIndex(String time) {
    final hour = _extractStartHour(time);

    if (hour == null) return null;

    final index = hour - gridStartHour;

    if (index < 0 || index >= gridSlotCount) {
      return null;
    }

    return index;
  }

  // =====================================================
  // CHECK IF CLASS EXISTS IN THIS DAY AND TIME
  // =====================================================

  bool _hasClass(int dayIndex, int slotIndex) {
    return classesList.any((item) {
      if (item is! Map) return false;

      final day = _getDayIndex(
        _getItemValue(item, ['day']),
      );

      final slot = _getSlotIndex(
        _getItemValue(
          item,
          ['time', 'classTime', 'class_time'],
        ),
      );

      return day == dayIndex && slot == slotIndex;
    });
  }

  // =====================================================
  // REFRESH
  // =====================================================

  Future<void> refreshClasses() async {
    await fetchChildClasses();
  }

  // =====================================================
  // SNACKBAR
  // =====================================================

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =====================================================
  // WEEKLY TIMETABLE
  // FIXED DAYS - NO HORIZONTAL SCROLLING
  // =====================================================

  Widget _buildTimetableGrid() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE5EAE9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading
          const Text(
            'Weekly Timetable',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Class schedule from Monday to Sunday',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 16),

          // Fixed timetable grid
          LayoutBuilder(
            builder: (context, constraints) {
              const double timeColumnWidth = 66;
              const double cellHeight = 35;

              final double dayColumnWidth =
                  (constraints.maxWidth - timeColumnWidth) / 7;

              return Column(
                children: [
                  // DAY HEADERS
                  Row(
                    children: [
                      SizedBox(
                        width: timeColumnWidth,
                        height: 36,
                        child: const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'TIME',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),

                      ...List.generate(7, (index) {
                        return SizedBox(
                          width: dayColumnWidth,
                          height: 36,
                          child: Center(
                            child: Text(
                              weekDaysShort[index],
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),

                  // HEADER DIVIDER
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE8ECEB),
                  ),

                  // TIME SLOT ROWS
                  ...List.generate(gridSlotCount, (slotIndex) {
                    return SizedBox(
                      height: cellHeight,
                      child: Row(
                        children: [
                          // TIME LABEL
                          SizedBox(
                            width: timeColumnWidth,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                timeSlotLabels[slotIndex],
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                          // FIXED 7 DAY CELLS
                          ...List.generate(7, (dayIndex) {
                            final hasClass = _hasClass(
                              dayIndex + 1,
                              slotIndex,
                            );

                            return SizedBox(
                              width: dayColumnWidth,
                              height: cellHeight,
                              child: Center(
                                child: Container(
                                  width: 23,
                                  height: 23,
                                  decoration: BoxDecoration(
                                    color: hasClass
                                        ? primaryColor
                                        : const Color(0xFFF2F4F4),
                                    borderRadius:
                                        BorderRadius.circular(5),
                                  ),
                                  child: hasClass
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // SIMPLE LEGEND
          Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Active class',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // CLASS DETAIL CARD
  // =====================================================

  Widget _buildClassCard(dynamic item) {
    if (item is! Map) return const SizedBox.shrink();

    final courseName = _getItemValue(
      item,
      ['courseName', 'course_name', 'course'],
    );

    final tutorName = _getItemValue(
      item,
      ['tutorName', 'tutor_name', 'instructor'],
    );

    final tutorEmail = _getItemValue(
      item,
      ['tutorEmail', 'tutor_email', 'email'],
    );

    final tutorPhone = _getItemValue(
      item,
      ['tutorPhone', 'tutor_phone', 'phone'],
    );

    final day = _getFullDayName(
      _getItemValue(item, ['day']),
    );

    final time = _getItemValue(
      item,
      ['time', 'classTime', 'class_time'],
    );

    final classDate = _formatDate(
      item['classDate'] ?? item['class_date'],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFFE7ECEB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course and status
          Row(
            children: [
              Expanded(
                child: Text(
                  courseName.isNotEmpty
                      ? courseName
                      : widget.courseTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF24865C),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          const Divider(
            height: 1,
            color: Color(0xFFEDF0F0),
          ),

          const SizedBox(height: 13),

          // Tutor name - no person avatar/icon
          _detailRow(
            'Instructor',
            tutorName.isNotEmpty ? tutorName : 'Not Available',
          ),

          if (tutorEmail.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailRow('Email', tutorEmail),
          ],

          if (tutorPhone.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailRow('Phone', tutorPhone),
          ],

          const SizedBox(height: 13),

          // Class timing
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8F7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              children: [
                _scheduleInfoRow('Day', day),
                const SizedBox(height: 9),
                _scheduleInfoRow(
                  'Time',
                  time.isNotEmpty ? time : 'Not Available',
                ),

                if (classDate != 'N/A') ...[
                  const SizedBox(height: 9),
                  _scheduleInfoRow('Date', classDate),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // DETAIL ROW
  // =====================================================

  Widget _detailRow(String title, String value) {
    return Row(
      children: [
        SizedBox(
          width: 65,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ),

        const Text(
          ':',
          style: TextStyle(color: Colors.grey),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // SCHEDULE INFO ROW
  // =====================================================

  Widget _scheduleInfoRow(String title, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // FORMAT DATE
  // =====================================================

  String _formatDate(dynamic value) {
    if (value == null) return 'N/A';

    final date = value.toString().trim();

    if (date.isEmpty) return 'N/A';

    final parsedDate = DateTime.tryParse(date);

    if (parsedDate == null) {
      return date.split('T')[0];
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr',
      'May', 'Jun', 'Jul', 'Aug',
      'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${parsedDate.day} ${months[parsedDate.month - 1]} ${parsedDate.year}';
  }

  // =====================================================
  // EMPTY STATE
  // =====================================================

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 45,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE7ECEB),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 43,
            color: Colors.grey.shade400,
          ),

          const SizedBox(height: 13),

          const Text(
            'No Active Classes Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'No active classes are available for ${widget.courseTitle}.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 15),

          TextButton.icon(
            onPressed: refreshClasses,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
            style: TextButton.styleFrom(
              foregroundColor: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      // APP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 19,
            color: primaryColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),

        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 27,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),

            const SizedBox(width: 8),

            const Text(
              'House of Tutor',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),

        centerTitle: true,

        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFE9EEEE),
          ),
        ),
      ),

      // BODY
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: refreshClasses,

        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: primaryColor,
                ),
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  14,
                  18,
                  14,
                  25,
                ),
                children: [
                  // Course title
                  Text(
                    widget.courseTitle,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Weekly class schedule',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 17),

                  if (classesList.isEmpty) ...[
                    _buildEmptyState(),
                  ] else ...[
                    // Fixed weekly timetable
                    _buildTimetableGrid(),

                    const SizedBox(height: 22),

                    const Text(
                      'Class Details',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),

                    const SizedBox(height: 12),

                    ...classesList.map(
                      (item) => _buildClassCard(item),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:house_of_tutor/services/api_client.dart';

// class ParentChildClasses extends StatefulWidget {
//   final int studentId;
//   final int courseId;
//   final String courseTitle;

//   const ParentChildClasses({
//     Key? key,
//     required this.studentId,
//     required this.courseId,
//     required this.courseTitle,
//   }) : super(key: key);

//   @override
//   State<ParentChildClasses> createState() => _ParentChildClassesState();
// }

// class _ParentChildClassesState extends State<ParentChildClasses> {
//   // =====================================================
//   // COLORS
//   // =====================================================

//   static const Color primaryColor = Color(0xFF1E8E7E);
//   static const Color backgroundColor = Color(0xFFF5F7FA);
//   static const Color textColor = Color(0xFF263238);
//   static const Color lightTeal = Color(0xFFEAF5F2);

//   // =====================================================
//   // VARIABLES
//   // =====================================================

//   List<dynamic> classesList = [];
//   bool isLoading = true;

//   final List<String> weekDays = [
//     'Monday',
//     'Tuesday',
//     'Wednesday',
//     'Thursday',
//     'Friday',
//     'Saturday',
//     'Sunday',
//   ];

//   final List<String> weekDaysShort = [
//     'MON',
//     'TUE',
//     'WED',
//     'THU',
//     'FRI',
//     'SAT',
//     'SUN',
//   ];

//   // =====================================================
//   // INIT
//   // =====================================================

//   @override
//   void initState() {
//     super.initState();
//     fetchChildClasses();
//   }

//   // =====================================================
//   // FETCH CHILD CLASSES API
//   // =====================================================

//   Future<void> fetchChildClasses() async {
//     if (!mounted) return;

//     setState(() {
//       isLoading = true;
//     });

//     try {
//       final response = await ApiClient.get(
//         '/api/Parent/child-classes/${widget.studentId}/${widget.courseId}',
//       );

//       debugPrint('CHILD CLASSES STATUS: ${response.statusCode}');
//       debugPrint('CHILD CLASSES BODY: ${response.body}');

//       if (response.statusCode == 200) {
//         final decodedData = jsonDecode(
//           utf8.decode(response.bodyBytes),
//         );

//         List<dynamic> result = [];

//         // Direct list response
//         if (decodedData is List) {
//           result = List<dynamic>.from(decodedData);
//         }

//         // Object response
//         else if (decodedData is Map<String, dynamic>) {
//           if (decodedData['classes'] is List) {
//             result = List<dynamic>.from(decodedData['classes']);
//           } else if (decodedData['data'] is List) {
//             result = List<dynamic>.from(decodedData['data']);
//           } else if (decodedData['result'] is List) {
//             result = List<dynamic>.from(decodedData['result']);
//           }
//         }

//         // Filter by selected course
//         result = result.where((item) {
//           if (item is! Map) return false;

//           final itemCourseId =
//               item['courseId'] ?? item['course_id'];

//           if (itemCourseId == null) return false;

//           return itemCourseId.toString().trim() ==
//               widget.courseId.toString();
//         }).toList();

//         // Only accepted / active classes
//         result = result.where((item) {
//           if (item is! Map) return false;

//           final status = (item['status'] ?? '')
//               .toString()
//               .trim()
//               .toLowerCase();

//           return status == 'accepted' || status == 'active';
//         }).toList();

//         // Sort classes by day
//         result.sort((a, b) {
//           final dayA = _getDayIndex(
//             _getItemValue(a, ['day']),
//           );

//           final dayB = _getDayIndex(
//             _getItemValue(b, ['day']),
//           );

//           return dayA.compareTo(dayB);
//         });

//         if (!mounted) return;

//         setState(() {
//           classesList = result;
//           isLoading = false;
//         });
//       } else {
//         if (!mounted) return;

//         setState(() {
//           classesList = [];
//           isLoading = false;
//         });

//         _showSnackBar('Failed to load class sessions.');
//       }
//     } catch (e) {
//       debugPrint('CHILD CLASSES ERROR: $e');

//       if (!mounted) return;

//       setState(() {
//         classesList = [];
//         isLoading = false;
//       });

//       _showSnackBar('An error occurred while loading classes.');
//     }
//   }

//   // =====================================================
//   // SAFE VALUE FROM API
//   // =====================================================

//   String _getItemValue(dynamic item, List<String> keys) {
//     if (item is! Map) return '';

//     for (final key in keys) {
//       final value = item[key];

//       if (value != null && value.toString().trim().isNotEmpty) {
//         return value.toString().trim();
//       }
//     }

//     return '';
//   }

//   // =====================================================
//   // GET DAY INDEX
//   // =====================================================

//   int _getDayIndex(String day) {
//     switch (day.toLowerCase().trim()) {
//       case 'monday':
//       case 'mon':
//         return 1;
//       case 'tuesday':
//       case 'tue':
//       case 'tues':
//         return 2;
//       case 'wednesday':
//       case 'wed':
//         return 3;
//       case 'thursday':
//       case 'thu':
//       case 'thur':
//       case 'thurs':
//         return 4;
//       case 'friday':
//       case 'fri':
//         return 5;
//       case 'saturday':
//       case 'sat':
//         return 6;
//       case 'sunday':
//       case 'sun':
//         return 7;
//       default:
//         return 8;
//     }
//   }

//   // =====================================================
//   // FULL DAY NAME
//   // =====================================================

//   String _getFullDayName(String day) {
//     switch (day.toLowerCase().trim()) {
//       case 'monday':
//       case 'mon':
//         return 'Monday';
//       case 'tuesday':
//       case 'tue':
//       case 'tues':
//         return 'Tuesday';
//       case 'wednesday':
//       case 'wed':
//         return 'Wednesday';
//       case 'thursday':
//       case 'thu':
//       case 'thur':
//       case 'thurs':
//         return 'Thursday';
//       case 'friday':
//       case 'fri':
//         return 'Friday';
//       case 'saturday':
//       case 'sat':
//         return 'Saturday';
//       case 'sunday':
//       case 'sun':
//         return 'Sunday';
//       default:
//         return day.isEmpty ? 'Day Not Available' : day;
//     }
//   }

//   // =====================================================
//   // EXTRACT START HOUR
//   // =====================================================

//   int? _extractStartHour(String time) {
//     if (time.isEmpty) return null;

//     final match = RegExp(
//       r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
//       caseSensitive: false,
//     ).firstMatch(time);

//     if (match == null) return null;

//     int? hour = int.tryParse(match.group(1) ?? '');

//     if (hour == null) return null;

//     final meridiem = match.group(3)?.toLowerCase();

//     if (meridiem == 'pm' && hour != 12) {
//       hour += 12;
//     } else if (meridiem == 'am' && hour == 12) {
//       hour = 0;
//     }

//     return hour;
//   }

//   // =====================================================
//   // REFRESH
//   // =====================================================

//   Future<void> refreshClasses() async {
//     await fetchChildClasses();
//   }

//   // =====================================================
//   // SNACKBAR
//   // =====================================================

//   void _showSnackBar(String message) {
//     if (!mounted) return;

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         behavior: SnackBarBehavior.floating,
//         backgroundColor: textColor,
//       ),
//     );
//   }

//   // =====================================================
//   // PROFILE HEADER
//   // =====================================================

//   Widget _buildProfileHeader() {
//     final firstItem = classesList.isNotEmpty
//         ? classesList.first
//         : null;

//     final studentName = _getItemValue(
//       firstItem,
//       ['studentName', 'student_name', 'childName', 'child_name'],
//     );

//     final studentEmail = _getItemValue(
//       firstItem,
//       ['studentEmail', 'student_email', 'childEmail', 'child_email'],
//     );

//     final studentPhone = _getItemValue(
//       firstItem,
//       ['studentPhone', 'student_phone', 'childPhone', 'child_phone'],
//     );

//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: const Color(0xFFE9EEEE)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.035),
//             blurRadius: 15,
//             offset: const Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 62,
//             height: 62,
//             decoration: BoxDecoration(
//               color: lightTeal,
//               borderRadius: BorderRadius.circular(18),
//             ),
//             child: const Icon(
//               Icons.person_rounded,
//               color: primaryColor,
//               size: 34,
//             ),
//           ),

//           const SizedBox(width: 15),

//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   studentName.isNotEmpty ? studentName : 'Student',
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     fontSize: 17,
//                     fontWeight: FontWeight.bold,
//                     color: textColor,
//                   ),
//                 ),

//                 const SizedBox(height: 7),

//                 if (studentEmail.isNotEmpty)
//                   _profileInfoRow(
//                     Icons.email_outlined,
//                     studentEmail,
//                   ),

//                 if (studentPhone.isNotEmpty) ...[
//                   const SizedBox(height: 5),
//                   _profileInfoRow(
//                     Icons.phone_outlined,
//                     studentPhone,
//                   ),
//                 ],

//                 if (studentEmail.isEmpty && studentPhone.isEmpty)
//                   const Text(
//                     'Student Profile',
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.grey,
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _profileInfoRow(IconData icon, String value) {
//     return Row(
//       children: [
//         Icon(
//           icon,
//           size: 14,
//           color: Colors.grey.shade500,
//         ),
//         const SizedBox(width: 6),
//         Expanded(
//           child: Text(
//             value,
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//               fontSize: 11,
//               color: Colors.grey.shade700,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   // =====================================================
//   // WEEKLY SCHEDULE - NO HORIZONTAL SCROLLING
//   // =====================================================

//   Widget _buildTimetableGrid() {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(17),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: const Color(0xFFE9EEEE)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.035),
//             blurRadius: 15,
//             offset: const Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   color: lightTeal,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: const Icon(
//                   Icons.calendar_month_rounded,
//                   color: primaryColor,
//                   size: 22,
//                 ),
//               ),

//               const SizedBox(width: 12),

//               const Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Weekly Schedule',
//                       style: TextStyle(
//                         fontSize: 17,
//                         fontWeight: FontWeight.bold,
//                         color: textColor,
//                       ),
//                     ),
//                     SizedBox(height: 3),
//                     Text(
//                       'Your child’s weekly class timings',
//                       style: TextStyle(
//                         fontSize: 11,
//                         color: Colors.grey,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 10,
//                   vertical: 7,
//                 ),
//                 decoration: BoxDecoration(
//                   color: lightTeal,
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: const Row(
//                   children: [
//                     Icon(
//                       Icons.circle,
//                       color: primaryColor,
//                       size: 8,
//                     ),
//                     SizedBox(width: 5),
//                     Text(
//                       'Active',
//                       style: TextStyle(
//                         color: primaryColor,
//                         fontSize: 11,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),

//           const SizedBox(height: 18),

//           // All seven days are displayed vertically
//           ...List.generate(7, (dayIndex) {
//             final dayNumber = dayIndex + 1;
//             final dayName = weekDays[dayIndex];
//             final shortName = weekDaysShort[dayIndex];

//             final dayClasses = classesList.where((item) {
//               if (item is! Map) return false;

//               return _getDayIndex(
//                     _getItemValue(item, ['day']),
//                   ) ==
//                   dayNumber;
//             }).toList();

//             final classTimes = <String>[];

//             for (final item in dayClasses) {
//               final time = _getItemValue(
//                 item,
//                 ['time', 'classTime', 'class_time'],
//               );

//               if (time.isNotEmpty && !classTimes.contains(time)) {
//                 classTimes.add(time);
//               }
//             }

//             classTimes.sort((a, b) {
//               return (_extractStartHour(a) ?? 0)
//                   .compareTo(_extractStartHour(b) ?? 0);
//             });

//             final hasClass = classTimes.isNotEmpty;

//             return Container(
//               margin: EdgeInsets.only(
//                 bottom: dayIndex == 6 ? 0 : 9,
//               ),
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: hasClass
//                     ? const Color(0xFFF0F8F6)
//                     : const Color(0xFFFAFBFC),
//                 borderRadius: BorderRadius.circular(14),
//                 border: Border.all(
//                   color: hasClass
//                       ? const Color(0xFFD5EAE4)
//                       : const Color(0xFFEDF0F2),
//                 ),
//               ),
//               child: Row(
//                 children: [
//                   Container(
//                     width: 44,
//                     height: 44,
//                     alignment: Alignment.center,
//                     decoration: BoxDecoration(
//                       color: hasClass
//                           ? primaryColor
//                           : const Color(0xFFECEFF1),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Text(
//                       shortName,
//                       style: TextStyle(
//                         fontSize: 11,
//                         fontWeight: FontWeight.bold,
//                         color: hasClass
//                             ? Colors.white
//                             : Colors.grey.shade600,
//                       ),
//                     ),
//                   ),

//                   const SizedBox(width: 12),

//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           dayName,
//                           style: const TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w700,
//                             color: textColor,
//                           ),
//                         ),

//                         const SizedBox(height: 7),

//                         if (hasClass)
//                           Wrap(
//                             spacing: 6,
//                             runSpacing: 6,
//                             children: classTimes.map((time) {
//                               return Container(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 9,
//                                   vertical: 6,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   color: Colors.white,
//                                   borderRadius: BorderRadius.circular(8),
//                                   border: Border.all(
//                                     color: const Color(0xFFB9DED4),
//                                   ),
//                                 ),
//                                 child: Row(
//                                   mainAxisSize: MainAxisSize.min,
//                                   children: [
//                                     const Icon(
//                                       Icons.access_time_rounded,
//                                       size: 12,
//                                       color: primaryColor,
//                                     ),
//                                     const SizedBox(width: 5),
//                                     Text(
//                                       time,
//                                       style: const TextStyle(
//                                         fontSize: 10,
//                                         fontWeight: FontWeight.w600,
//                                         color: primaryColor,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               );
//                             }).toList(),
//                           )
//                         else
//                           Text(
//                             'No class scheduled',
//                             style: TextStyle(
//                               fontSize: 11,
//                               color: Colors.grey.shade500,
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),

//                   Icon(
//                     hasClass
//                         ? Icons.check_circle_rounded
//                         : Icons.remove_circle_outline,
//                     size: 18,
//                     color: hasClass
//                         ? primaryColor
//                         : Colors.grey.shade400,
//                   ),
//                 ],
//               ),
//             );
//           }),
//         ],
//       ),
//     );
//   }

//   // =====================================================
//   // CLASS DETAIL CARD
//   // =====================================================

//   Widget _buildClassCard(dynamic item) {
//     if (item is! Map) return const SizedBox.shrink();

//     final courseName = _getItemValue(
//       item,
//       ['courseName', 'course_name', 'course'],
//     );

//     final finalCourseName = courseName.isNotEmpty
//         ? courseName
//         : widget.courseTitle;

//     final tutorName = _getItemValue(
//       item,
//       ['tutorName', 'tutor_name', 'instructor'],
//     );

//     final tutorEmail = _getItemValue(
//       item,
//       ['tutorEmail', 'tutor_email', 'email'],
//     );

//     final tutorPhone = _getItemValue(
//       item,
//       ['tutorPhone', 'tutor_phone', 'phone'],
//     );

//     final day = _getItemValue(item, ['day']);
//     final fullDay = _getFullDayName(day);

//     final time = _getItemValue(
//       item,
//       ['time', 'classTime', 'class_time'],
//     );

//     final classDate = _formatDate(
//       item['classDate'] ?? item['class_date'],
//     );

//     return Container(
//       margin: const EdgeInsets.only(bottom: 13),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(
//           color: const Color(0xFFE9EEEE),
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.03),
//             blurRadius: 12,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Course heading and status
//           Row(
//             children: [
//               Container(
//                 width: 42,
//                 height: 42,
//                 decoration: BoxDecoration(
//                   color: lightTeal,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: const Icon(
//                   Icons.menu_book_rounded,
//                   color: primaryColor,
//                   size: 22,
//                 ),
//               ),

//               const SizedBox(width: 11),

//               Expanded(
//                 child: Text(
//                   finalCourseName,
//                   style: const TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.bold,
//                     color: textColor,
//                   ),
//                 ),
//               ),

//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 10,
//                   vertical: 6,
//                 ),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFEAF6EE),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: const Text(
//                   'Active',
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                     color: Color(0xFF299653),
//                   ),
//                 ),
//               ),
//             ],
//           ),

//           const SizedBox(height: 15),

//           const Divider(
//             height: 1,
//             color: Color(0xFFEDF0F2),
//           ),

//           const SizedBox(height: 14),

//           // Tutor details
//           Row(
//             children: [
//               Container(
//                 width: 38,
//                 height: 38,
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFF1F0F8),
//                   borderRadius: BorderRadius.circular(11),
//                 ),
//                 child: const Icon(
//                   Icons.person_outline_rounded,
//                   color: Color(0xFF6A1B9A),
//                   size: 21,
//                 ),
//               ),

//               const SizedBox(width: 10),

//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       tutorName.isNotEmpty
//                           ? tutorName
//                           : 'Unknown Instructor',
//                       style: const TextStyle(
//                         fontSize: 13,
//                         fontWeight: FontWeight.bold,
//                         color: textColor,
//                       ),
//                     ),
//                     const SizedBox(height: 3),
//                     const Text(
//                       'Assigned Instructor',
//                       style: TextStyle(
//                         fontSize: 10,
//                         color: Colors.grey,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),

//           if (tutorEmail.isNotEmpty) ...[
//             const SizedBox(height: 12),
//             _detailRow(
//               Icons.email_outlined,
//               tutorEmail,
//             ),
//           ],

//           if (tutorPhone.isNotEmpty) ...[
//             const SizedBox(height: 9),
//             _detailRow(
//               Icons.phone_outlined,
//               tutorPhone,
//             ),
//           ],

//           const SizedBox(height: 15),

//           // Class schedule information
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: const Color(0xFFF6F8F9),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Column(
//               children: [
//                 _scheduleInfoRow(
//                   Icons.calendar_today_rounded,
//                   'Class Day',
//                   fullDay,
//                 ),

//                 const SizedBox(height: 12),

//                 _scheduleInfoRow(
//                   Icons.access_time_rounded,
//                   'Class Time',
//                   time.isNotEmpty ? time : 'Not Available',
//                 ),

//                 if (classDate != 'N/A') ...[
//                   const SizedBox(height: 12),
//                   _scheduleInfoRow(
//                     Icons.event_outlined,
//                     'Class Date',
//                     classDate,
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // =====================================================
//   // DETAIL ROW
//   // =====================================================

//   Widget _detailRow(IconData icon, String value) {
//     return Row(
//       children: [
//         Icon(
//           icon,
//           size: 15,
//           color: Colors.grey.shade500,
//         ),
//         const SizedBox(width: 9),
//         Expanded(
//           child: Text(
//             value,
//             style: TextStyle(
//               fontSize: 11,
//               color: Colors.grey.shade700,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   // =====================================================
//   // SCHEDULE INFORMATION ROW
//   // =====================================================

//   Widget _scheduleInfoRow(
//     IconData icon,
//     String title,
//     String value,
//   ) {
//     return Row(
//       children: [
//         Icon(
//           icon,
//           size: 16,
//           color: primaryColor,
//         ),

//         const SizedBox(width: 9),

//         Expanded(
//           child: Text(
//             title,
//             style: TextStyle(
//               fontSize: 11,
//               color: Colors.grey.shade600,
//             ),
//           ),
//         ),

//         Flexible(
//           child: Text(
//             value,
//             textAlign: TextAlign.end,
//             style: const TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//               color: textColor,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   // =====================================================
//   // FORMAT DATE
//   // =====================================================

//   String _formatDate(dynamic value) {
//     if (value == null) return 'N/A';

//     final date = value.toString().trim();

//     if (date.isEmpty) return 'N/A';

//     final parsedDate = DateTime.tryParse(date);

//     if (parsedDate == null) {
//       return date.split('T')[0];
//     }

//     const months = [
//       'Jan', 'Feb', 'Mar', 'Apr',
//       'May', 'Jun', 'Jul', 'Aug',
//       'Sep', 'Oct', 'Nov', 'Dec',
//     ];

//     return '${parsedDate.day} ${months[parsedDate.month - 1]} ${parsedDate.year}';
//   }

//   // =====================================================
//   // SECTION HEADING
//   // =====================================================

//   Widget _sectionHeading(String title, String subtitle) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           title,
//           style: const TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//             color: textColor,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           subtitle,
//           style: TextStyle(
//             fontSize: 12,
//             color: Colors.grey.shade600,
//           ),
//         ),
//       ],
//     );
//   }

//   // =====================================================
//   // EMPTY STATE
//   // =====================================================

//   Widget _buildEmptyState() {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.symmetric(
//         horizontal: 25,
//         vertical: 45,
//       ),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(
//           color: const Color(0xFFE9EEEE),
//         ),
//       ),
//       child: Column(
//         children: [
//           Container(
//             width: 75,
//             height: 75,
//             decoration: const BoxDecoration(
//               color: Color(0xFFF0F2F4),
//               shape: BoxShape.circle,
//             ),
//             child: Icon(
//               Icons.event_busy_rounded,
//               size: 36,
//               color: Colors.grey.shade400,
//             ),
//           ),

//           const SizedBox(height: 17),

//           const Text(
//             'No Active Classes',
//             style: TextStyle(
//               fontSize: 17,
//               fontWeight: FontWeight.bold,
//               color: textColor,
//             ),
//           ),

//           const SizedBox(height: 7),

//           Text(
//             'There are no active weekly classes available for ${widget.courseTitle}.',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontSize: 12,
//               height: 1.5,
//               color: Colors.grey.shade600,
//             ),
//           ),

//           const SizedBox(height: 18),

//           OutlinedButton.icon(
//             onPressed: refreshClasses,
//             icon: const Icon(Icons.refresh_rounded),
//             label: const Text('Refresh'),
//             style: OutlinedButton.styleFrom(
//               foregroundColor: primaryColor,
//               side: const BorderSide(color: primaryColor),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // =====================================================
//   // BUILD SCREEN
//   // =====================================================

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: backgroundColor,

//       // =================================================
//       // APP BAR
//       // =================================================

//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         scrolledUnderElevation: 0,

//         leading: IconButton(
//           icon: const Icon(
//             Icons.arrow_back_ios_new_rounded,
//             color: primaryColor,
//             size: 19,
//           ),
//           onPressed: () => Navigator.pop(context),
//         ),

//         title: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Image.asset(
//               'assets/logo.png',
//               height: 29,
//               errorBuilder: (context, error, stackTrace) {
//                 return const Icon(
//                   Icons.school_rounded,
//                   color: primaryColor,
//                   size: 27,
//                 );
//               },
//             ),

//             const SizedBox(width: 9),

//             const Text(
//               'House of Tutor',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: textColor,
//               ),
//             ),
//           ],
//         ),

//         centerTitle: true,

//         bottom: PreferredSize(
//           preferredSize: const Size.fromHeight(1),
//           child: Container(
//             height: 1,
//             color: const Color(0xFFEDF0F2),
//           ),
//         ),
//       ),

//       // =================================================
//       // BODY
//       // =================================================

//       body: RefreshIndicator(
//         color: primaryColor,
//         onRefresh: refreshClasses,

//         child: isLoading
//             ? const Center(
//                 child: CircularProgressIndicator(
//                   color: primaryColor,
//                 ),
//               )

//             : ListView(
//                 physics: const AlwaysScrollableScrollPhysics(),
//                 padding: const EdgeInsets.fromLTRB(
//                   16, 20, 16, 30,
//                 ),

//                 children: [
//                   // Course heading
//                   Text(
//                     widget.courseTitle,
//                     style: const TextStyle(
//                       fontSize: 23,
//                       fontWeight: FontWeight.bold,
//                       color: textColor,
//                     ),
//                   ),

//                   const SizedBox(height: 5),

//                   Text(
//                     'View your child’s class schedule and instructor details.',
//                     style: TextStyle(
//                       fontSize: 12,
//                       height: 1.5,
//                       color: Colors.grey.shade600,
//                     ),
//                   ),

//                   const SizedBox(height: 20),

//                   if (classesList.isEmpty)
//                     _buildEmptyState()

//                   else ...[
//                     // Student profile
//                     _buildProfileHeader(),

//                     const SizedBox(height: 22),

//                     // Weekly schedule
//                     _buildTimetableGrid(),

//                     const SizedBox(height: 25),

//                     // Class details heading
//                     _sectionHeading(
//                       'Class Details',
//                       'Information about your child’s assigned classes',
//                     ),

//                     const SizedBox(height: 13),

//                     // All class cards
//                     ...classesList.map(
//                       (item) => _buildClassCard(item),
//                     ),
//                   ],
//                 ],
//               ),
//       ),
//     );
//   }
// }
















// // import 'dart:convert';

// // import 'package:flutter/material.dart';
// // import 'package:house_of_tutor/services/api_client.dart';

// // class ParentChildClasses extends StatefulWidget {
// //   final int studentId;
// //   final int courseId;
// //   final String courseTitle;

// //   const ParentChildClasses({
// //     Key? key,
// //     required this.studentId,
// //     required this.courseId,
// //     required this.courseTitle,
// //   }) : super(key: key);

// //   @override
// //   State<ParentChildClasses> createState() => _ParentChildClassesState();
// // }

// // class _ParentChildClassesState extends State<ParentChildClasses> {
// //   // =====================================================
// //   // VARIABLES
// //   // =====================================================

// //   List<dynamic> classesList = [];

// //   bool isLoading = true;

// //   // =====================================================
// //   // WEEK DAYS (full + short labels used by the grid)
// //   // =====================================================

// //   final List<String> weekDays = [
// //     "Monday",
// //     "Tuesday",
// //     "Wednesday",
// //     "Thursday",
// //     "Friday",
// //     "Saturday",
// //     "Sunday",
// //   ];

// //   final List<String> weekDaysShort = [
// //     "Mon",
// //     "Tue",
// //     "Wed",
// //     "Thu",
// //     "Fri",
// //     "Sat",
// //     "Sun",
// //   ];

// //   // =====================================================
// //   // TIME SLOTS FOR THE GRID (8:00 am -> 10:00 pm)
// //   // =====================================================

// //   final List<String> timeSlotLabels = [
// //     "8:00-9:00 am",
// //     "9:00-10:00 am",
// //     "10:00-11:00 am",
// //     "11:00-12:00 pm",
// //     "12:00-1:00 pm",
// //     "1:00-2:00 pm",
// //     "2:00-3:00 pm",
// //     "3:00-4:00 pm",
// //     "4:00-5:00 pm",
// //     "5:00-6:00 pm",
// //     "6:00-7:00 pm",
// //     "7:00-8:00 pm",
// //     "8:00-9:00 pm",
// //     "9:00-10:00 pm",
// //   ];

// //   static const int gridStartHour = 8; // 8 am
// //   static const int gridSlotCount = 14;

// //   // =====================================================
// //   // INIT
// //   // =====================================================

// //   @override
// //   void initState() {
// //     super.initState();

// //     fetchChildClasses();
// //   }

// //   // =====================================================
// //   // GET CHILD CLASSES API
// //   // =====================================================

// //   Future<void> fetchChildClasses() async {
// //     if (mounted) {
// //       setState(() {
// //         isLoading = true;
// //       });
// //     }

// //     try {
// //       final response = await ApiClient.get(
// //         '/api/Parent/child-classes/${widget.studentId}/${widget.courseId}',
// //       );

// //       debugPrint("========================================");
// //       debugPrint("CHILD CLASSES STATUS: ${response.statusCode}");
// //       debugPrint("CHILD CLASSES BODY: ${response.body}");
// //       debugPrint("========================================");

// //       if (response.statusCode == 200) {
// //         final decodedData = jsonDecode(
// //           utf8.decode(response.bodyBytes),
// //         );

// //         List<dynamic> result = [];

// //         // =====================================================
// //         // API RESPONSE IS DIRECT LIST
// //         // =====================================================

// //         if (decodedData is List) {
// //           result = List<dynamic>.from(decodedData);
// //         }

// //         // =====================================================
// //         // API RESPONSE IS OBJECT
// //         // =====================================================

// //         else if (decodedData is Map<String, dynamic>) {
// //           if (decodedData['classes'] is List) {
// //             result = List<dynamic>.from(
// //               decodedData['classes'],
// //             );
// //           } else if (decodedData['data'] is List) {
// //             result = List<dynamic>.from(
// //               decodedData['data'],
// //             );
// //           } else if (decodedData['result'] is List) {
// //             result = List<dynamic>.from(
// //               decodedData['result'],
// //             );
// //           }
// //         }

// //         debugPrint(
// //           "TOTAL CLASSES FROM API: ${result.length}",
// //         );

// //         // =====================================================
// //         // COURSE FILTER
// //         // =====================================================

// //         result = result.where((item) {
// //           if (item is! Map) {
// //             return false;
// //           }

// //           final itemCourseId =
// //               item['courseId'] ??
// //               item['course_id'];

// //           if (itemCourseId == null) {
// //             return false;
// //           }

// //           return itemCourseId.toString().trim() ==
// //               widget.courseId.toString().trim();
// //         }).toList();

// //         debugPrint(
// //           "AFTER COURSE FILTER: ${result.length}",
// //         );

// //         // =====================================================
// //         // STATUS FILTER (Accepted = Active for this screen)
// //         // =====================================================

// //         result = result.where((item) {
// //           if (item is! Map) {
// //             return false;
// //           }

// //           final status = (
// //             item['status'] ??
// //             ''
// //           ).toString().trim().toLowerCase();

// //           return status == "accepted" ||
// //               status == "active";
// //         }).toList();

// //         debugPrint(
// //           "AFTER STATUS FILTER: ${result.length}",
// //         );

// //         // =====================================================
// //         // SORT BY WEEK DAY
// //         // =====================================================

// //         result.sort((a, b) {
// //           final dayA = _getDayIndex(
// //             _getItemValue(a, ['day']),
// //           );

// //           final dayB = _getDayIndex(
// //             _getItemValue(b, ['day']),
// //           );

// //           return dayA.compareTo(dayB);
// //         });

// //         // =====================================================
// //         // SET DATA
// //         // =====================================================

// //         if (mounted) {
// //           setState(() {
// //             classesList = result;
// //             isLoading = false;
// //           });
// //         }

// //         debugPrint(
// //           "FINAL CLASSES TO DISPLAY: ${classesList.length}",
// //         );
// //       } else {
// //         if (mounted) {
// //           setState(() {
// //             isLoading = false;
// //             classesList = [];
// //           });

// //           String message = "Failed to load class sessions.";

// //           try {
// //             final data = jsonDecode(
// //               utf8.decode(response.bodyBytes),
// //             );

// //             if (data is Map<String, dynamic>) {
// //               message =
// //                   data['message']?.toString() ??
// //                   data['error']?.toString() ??
// //                   message;
// //             }
// //           } catch (_) {}

// //           _showSnackBar(message);
// //         }
// //       }
// //     } catch (e) {
// //       debugPrint("CHILD CLASSES ERROR: $e");

// //       if (mounted) {
// //         setState(() {
// //           isLoading = false;
// //           classesList = [];
// //         });

// //         _showSnackBar(
// //           "An error occurred while loading classes.",
// //         );
// //       }
// //     }
// //   }

// //   // =====================================================
// //   // SAFE MAP VALUE
// //   // =====================================================

// //   String _getItemValue(dynamic item, List<String> keys) {
// //     if (item is! Map) {
// //       return "";
// //     }

// //     for (final key in keys) {
// //       final value = item[key];

// //       if (value != null &&
// //           value.toString().trim().isNotEmpty) {
// //         return value.toString().trim();
// //       }
// //     }

// //     return "";
// //   }

// //   // =====================================================
// //   // GET DAY INDEX
// //   // =====================================================

// //   int _getDayIndex(String day) {
// //     final value = day.toLowerCase().trim();

// //     switch (value) {
// //       case "monday":
// //       case "mon":
// //         return 1;
// //       case "tuesday":
// //       case "tue":
// //       case "tues":
// //         return 2;
// //       case "wednesday":
// //       case "wed":
// //         return 3;
// //       case "thursday":
// //       case "thu":
// //       case "thur":
// //       case "thurs":
// //         return 4;
// //       case "friday":
// //       case "fri":
// //         return 5;
// //       case "saturday":
// //       case "sat":
// //         return 6;
// //       case "sunday":
// //       case "sun":
// //         return 7;
// //       default:
// //         return 8;
// //     }
// //   }

// //   // =====================================================
// //   // NORMALIZE DAY
// //   // =====================================================

// //   String _getFullDayName(String day) {
// //     final value = day.toLowerCase().trim();

// //     switch (value) {
// //       case "monday":
// //       case "mon":
// //         return "Monday";
// //       case "tuesday":
// //       case "tue":
// //       case "tues":
// //         return "Tuesday";
// //       case "wednesday":
// //       case "wed":
// //         return "Wednesday";
// //       case "thursday":
// //       case "thu":
// //       case "thur":
// //       case "thurs":
// //         return "Thursday";
// //       case "friday":
// //       case "fri":
// //         return "Friday";
// //       case "saturday":
// //       case "sat":
// //         return "Saturday";
// //       case "sunday":
// //       case "sun":
// //         return "Sunday";
// //       default:
// //         return day.isEmpty ? "Day Not Available" : day;
// //     }
// //   }

// //   // =====================================================
// //   // EXTRACT START HOUR FROM TIME STRING (for grid placement)
// //   // =====================================================
// //   //
// //   // Supports formats like:
// //   // "8:00 am", "08:00", "8:00-9:00 am", "20:00"
// //   //

// //   int? _extractStartHour(String time) {
// //     if (time.isEmpty) {
// //       return null;
// //     }

// //     final match = RegExp(
// //       r'(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)?',
// //     ).firstMatch(time);

// //     if (match == null) {
// //       return null;
// //     }

// //     int? hour = int.tryParse(match.group(1) ?? '');

// //     if (hour == null) {
// //       return null;
// //     }

// //     final meridiem = match.group(3)?.toLowerCase();

// //     if (meridiem == 'pm' && hour != 12) {
// //       hour += 12;
// //     } else if (meridiem == 'am' && hour == 12) {
// //       hour = 0;
// //     }

// //     return hour;
// //   }

// //   int? _getSlotIndex(String time) {
// //     final hour = _extractStartHour(time);

// //     if (hour == null) {
// //       return null;
// //     }

// //     final index = hour - gridStartHour;

// //     if (index < 0 || index >= gridSlotCount) {
// //       return null;
// //     }

// //     return index;
// //   }

// //   // =====================================================
// //   // REFRESH
// //   // =====================================================

// //   Future<void> refreshClasses() async {
// //     await fetchChildClasses();
// //   }

// //   // =====================================================
// //   // SNACKBAR
// //   // =====================================================

// //   void _showSnackBar(String message) {
// //     if (!mounted) return;

// //     ScaffoldMessenger.of(context).showSnackBar(
// //       SnackBar(content: Text(message)),
// //     );
// //   }

// //   // =====================================================
// //   // STUDENT (CHILD) PROFILE HEADER
// //   // =====================================================

// //   Widget _buildProfileHeader() {
// //     // Pull student info from the first class record (falls back
// //     // gracefully if the API doesn't include these fields).
// //     final firstItem = classesList.isNotEmpty ? classesList.first : null;

// //     final studentName = _getItemValue(
// //       firstItem,
// //       ['studentName', 'student_name', 'childName', 'child_name'],
// //     );

// //     final studentEmail = _getItemValue(
// //       firstItem,
// //       ['studentEmail', 'student_email', 'childEmail', 'child_email'],
// //     );

// //     final studentPhone = _getItemValue(
// //       firstItem,
// //       ['studentPhone', 'student_phone', 'childPhone', 'child_phone'],
// //     );

// //     return Container(
// //       width: double.infinity,
// //       padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(20),
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.grey.withOpacity(0.08),
// //             blurRadius: 10,
// //             offset: const Offset(0, 4),
// //           ),
// //         ],
// //       ),
// //       child: Column(
// //         children: [
// //           CircleAvatar(
// //             radius: 34,
// //             backgroundColor: Colors.teal.withOpacity(0.1),
// //             child: Icon(
// //               Icons.person,
// //               size: 36,
// //               color: Colors.teal.shade700,
// //             ),
// //           ),
// //           const SizedBox(height: 10),
// //           Text(
// //             studentName.isNotEmpty ? studentName : "Student",
// //             style: const TextStyle(
// //               fontSize: 17,
// //               fontWeight: FontWeight.bold,
// //               color: Colors.black87,
// //             ),
// //           ),
// //           const SizedBox(height: 8),
// //           if (studentEmail.isNotEmpty)
// //             _profileInfoRow(Icons.email_outlined, studentEmail),
// //           if (studentPhone.isNotEmpty) ...[
// //             const SizedBox(height: 4),
// //             _profileInfoRow(Icons.phone_outlined, studentPhone),
// //           ],
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _profileInfoRow(IconData icon, String value) {
// //     return Row(
// //       mainAxisSize: MainAxisSize.min,
// //       children: [
// //         Icon(icon, size: 14, color: Colors.grey.shade600),
// //         const SizedBox(width: 6),
// //         Text(
// //           value,
// //           style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
// //         ),
// //       ],
// //     );
// //   }

// //   // =====================================================
// //   // WEEKLY TIMETABLE GRID
// //   // =====================================================

// //   Widget _buildTimetableGrid() {
// //     const double timeColWidth = 92;
// //     const double dayColWidth = 52;
// //     const double rowHeight = 40;

// //     return Container(
// //       width: double.infinity,
// //       padding: const EdgeInsets.all(14),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(18),
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.grey.withOpacity(0.08),
// //             blurRadius: 10,
// //             offset: const Offset(0, 4),
// //           ),
// //         ],
// //       ),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           // ============================================
// //           // TITLE + LEGEND
// //           // ============================================
// //           Row(
// //             children: [
// //               const Expanded(
// //                 child: Text(
// //                   "Weekly Timetable",
// //                   style: TextStyle(
// //                     fontSize: 16,
// //                     fontWeight: FontWeight.bold,
// //                     color: Colors.black87,
// //                   ),
// //                 ),
// //               ),
// //               Container(
// //                 width: 8,
// //                 height: 8,
// //                 decoration: const BoxDecoration(
// //                   color: Colors.teal,
// //                   shape: BoxShape.circle,
// //                 ),
// //               ),
// //               const SizedBox(width: 5),
// //               Text(
// //                 "Active Class",
// //                 style: TextStyle(
// //                   fontSize: 11,
// //                   color: Colors.grey.shade600,
// //                   fontWeight: FontWeight.w500,
// //                 ),
// //               ),
// //             ],
// //           ),

// //           const SizedBox(height: 14),

// //           // ============================================
// //           // GRID: fixed time column + horizontally
// //           // scrollable day columns, sharing the same
// //           // vertical scroll so rows line up.
// //           // ============================================

// //           SizedBox(
// //             height: rowHeight * (gridSlotCount + 1) + 4,
// //             child: SingleChildScrollView(
// //               child: Row(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   // TIME LABEL COLUMN (fixed)
// //                   SizedBox(
// //                     width: timeColWidth,
// //                     child: Column(
// //                       children: [
// //                         SizedBox(height: rowHeight), // aligns with day header row
// //                         ...List.generate(gridSlotCount, (i) {
// //                           return SizedBox(
// //                             height: rowHeight,
// //                             child: Align(
// //                               alignment: Alignment.centerLeft,
// //                               child: Text(
// //                                 timeSlotLabels[i],
// //                                 style: TextStyle(
// //                                   fontSize: 10.5,
// //                                   color: Colors.grey.shade600,
// //                                 ),
// //                               ),
// //                             ),
// //                           );
// //                         }),
// //                       ],
// //                     ),
// //                   ),

// //                   // DAY COLUMNS (horizontally scrollable)
// //                   Expanded(
// //                     child: SingleChildScrollView(
// //                       scrollDirection: Axis.horizontal,
// //                       child: Column(
// //                         children: [
// //                           // DAY HEADER ROW
// //                           Row(
// //                             children: List.generate(7, (dayIdx) {
// //                               return SizedBox(
// //                                 width: dayColWidth,
// //                                 height: rowHeight,
// //                                 child: Center(
// //                                   child: Text(
// //                                     weekDaysShort[dayIdx],
// //                                     style: const TextStyle(
// //                                       fontSize: 11.5,
// //                                       fontWeight: FontWeight.bold,
// //                                       color: Colors.black87,
// //                                     ),
// //                                   ),
// //                                 ),
// //                               );
// //                             }),
// //                           ),

// //                           // SLOT ROWS
// //                           ...List.generate(gridSlotCount, (slotIdx) {
// //                             return Row(
// //                               children: List.generate(7, (dayIdx) {
// //                                 final hasClass = classesList.any((item) {
// //                                   if (item is! Map) return false;

// //                                   final itemDayIndex = _getDayIndex(
// //                                     _getItemValue(item, ['day']),
// //                                   );

// //                                   final itemSlot = _getSlotIndex(
// //                                     _getItemValue(
// //                                       item,
// //                                       ['time', 'classTime', 'class_time'],
// //                                     ),
// //                                   );

// //                                   return itemDayIndex == (dayIdx + 1) &&
// //                                       itemSlot == slotIdx;
// //                                 });

// //                                 return SizedBox(
// //                                   width: dayColWidth,
// //                                   height: rowHeight,
// //                                   child: Center(
// //                                     child: hasClass
// //                                         ? Container(
// //                                             width: 26,
// //                                             height: 26,
// //                                             decoration: BoxDecoration(
// //                                               color: Colors.teal.shade600,
// //                                               borderRadius:
// //                                                   BorderRadius.circular(7),
// //                                             ),
// //                                             child: const Icon(
// //                                               Icons.check,
// //                                               size: 16,
// //                                               color: Colors.white,
// //                                             ),
// //                                           )
// //                                         : Container(
// //                                             width: 26,
// //                                             height: 26,
// //                                             decoration: BoxDecoration(
// //                                               color: Colors.grey.shade100,
// //                                               borderRadius:
// //                                                   BorderRadius.circular(7),
// //                                             ),
// //                                           ),
// //                                   ),
// //                                 );
// //                               }),
// //                             );
// //                           }),
// //                         ],
// //                       ),
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   // =====================================================
// //   // CLASS DETAIL CARD (kept for full tutor/course info)
// //   // =====================================================

// //   Widget _buildClassCard(dynamic item) {
// //     if (item is! Map) {
// //       return const SizedBox.shrink();
// //     }

// //     final courseName = _getItemValue(
// //       item,
// //       ['courseName', 'course_name', 'course'],
// //     );

// //     final finalCourseName =
// //         courseName.isNotEmpty ? courseName : widget.courseTitle;

// //     final tutorName = _getItemValue(
// //       item,
// //       ['tutorName', 'tutor_name', 'instructor'],
// //     );

// //     final finalTutorName =
// //         tutorName.isNotEmpty ? tutorName : 'Unknown Instructor';

// //     final tutorEmail = _getItemValue(
// //       item,
// //       ['tutorEmail', 'tutor_email', 'email'],
// //     );

// //     final finalTutorEmail =
// //         tutorEmail.isNotEmpty ? tutorEmail : 'Not Available';

// //     final tutorPhone = _getItemValue(
// //       item,
// //       ['tutorPhone', 'tutor_phone', 'phone'],
// //     );

// //     final finalTutorPhone =
// //         tutorPhone.isNotEmpty ? tutorPhone : 'Not Available';

// //     final day = _getItemValue(item, ['day']);
// //     final fullDay = _getFullDayName(day);

// //     final time = _getItemValue(
// //       item,
// //       ['time', 'classTime', 'class_time'],
// //     );

// //     final finalTime = time.isNotEmpty ? time : 'N/A';

// //     final classDate = _formatDate(
// //       item['classDate'] ?? item['class_date'],
// //     );

// //     return Container(
// //       margin: const EdgeInsets.only(bottom: 14),
// //       padding: const EdgeInsets.all(16),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(16),
// //         border: Border.all(color: Colors.grey.shade200),
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.grey.withOpacity(0.08),
// //             blurRadius: 8,
// //             offset: const Offset(0, 4),
// //           ),
// //         ],
// //       ),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Row(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               Expanded(
// //                 child: Row(
// //                   children: [
// //                     Icon(Icons.menu_book, color: Colors.teal.shade700, size: 20),
// //                     const SizedBox(width: 8),
// //                     Expanded(
// //                       child: Text(
// //                         finalCourseName,
// //                         style: const TextStyle(
// //                           fontSize: 16,
// //                           fontWeight: FontWeight.bold,
// //                           color: Colors.black87,
// //                         ),
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //               const SizedBox(width: 8),
// //               Container(
// //                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
// //                 decoration: BoxDecoration(
// //                   color: Colors.green.withOpacity(0.1),
// //                   borderRadius: BorderRadius.circular(12),
// //                 ),
// //                 child: const Text(
// //                   "Active",
// //                   style: TextStyle(
// //                     color: Colors.green,
// //                     fontSize: 11,
// //                     fontWeight: FontWeight.bold,
// //                   ),
// //                 ),
// //               ),
// //             ],
// //           ),

// //           const SizedBox(height: 12),

// //           Container(
// //             width: double.infinity,
// //             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
// //             decoration: BoxDecoration(
// //               color: Colors.teal.withOpacity(0.08),
// //               borderRadius: BorderRadius.circular(10),
// //             ),
// //             child: Row(
// //               children: [
// //                 Icon(Icons.calendar_month, size: 18, color: Colors.teal.shade700),
// //                 const SizedBox(width: 8),
// //                 const Text(
// //                   "Weekly Class:",
// //                   style: TextStyle(
// //                     fontSize: 12,
// //                     color: Colors.grey,
// //                     fontWeight: FontWeight.w500,
// //                   ),
// //                 ),
// //                 const SizedBox(width: 6),
// //                 Expanded(
// //                   child: Text(
// //                     fullDay,
// //                     style: TextStyle(
// //                       fontSize: 14,
// //                       fontWeight: FontWeight.bold,
// //                       color: Colors.teal.shade800,
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),

// //           const SizedBox(height: 12),

// //           Container(
// //             width: double.infinity,
// //             padding: const EdgeInsets.all(12),
// //             decoration: BoxDecoration(
// //               color: Colors.grey.shade50,
// //               borderRadius: BorderRadius.circular(12),
// //               border: Border.all(color: Colors.grey.shade200),
// //             ),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 Row(
// //                   children: [
// //                     Icon(Icons.person_outline, size: 18, color: Colors.grey.shade700),
// //                     const SizedBox(width: 8),
// //                     Expanded(
// //                       child: Column(
// //                         crossAxisAlignment: CrossAxisAlignment.start,
// //                         children: [
// //                           Text(
// //                             finalTutorName,
// //                             style: const TextStyle(
// //                               fontSize: 14,
// //                               fontWeight: FontWeight.bold,
// //                               color: Colors.black87,
// //                             ),
// //                           ),
// //                           const Text(
// //                             "Assigned Instructor",
// //                             style: TextStyle(fontSize: 11, color: Colors.grey),
// //                           ),
// //                         ],
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //                 const SizedBox(height: 8),
// //                 Row(
// //                   children: [
// //                     Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade600),
// //                     const SizedBox(width: 6),
// //                     Expanded(
// //                       child: Text(
// //                         finalTutorEmail,
// //                         style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
// //                         overflow: TextOverflow.ellipsis,
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //                 const SizedBox(height: 4),
// //                 Row(
// //                   children: [
// //                     Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
// //                     const SizedBox(width: 6),
// //                     Expanded(
// //                       child: Text(
// //                         finalTutorPhone,
// //                         style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ],
// //             ),
// //           ),

// //           const SizedBox(height: 12),

// //           _infoItem(icon: Icons.access_time, title: "Class Time", value: finalTime),

// //           if (classDate != "N/A") ...[
// //             const SizedBox(height: 10),
// //             _infoItem(icon: Icons.event_outlined, title: "Class Date", value: classDate),
// //           ],
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _infoItem({
// //     required IconData icon,
// //     required String title,
// //     required String value,
// //   }) {
// //     return Row(
// //       crossAxisAlignment: CrossAxisAlignment.start,
// //       children: [
// //         Icon(icon, size: 16, color: Colors.grey.shade600),
// //         const SizedBox(width: 6),
// //         Expanded(
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
// //               const SizedBox(height: 2),
// //               Text(
// //                 value,
// //                 style: const TextStyle(
// //                   fontSize: 12,
// //                   fontWeight: FontWeight.bold,
// //                   color: Colors.black87,
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ],
// //     );
// //   }

// //   String _formatDate(dynamic value) {
// //     if (value == null) return "N/A";

// //     final date = value.toString().trim();

// //     if (date.isEmpty) return "N/A";

// //     return date.split('T')[0];
// //   }

// //   // =====================================================
// //   // BUILD
// //   // =====================================================

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: const Color(0xFFF8F9FA),

// //       appBar: AppBar(
// //         backgroundColor: Colors.white,
// //         elevation: 0,
// //         leading: IconButton(
// //           icon: const Icon(Icons.arrow_back, color: Colors.teal),
// //           onPressed: () => Navigator.of(context).pop(),
// //         ),
// //         title: Row(
// //           mainAxisSize: MainAxisSize.min,
// //           children: [
// //             Image.asset(
// //               'assets/logo.png',
// //               height: 24,
// //               errorBuilder: (context, error, stackTrace) {
// //                 return const Icon(Icons.school, color: Colors.teal, size: 24);
// //               },
// //             ),
// //             const SizedBox(width: 8),
// //             const Text(
// //               "House of Tutor",
// //               style: TextStyle(
// //                 color: Colors.black87,
// //                 fontSize: 14,
// //                 fontWeight: FontWeight.bold,
// //               ),
// //             ),
// //           ],
// //         ),
// //         centerTitle: true,
// //       ),

// //       body: RefreshIndicator(
// //         color: Colors.teal,
// //         onRefresh: refreshClasses,
// //         child: isLoading
// //             ? const Center(
// //                 child: CircularProgressIndicator(color: Colors.teal),
// //               )
// //             : ListView(
// //                 physics: const AlwaysScrollableScrollPhysics(),
// //                 padding: const EdgeInsets.all(16),
// //                 children: [
// //                   Text(
// //                     widget.courseTitle,
// //                     style: const TextStyle(
// //                       fontSize: 22,
// //                       fontWeight: FontWeight.bold,
// //                       color: Colors.black87,
// //                     ),
// //                   ),
// //                   const SizedBox(height: 4),
// //                   const Text(
// //                     "Weekly active class schedule",
// //                     style: TextStyle(fontSize: 13, color: Colors.grey),
// //                   ),
// //                   const SizedBox(height: 16),

// //                   if (classesList.isEmpty)
// //                     Padding(
// //                       padding: const EdgeInsets.symmetric(vertical: 80),
// //                       child: Column(
// //                         mainAxisAlignment: MainAxisAlignment.center,
// //                         children: [
// //                           Icon(Icons.event_busy, size: 55, color: Colors.grey.shade400),
// //                           const SizedBox(height: 15),
// //                           Text(
// //                             "No active classes found",
// //                             style: TextStyle(
// //                               color: Colors.grey.shade600,
// //                               fontSize: 15,
// //                               fontWeight: FontWeight.w500,
// //                             ),
// //                           ),
// //                           const SizedBox(height: 5),
// //                           Text(
// //                             "No active weekly class is available for this course.",
// //                             textAlign: TextAlign.center,
// //                             style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
// //                           ),
// //                         ],
// //                       ),
// //                     )
// //                   else ...[
// //                     _buildProfileHeader(),
// //                     const SizedBox(height: 16),
// //                     _buildTimetableGrid(),
// //                     const SizedBox(height: 20),
// //                     const Text(
// //                       "Class Details",
// //                       style: TextStyle(
// //                         fontSize: 15,
// //                         fontWeight: FontWeight.bold,
// //                         color: Colors.black87,
// //                       ),
// //                     ),
// //                     const SizedBox(height: 10),
// //                     ...classesList.map((item) => _buildClassCard(item)),
// //                   ],
// //                 ],
// //               ),
// //       ),
// //     );
// //   }
// // }