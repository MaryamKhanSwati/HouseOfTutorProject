import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:house_of_tutor/TutorDrawer.dart';
import 'package:house_of_tutor/TutorStudentRequest.dart';
import 'package:house_of_tutor/TutorTodayClasses.dart';
import 'package:house_of_tutor/TutorAddSubject.dart';
import 'package:house_of_tutor/TutorNotification.dart'; // Notification screen
import 'package:house_of_tutor/services/api_client.dart';

class TutorHome extends StatefulWidget {
  const TutorHome({super.key});

  @override
  State<TutorHome> createState() => _TutorHomeState();
}

class _TutorHomeState extends State<TutorHome> {

  // =====================================================
  // COLORS
  // =====================================================

  static const Color primaryColor = Color(0xff1E8E7E);
  static const Color lightTeal = Color(0xffEAF5F2);
  static const Color backgroundColor = Color(0xffF7F9F8);
  static const Color textColor = Color(0xff263B38);
  static const Color greyColor = Color(0xff899592);

  // =====================================================
  // BASIC VARIABLES
  // =====================================================

  int selectedIndex = 0;

  bool isLoading = true;
  bool isSaving = false;

  // Notification count
  int notificationCount = 0;

  String teachType = "full";

  DateTime? startDate;
  DateTime? endDate;

  Set<String> selectedKeys = {};

  Map<String, dynamic> scheduleData = {};

  static const double timeColWidth = 57;
  static const double cellHeight = 42;

  // =====================================================
  // DAYS
  // =====================================================

  final List<String> days = [
    "Mon",
    "Tue",
    "Wed",
    "Thu",
    "Fri",
    "Sat",
    "Sun",
  ];

  // =====================================================
  // TIME SLOTS
  // =====================================================

  final List<String> times = [
    "8:00-9:00 am",
    "9:00-10:00 am",
    "10:00-11:00 am",
    "11:00-12:00 pm",
    "12:00-1:00 pm",
    "1:00-2:00 pm",
    "2:00-3:00 pm",
    "3:00-4:00 pm",
    "4:00-5:00 pm",
    "5:00-6:00 pm",
    "6:00-7:00 pm",
    "7:00-8:00 pm",
    "8:00-9:00 pm",
    "9:00-10:00 pm",
  ];

  static const List<String> months = [
    "Jan", "Feb", "Mar", "Apr",
    "May", "Jun", "Jul", "Aug",
    "Sep", "Oct", "Nov", "Dec",
  ];

  // =====================================================
  // INIT STATE
  // =====================================================

  @override
  void initState() {
    super.initState();

    loadSchedule();

    // Load pending notification count
    loadNotificationCount();
  }

  // =====================================================
  // LOAD NOTIFICATION COUNT API
  // GET: /api/Tutor/notification-badge-count
  // =====================================================

  Future<void> loadNotificationCount() async {
    try {
      final response = await ApiClient.get(
        "/api/Tutor/notification-badge-count",
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        if (!mounted) return;

        setState(() {
          notificationCount = int.tryParse(
                data["count"].toString(),
              ) ??
              0;
        });
      }
    } catch (e) {
      debugPrint("Notification count error: $e");
    }
  }

  // =====================================================
  // OPEN NOTIFICATION SCREEN
  // =====================================================

  Future<void> openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TutorNotification(),
      ),
    );

    // Refresh badge count when returning from notifications
    if (mounted) {
      loadNotificationCount();
    }
  }

  // =====================================================
  // NOTIFICATION ICON WITH BADGE
  // =====================================================

  Widget notificationButton() {
    return IconButton(
      onPressed: openNotifications,
      tooltip: "Notifications",
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: primaryColor,
            size: 27,
          ),

          // Show red badge only when count is greater than zero
          if (notificationCount > 0)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5,
                  ),
                ),
                constraints: const BoxConstraints(
                  minWidth: 17,
                  minHeight: 17,
                ),
                child: Text(
                  notificationCount > 99
                      ? "99+"
                      : notificationCount.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =====================================================
  // SHOW MESSAGE
  // =====================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: textColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // =====================================================
  // DATE FORMAT
  // =====================================================

  String showDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')} "
        "${months[date.month - 1]} ${date.year}";
  }

  String apiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return "${date.year}-$month-$day";
  }

  // =====================================================
  // GET SLOT STATUS
  // =====================================================

  String? getSlotStatus(String day, String time) {
    return scheduleData["${day}_$time"]?["slot_status"]
        ?.toString()
        .toLowerCase();
  }

  // =====================================================
  // LOAD SCHEDULE API
  // =====================================================

  Future<void> loadSchedule() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiClient.get(
        "/api/Tutor/get-schedule",
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        final List data = decoded is List ? decoded : [];

        selectedKeys.clear();
        scheduleData.clear();

        startDate = null;
        endDate = null;
        teachType = "full";

        for (var item in data) {
          final day = item["day"]?.toString() ?? "";
          final time = item["time"]?.toString() ?? "";

          final key = "${day}_$time";

          selectedKeys.add(key);
          scheduleData[key] = item;

          if (item["startDate"] != null) {
            startDate = DateTime.tryParse(
              item["startDate"].toString(),
            );
          }

          if (item["endDate"] != null) {
            endDate = DateTime.tryParse(
              item["endDate"].toString(),
            );
          }

          if (item["type"] != null) {
            final type = item["type"]
                .toString()
                .toLowerCase();

            if (type == "specific time" ||
                type == "specific") {
              teachType = "specific";
            } else if (type == "full time" ||
                type == "full") {
              teachType = "full";
            }
          }
        }
      } else {
        showMessage("Unable to load schedule");
      }
    } catch (e) {
      showMessage(e.toString());
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  // =====================================================
  // SELECT / UNSELECT SLOT
  // =====================================================

  void onSlotTap(String day, String time) {
    final key = "${day}_$time";

    final status = getSlotStatus(day, time);

    if (status == "red") {
      showMessage("This slot is already booked");
      return;
    }

    if (status == "yellow") {
      showMessage(
        "This slot has a pre/reschedule request",
      );
      return;
    }

    setState(() {
      if (selectedKeys.contains(key)) {
        selectedKeys.remove(key);
      } else {
        selectedKeys.add(key);
      }
    });
  }

  // =====================================================
  // SLOT COLORS
  // =====================================================

  Color getSlotColor(String day, String time) {
    final status = getSlotStatus(day, time);

    if (status == "red") {
      return const Color(0xffFCE9E9);
    }

    if (status == "yellow") {
      return const Color(0xffFFF4DE);
    }

    if (selectedKeys.contains("${day}_$time")) {
      return primaryColor;
    }

    return const Color(0xffF1F4F3);
  }

  Color getSlotBorder(String day, String time) {
    final status = getSlotStatus(day, time);

    if (status == "red") {
      return const Color(0xffF1C5C5);
    }

    if (status == "yellow") {
      return const Color(0xffF0D99F);
    }

    if (selectedKeys.contains("${day}_$time")) {
      return primaryColor;
    }

    return const Color(0xffE5EAE8);
  }

  // =====================================================
  // DATE PICKER
  // =====================================================

  Future<void> pickDate(bool isStart) async {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    DateTime firstDate = today;

    if (!isStart && startDate != null) {
      firstDate = startDate!;
    }

    final currentDate = isStart ? startDate : endDate;

    DateTime initialDate = currentDate ?? firstDate;

    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textColor,
            ),
          ),
          child: child!,
        );
      },
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

  // =====================================================
  // SELECT WHOLE DAY
  // =====================================================

  void toggleDay(String day) {
    final freeSlots = times.where((time) {
      final status = getSlotStatus(day, time);

      return status != "red" &&
          status != "yellow";
    }).toList();

    if (freeSlots.isEmpty) return;

    final allSelected = freeSlots.every(
      (time) => selectedKeys.contains("${day}_$time"),
    );

    setState(() {
      for (final time in freeSlots) {
        final key = "${day}_$time";

        if (allSelected) {
          selectedKeys.remove(key);
        } else {
          selectedKeys.add(key);
        }
      }
    });
  }

  // =====================================================
  // SAVE SCHEDULE API
  // =====================================================

  Future<void> saveSchedule() async {
    if (selectedKeys.isEmpty) {
      showMessage("Please select at least one slot");
      return;
    }

    if (teachType == "specific") {
      if (startDate == null || endDate == null) {
        showMessage("Please select start and end date");
        return;
      }

      if (endDate!.isBefore(startDate!)) {
        showMessage("End date cannot be before start date");
        return;
      }
    }

    final List<Map<String, String>> slots = [];

    for (final key in selectedKeys) {
      final index = key.indexOf("_");

      slots.add({
        "day": key.substring(0, index),
        "time": key.substring(index + 1),
      });
    }

    final Map<String, dynamic> body = {
      "teachType": teachType,
      "slots": slots,
    };

    if (teachType == "specific") {
      body["startDate"] = apiDate(startDate!);
      body["endDate"] = apiDate(endDate!);
    } else {
      body["startDate"] = null;
      body["endDate"] = null;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final response = await ApiClient.post(
        "/api/Tutor/save-schedule",
        body,
      );

      if (response.statusCode == 200) {
        showMessage("Schedule saved successfully");
        await loadSchedule();
      } else {
        String message = "Unable to save schedule";

        try {
          final data = jsonDecode(response.body);

          if (data is Map) {
            message = data["message"]?.toString() ?? message;
          } else if (data is String) {
            message = data;
          }
        } catch (_) {
          message = response.body;
        }

        showMessage(message);
      }
    } catch (e) {
      showMessage(e.toString());
    }

    if (!mounted) return;

    setState(() {
      isSaving = false;
    });
  }

  // =====================================================
  // CLEAR SCHEDULE
  // =====================================================

  void clearSchedule() {
    setState(() {
      selectedKeys.clear();

      teachType = "full";

      startDate = null;
      endDate = null;
    });
  }

  // =====================================================
  // BOTTOM NAVIGATION
  // =====================================================

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });

    switch (index) {
      case 0:
        break;

      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TutorStudentRequest(),
          ),
        );
        break;

      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TutorTodayClasses(),
          ),
        );
        break;

      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TutorAddSubject(),
          ),
        );
        break;
    }
  }

  // =====================================================
  // SECTION TITLE
  // =====================================================

  Widget sectionTitle(
    String title, {
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),

          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: greyColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =====================================================
  // PAGE HEADER
  // =====================================================

  Widget pageHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "TUTOR DASHBOARD",
                style: TextStyle(
                  fontSize: 10,
                  color: greyColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                "My Availability",
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                "Manage your weekly teaching hours",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: lightTeal,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: primaryColor,
                size: 21,
              ),

              const SizedBox(height: 4),

              Text(
                "${selectedKeys.length}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),

              const Text(
                "Selected",
                style: TextStyle(
                  fontSize: 9,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =====================================================
  // AVAILABILITY TYPE SELECTOR
  // =====================================================

  Widget availabilityTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xffF0F3F2),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: typeOption(
              title: "Full Time",
              icon: Icons.all_inclusive_rounded,
              selected: teachType == "full",
              onTap: () {
                setState(() {
                  teachType = "full";
                  startDate = null;
                  endDate = null;
                });
              },
            ),
          ),

          Expanded(
            child: typeOption(
              title: "Specific Time",
              icon: Icons.date_range_rounded,
              selected: teachType == "specific",
              onTap: () {
                setState(() {
                  teachType = "specific";
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // TYPE OPTION
  // =====================================================

  Widget typeOption({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? primaryColor : greyColor,
            ),

            const SizedBox(width: 7),

            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? primaryColor : greyColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // DATE RANGE SECTION
  // =====================================================

  Widget dateRangeSection() {
    if (teachType != "specific") {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(
          "Choose Date Range",
          subtitle: "Set the period for this availability.",
        ),

        Row(
          children: [
            Expanded(
              child: dateBox(
                "START DATE",
                startDate,
                true,
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 9),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 17,
                color: greyColor,
              ),
            ),

            Expanded(
              child: dateBox(
                "END DATE",
                endDate,
                false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =====================================================
  // DATE BOX
  // =====================================================

  Widget dateBox(
    String label,
    DateTime? date,
    bool isStart,
  ) {
    return InkWell(
      onTap: () => pickDate(isStart),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xffE3EAE7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 15,
                  color: primaryColor,
                ),

                const SizedBox(width: 5),

                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: greyColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              date == null ? "Select date" : showDate(date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: date == null ? greyColor : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // SCHEDULE GRID
  // =====================================================

  Widget scheduleGrid() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(7, 12, 7, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xffE8EDEA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Day headings
          Row(
            children: [
              const SizedBox(width: timeColWidth),

              ...days.map((day) {
                final freeSlots = times.where((time) {
                  final status = getSlotStatus(day, time);

                  return status != "red" &&
                      status != "yellow";
                }).toList();

                final allSelected = freeSlots.isNotEmpty &&
                    freeSlots.every(
                      (time) =>
                          selectedKeys.contains("${day}_$time"),
                    );

                return Expanded(
                  child: GestureDetector(
                    onTap: () => toggleDay(day),
                    child: Container(
                      height: 34,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 1,
                      ),
                      decoration: BoxDecoration(
                        color: allSelected
                            ? const Color(0xffE4F3EF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: allSelected
                              ? primaryColor
                              : const Color(0xff53615D),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 7),

          Divider(
            height: 1,
            color: Colors.grey.shade200,
          ),

          const SizedBox(height: 5),

          // Time rows
          ...times.map((time) {
            return Row(
              children: [
                timeLabel(time),

                ...days.map((day) {
                  return Expanded(
                    child: slotCell(day, time),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }

  // =====================================================
  // TIME LABEL
  // =====================================================

  Widget timeLabel(String time) {
    final parts = time.split(' ');

    final range = parts[0];

    final period = parts.length > 1
        ? parts[1].toUpperCase()
        : '';

    return SizedBox(
      width: timeColWidth,
      height: cellHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            range,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Color(0xff46534F),
            ),
          ),

          Text(
            period,
            style: const TextStyle(
              fontSize: 8,
              color: Color(0xffA0AAA6),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // SLOT CELL
  // =====================================================

  Widget slotCell(
    String day,
    String time,
  ) {
    final status = getSlotStatus(day, time);

    final selected = selectedKeys.contains("${day}_$time");

    Widget? icon;

    if (status == "red") {
      icon = const Icon(
        Icons.lock_rounded,
        color: Color(0xffD75B5B),
        size: 11,
      );
    } else if (status == "yellow") {
      icon = const Icon(
        Icons.schedule_rounded,
        color: Color(0xffC38B25),
        size: 11,
      );
    } else if (selected) {
      icon = const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 13,
      );
    }

    return GestureDetector(
      onTap: () => onSlotTap(day, time),
      child: SizedBox(
        height: cellHeight,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: getSlotColor(day, time),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: getSlotBorder(day, time),
              width: 0.8,
            ),
          ),
          child: icon == null
              ? null
              : Center(child: icon),
        ),
      ),
    );
  }

  // =====================================================
  // SCHEDULE LEGEND
  // =====================================================

  Widget scheduleLegend() {
    return Wrap(
      spacing: 15,
      runSpacing: 9,
      children: [
        legendItem(
          primaryColor,
          "Available",
        ),

        legendItem(
          const Color(0xffFCE9E9),
          "Booked",
        ),

        legendItem(
          const Color(0xffFFF4DE),
          "Pre / Reschedule",
        ),

        legendItem(
          const Color(0xffF1F4F3),
          "Free",
        ),
      ],
    );
  }

  // =====================================================
  // LEGEND ITEM
  // =====================================================

  Widget legendItem(Color color, String title) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 12,
          width: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 0.5,
            ),
          ),
        ),

        const SizedBox(width: 5),

        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xff65716D),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // SAVE AND CLEAR BUTTONS
  // =====================================================

  Widget actionButtons() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        0, 12, 0, 12,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : saveSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              icon: isSaving
                  ? const SizedBox(
                      height: 17,
                      width: 17,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.save_outlined,
                      size: 19,
                    ),
              label: Text(
                isSaving ? "Saving..." : "Save Schedule",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: OutlinedButton(
              onPressed: isSaving ? null : clearSchedule,
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: const BorderSide(
                  color: primaryColor,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: const Text(
                "Clear",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // APP BAR
  // Added notification icon in actions
  // =====================================================

  PreferredSizeWidget tutorAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      centerTitle: true,

      // Drawer icon
      leading: Builder(
        builder: (context) {
          return IconButton(
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
            icon: const Icon(
              Icons.menu_rounded,
              color: primaryColor,
            ),
          );
        },
      ),

      // Logo and app name
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            "assets/images/logo.png",
            height: 35,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.school_rounded,
                color: primaryColor,
                size: 32,
              );
            },
          ),

          const SizedBox(width: 8),

          const Text(
            "House of Tutor",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ],
      ),

      // Notification icon with pending count
      actions: [
        notificationButton(),
        const SizedBox(width: 5),
      ],
    );
  }

  // =====================================================
  // MAIN BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: tutorAppBar(),

      drawer: const TutorDrawer(),

      // =================================================
      // BODY
      // =================================================

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: loadSchedule,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  15, 18, 15, 25,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page heading
                    pageHeader(),

                    const SizedBox(height: 23),

                    // Availability type
                    sectionTitle(
                      "Availability Type",
                      subtitle:
                          "Select your preferred teaching schedule.",
                    ),

                    availabilityTypeSelector(),

                    // Start and end dates
                    if (teachType == "specific") ...[
                      const SizedBox(height: 23),
                      dateRangeSection(),
                    ],

                    const SizedBox(height: 24),

                    // Schedule heading
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Weekly Schedule",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                        ),

                        Text(
                          "Tap day to select all",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Schedule grid
                    scheduleGrid(),

                    const SizedBox(height: 14),

                    // Color legend
                    scheduleLegend(),

                    const SizedBox(height: 8),

                    // Save and clear buttons
                    actionButtons(),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

      // =================================================
      // BOTTOM NAVIGATION
      // =================================================

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: primaryColor,
        unselectedItemColor: const Color(0xff9AA4A1),
        selectedFontSize: 11,
        unselectedFontSize: 10,
        onTap: onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            label: "Schedule",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_rounded),
            label: "Requests",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.school_rounded),
            label: "Classes",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: "Subjects",
          ),
        ],
      ),
    );
  }
}