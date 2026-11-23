
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:house_of_tutor/StudentAddCourses.dart';
import 'package:house_of_tutor/StudentAllClasses.dart';
import 'package:house_of_tutor/StudentCourses.dart';
import 'package:house_of_tutor/StudentDrawer.dart';
import 'package:house_of_tutor/StudentNotfications.dart';
import 'package:house_of_tutor/services/api_client.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {

  // ================= BASIC VARIABLES =================

  final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  int selectedIndex = 0;

  bool loading = true;
  bool saving = false;

  bool isSpecificTime = false;

  DateTime? startDate;
  DateTime? endDate;

  // ================= DAYS =================

  final List<String> days = [
    "Mon",
    "Tue",
    "Wed",
    "Thu",
    "Fri",
    "Sat",
    "Sun",
  ];

  // ================= TIMES =================

  final List<String> times = [
    '8:00-9:00 am',
    '9:00-10:00 am',
    '10:00-11:00 am',
    '11:00-12:00 pm',
    '12:00-1:00 pm',
    '1:00-2:00 pm',
    '2:00-3:00 pm',
    '3:00-4:00 pm',
    '4:00-5:00 pm',
    '5:00-6:00 pm',
    '6:00-7:00 pm',
    '7:00-8:00 pm',
    '8:00-9:00 pm',
    '9:00-10:00 pm',
  ];

  static const List<String> _months = [
    "Jan", "Feb", "Mar", "Apr",
    "May", "Jun", "Jul", "Aug",
    "Sep", "Oct", "Nov", "Dec",
  ];

  // Selected schedule slots
  // Example: Mon_8:00-9:00 am

  final Map<String, bool> selectedSlots = {};

  // ================= LAYOUT SIZES =================

  static const double timeColWidth = 58;
  static const double cellHeight = 42;

  @override
  void initState() {
    super.initState();
    fetchSchedule();
  }

  // ================= SHOW MESSAGE =================

  void _msg(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  // ================= DATE FORMAT =================

  String _showDate(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')} "
        "${_months[d.month - 1]} ${d.year}";
  }

  // Backend DateOnly format: yyyy-MM-dd

  String _apiDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');

    return "${d.year}-$m-$day";
  }

  // ================= FETCH SCHEDULE API =================

  Future<void> fetchSchedule() async {

    setState(() {
      loading = true;
    });

    try {

      final response = await ApiClient.get(
        "/api/Student/get-student-schedules",
      );

      if (response.statusCode == 200) {

        final data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        selectedSlots.clear();

        if (data != null && data is List && data.isNotEmpty) {

          final first = data.first;

          isSpecificTime = first["type"] == "Specific Time";

          if (first["startDate"] != null) {
            startDate = DateTime.parse(first["startDate"]);
          } else {
            startDate = null;
          }

          if (first["endDate"] != null) {
            endDate = DateTime.parse(first["endDate"]);
          } else {
            endDate = null;
          }

          for (var item in data) {

            final key = "${item["day"]}_${item["time"]}";

            selectedSlots[key] = true;
          }

        } else {

          selectedSlots.clear();
          startDate = null;
          endDate = null;
        }
      }

    } catch (e) {

      _msg(e.toString());
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  // ================= SAVE SCHEDULE API =================

  Future<void> saveSchedule() async {

    if (selectedSlots.isEmpty) {
      _msg("Please select schedule slots");
      return;
    }

    if (isSpecificTime &&
        (startDate == null || endDate == null)) {

      _msg("Please select start and end date");
      return;
    }

    setState(() {
      saving = true;
    });

    try {

      final List<Map<String, dynamic>> slots = [];

      selectedSlots.forEach((key, value) {

        if (value) {

          final index = key.indexOf("_");

          slots.add({
            "day": key.substring(0, index),
            "time": key.substring(index + 1),
          });
        }
      });

      final body = {

        "availabilityType":
            isSpecificTime ? "specific" : "full",

        "startDate":
            isSpecificTime && startDate != null
                ? _apiDate(startDate!)
                : null,

        "endDate":
            isSpecificTime && endDate != null
                ? _apiDate(endDate!)
                : null,

        "slots": slots,
      };

      final response = await ApiClient.post(
        "/api/Student/save-student-schedule",
        body,
      );

      if (response.statusCode == 200) {

        _msg("Schedule Saved Successfully");

        await fetchSchedule();

      } else {

        String message = "Save Failed";

        try {

          final data = jsonDecode(response.body);

          message = data["message"] ?? message;

        } catch (_) {}

        _msg(message);
      }

    } catch (e) {

      _msg(e.toString());
    }

    if (!mounted) return;

    setState(() {
      saving = false;
    });
  }

  // ================= DATE PICKER =================

  Future<void> pickDate(bool isStart) async {

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    DateTime first = isStart
        ? today
        : (startDate ?? today);

    final DateTime initial =
        (isStart ? startDate : endDate) ?? first;

    // Allow already saved past dates

    if (initial.isBefore(first)) {
      first = initial;
    }

    final picked = await showDatePicker(

      context: context,

      initialDate: initial,

      firstDate: first,

      lastDate: DateTime(2035),
    );

    if (picked == null) return;

    setState(() {

      if (isStart) {

        startDate = picked;

        if (endDate != null &&
            endDate!.isBefore(picked)) {

          endDate = null;
        }

      } else {

        endDate = picked;
      }
    });
  }

  // ================= SELECT WHOLE DAY =================

  void toggleDay(String day) {

    final allSelected = times.every(
      (t) => selectedSlots["${day}_$t"] == true,
    );

    setState(() {

      for (final t in times) {

        final key = "${day}_$t";

        if (allSelected) {

          selectedSlots.remove(key);

        } else {

          selectedSlots[key] = true;
        }
      }
    });
  }

  // ================= BOTTOM NAVIGATION =================

  void onTapBottom(int index) {

    setState(() {
      selectedIndex = index;
    });

    if (index == 1) {

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const StudentAddCourses(),
        ),
      );

    } else if (index == 2) {

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const StudentCourses(),
        ),
      );

    } else if (index == 3) {

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const StudentAllClasses(),
        ),
      );
    }
  }

  // ================= COMMON CARD =================

  Widget _card({
    required Widget child,
    EdgeInsets? padding,
  }) {

    return Container(

      width: double.infinity,

      padding: padding ?? const EdgeInsets.all(14),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: child,
    );
  }

  // ================= TYPE BUTTONS =================

  Widget _typeButton(
    String label,
    IconData icon,
    bool selected,
    bool value,
  ) {

    return Expanded(

      child: GestureDetector(

        onTap: () {

          setState(() {
            isSpecificTime = value;
          });
        },

        child: AnimatedContainer(

          duration: const Duration(milliseconds: 200),

          padding: const EdgeInsets.symmetric(vertical: 14),

          decoration: BoxDecoration(

            color: selected
                ? Colors.teal
                : Colors.transparent,

            borderRadius: BorderRadius.circular(12),
          ),

          child: Row(

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              Icon(
                icon,
                size: 18,
                color: selected
                    ? Colors.white
                    : Colors.grey.shade600,
              ),

              const SizedBox(width: 6),

              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= DATE TILE =================

  Widget _dateTile(
    String label,
    DateTime? date,
    bool isStart,
  ) {

    final hasDate = date != null;

    return Expanded(

      child: InkWell(

        borderRadius: BorderRadius.circular(14),

        onTap: () => pickDate(isStart),

        child: Container(

          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),

          decoration: BoxDecoration(

            color: Colors.white,

            borderRadius: BorderRadius.circular(14),

            border: Border.all(
              color: hasDate
                  ? Colors.teal
                  : Colors.grey.shade300,
            ),
          ),

          child: Row(

            children: [

              Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: hasDate
                    ? Colors.teal
                    : Colors.grey,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      hasDate
                          ? _showDate(date)
                          : "Select",

                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: hasDate
                            ? Colors.black87
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= TIME LABEL =================

  Widget _timeLabel(String time) {

    final parts = time.split(' ');

    final range = parts[0];

    final period = parts.length > 1
        ? parts[1].toUpperCase()
        : '';

    return SizedBox(

      width: timeColWidth,

      height: cellHeight,

      child: Padding(

        padding: const EdgeInsets.only(right: 3),

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Text(
              range,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),

            Text(
              period,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= SLOT CELL =================

  Widget _slotCell(
    String day,
    String time,
    double width,
  ) {

    final key = "${day}_$time";

    final selected = selectedSlots[key] ?? false;

    return GestureDetector(

      onTap: () {

        setState(() {

          if (selected) {

            selectedSlots.remove(key);

          } else {

            selectedSlots[key] = true;
          }
        });
      },

      child: SizedBox(

        height: cellHeight,

        child: AnimatedContainer(

          duration: const Duration(milliseconds: 150),

          margin: const EdgeInsets.all(2),

          decoration: BoxDecoration(

            color: selected
                ? Colors.teal
                : Colors.grey.shade100,

            borderRadius: BorderRadius.circular(7),

            border: Border.all(
              color: selected
                  ? Colors.teal
                  : Colors.grey.shade300,
              width: 0.8,
            ),
          ),

          child: selected
              ? const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  // ================= SCHEDULE GRID =================
  // All 7 days fit together.
  // No horizontal scrolling.

  Widget _scheduleGrid() {

    return _card(

      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 12,
      ),

      child: LayoutBuilder(

        builder: (context, constraints) {

          final double dayWidth =
              (constraints.maxWidth - timeColWidth) /
                  days.length;

          return Column(

            children: [

              // ================= DAYS HEADER =================

              Row(

                children: [

                  const SizedBox(width: timeColWidth),

                  ...days.map((day) {

                    final allSelected = times.every(
                      (t) => selectedSlots["${day}_$t"] == true,
                    );

                    return Expanded(

                      child: GestureDetector(

                        onTap: () => toggleDay(day),

                        child: SizedBox(

                          height: 36,

                          child: Center(

                            child: Container(

                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 4,
                              ),

                              decoration: BoxDecoration(

                                color: allSelected
                                    ? Colors.teal.withOpacity(0.15)
                                    : Colors.transparent,

                                borderRadius:
                                    BorderRadius.circular(8),
                              ),

                              child: Text(
                                day,

                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Colors.teal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),

              const SizedBox(height: 4),

              Divider(
                height: 1,
                color: Colors.grey.shade300,
              ),

              const SizedBox(height: 4),

              // ================= TIME ROWS =================

              ...times.map((time) {

                return Row(

                  children: [

                    // Time column

                    _timeLabel(time),

                    // Seven days in one row

                    ...days.map((day) {

                      return Expanded(

                        child: _slotCell(
                          day,
                          time,
                          dayWidth,
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }

  // ================= LEGEND =================

  Widget _legend() {

    Widget dot(Color color, String text) {

      return Row(

        mainAxisSize: MainAxisSize.min,

        children: [

          Container(

            width: 14,
            height: 14,

            decoration: BoxDecoration(

              color: color,

              borderRadius: BorderRadius.circular(4),

              border: Border.all(
                color: Colors.grey.shade300,
                width: 0.8,
              ),
            ),
          ),

          const SizedBox(width: 6),

          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      );
    }

    return Row(

      mainAxisAlignment: MainAxisAlignment.spaceBetween,

      children: [

        Row(

          children: [

            dot(Colors.teal, "Selected"),

            const SizedBox(width: 14),

            dot(Colors.grey.shade100, "Free"),
          ],
        ),

        Text(
          "${selectedSlots.length} slot(s)",

          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.teal,
          ),
        ),
      ],
    );
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      key: scaffoldKey,

      backgroundColor: const Color(0xfff5f6f8),

      // ================= APP BAR =================

      appBar: AppBar(

        backgroundColor: Colors.white,

        elevation: 1,

        leading: IconButton(

          icon: const Icon(
            Icons.menu,
            color: Colors.teal,
          ),

          onPressed: () {
            scaffoldKey.currentState!.openDrawer();
          },
        ),

        centerTitle: true,

        title: Column(

          children: [

            Image.asset(
              "assets/images/logo.png",
              height: 36,
            ),

            const Text(
              "House of Tutor",

              style: TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),

        actions: [

          IconButton(

            icon: const Icon(
              Icons.notifications,
              color: Colors.teal,
              size: 26,
            ),

            onPressed: () {

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const StudentNotifications(),
                ),
              );
            },
          ),
        ],
      ),

      drawer: const StudentDrawer(),

      // ================= BODY =================

      body: loading

          ? const Center(
              child: CircularProgressIndicator(),
            )

          : SingleChildScrollView(

              padding: const EdgeInsets.fromLTRB(
                14,
                16,
                14,
                24,
              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  const Text(
                    "Select Your Availability",

                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "Tap a slot to select it. Tap a day name to select the whole day.",

                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ================= TYPE BUTTONS =================

                  Container(

                    padding: const EdgeInsets.all(5),

                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(15),
                    ),

                    child: Row(

                      children: [

                        _typeButton(
                          "Specific Time",
                          Icons.date_range_rounded,
                          isSpecificTime,
                          true,
                        ),

                        const SizedBox(width: 6),

                        _typeButton(
                          "Full Time",
                          Icons.all_inclusive_rounded,
                          !isSpecificTime,
                          false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ================= DATES =================

                  if (isSpecificTime) ...[

                    Row(
                      children: [
                        _dateTile(
                          "Start date",
                          startDate,
                          true,
                        ),

                        const SizedBox(width: 10),

                        _dateTile(
                          "End date",
                          endDate,
                          false,
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                  ],

                  // ================= SCHEDULE GRID =================

                  _scheduleGrid(),

                  const SizedBox(height: 12),

                  // ================= LEGEND =================

                  _legend(),

                  const SizedBox(height: 20),

                  // ================= SAVE AND CLEAR =================

                  Row(

                    children: [

                      Expanded(

                        flex: 2,

                        child: ElevatedButton.icon(

                          style: ElevatedButton.styleFrom(

                            backgroundColor: Colors.teal,

                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),

                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                          ),

                          onPressed: saving
                              ? null
                              : saveSchedule,

                          icon: saving

                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )

                              : const Icon(
                                  Icons.save_rounded,
                                  color: Colors.white,
                                ),

                          label: Text(
                            saving ? "Saving..." : "Save",

                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(

                        child: OutlinedButton(

                          style: OutlinedButton.styleFrom(

                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),

                            side: const BorderSide(
                              color: Colors.teal,
                            ),

                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                          ),

                          onPressed: () {

                            setState(() {

                              selectedSlots.clear();

                              startDate = null;

                              endDate = null;
                            });
                          },

                          child: const Text(
                            "Clear",

                            style: TextStyle(
                              fontSize: 17,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

      // ================= BOTTOM NAVIGATION =================

      bottomNavigationBar: BottomNavigationBar(

        currentIndex: selectedIndex,

        type: BottomNavigationBarType.fixed,

        selectedItemColor: Colors.teal,

        unselectedItemColor: Colors.grey,

        onTap: onTapBottom,

        items: const [

          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: "Schedule",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.add_box),
            label: "Add Courses",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: "Request",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: "Classes",
          ),
        ],
      ),
    );
  }
}