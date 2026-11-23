import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:house_of_tutor/TutorAddSubject.dart';
import 'package:house_of_tutor/TutorDrawer.dart';
import 'package:house_of_tutor/TutorHome.dart';
import 'package:house_of_tutor/TutorStudentRequest.dart';
import 'package:house_of_tutor/services/api_client.dart';

class TutorTodayClasses extends StatefulWidget {
  const TutorTodayClasses({super.key});

  @override
  State<TutorTodayClasses> createState() => _TutorTodayClassesState();
}

class _TutorTodayClassesState extends State<TutorTodayClasses> {
  int currentIndex = 2;
  bool loading = true;
  List<dynamic> classes = [];

  // 🎨 MAIN THEME COLOR
  final Color mainColor = Colors.teal;

  @override
  void initState() {
    super.initState();
    fetchTodayClasses();
  }

  // =====================================================
  // FETCH TODAY CLASSES
  // =====================================================

  Future<void> fetchTodayClasses() async {
    try {
      setState(() => loading = true);

      final response = await ApiClient.get('/api/Tutor/today-classes');

      debugPrint("TODAY STATUS : ${response.statusCode}");
      debugPrint("TODAY BODY : ${response.body}");

      classes = [];

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));

        if (decoded is Map &&
            decoded["data"] != null &&
            decoded["data"] is List) {
          classes = List<dynamic>.from(decoded["data"]);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ApiClient.messageFromBody(response.body) ??
                    "Failed to load classes",
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("TODAY ERROR : $e");
      classes = [];
    }

    if (mounted) setState(() => loading = false);
  }

  // =====================================================
  // COMPLETE CLASS
  // =====================================================

  Future<void> completeClass(int requestId) async {
    try {
      final response = await ApiClient.put(
        '/api/Tutor/complete-class/$requestId',
        {},
      );

      debugPrint("COMPLETE STATUS : ${response.statusCode}");
      debugPrint("COMPLETE BODY : ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Class marked as Complete")),
        );
        fetchTodayClasses();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiClient.messageFromBody(response.body) ?? "Failed",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("COMPLETE ERROR : $e");
    }
  }

  // =====================================================
  // CANCEL CLASS
  // =====================================================

  Future<void> cancelClass(int requestId) async {
    try {
      final response = await ApiClient.put(
        '/api/Tutor/cancel-class/$requestId',
        {},
      );

      debugPrint("CANCEL STATUS : ${response.statusCode}");
      debugPrint("CANCEL BODY : ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Class Cancelled")),
        );
        fetchTodayClasses();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiClient.messageFromBody(response.body) ?? "Failed",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("CANCEL ERROR : $e");
    }
  }

  // =====================================================
  // AUTO SCHEDULE (Pre / Re)
  // =====================================================

  Future<void> autoSchedule({
    required int requestId,
    required String requestType,
  }) async {
    try {
      setState(() => loading = true);

      final endpoint = requestType == "Preschedule"
          ? '/api/Tutor/preschedule'
          : '/api/Tutor/reschedule';

      final response = await ApiClient.post(endpoint, {
        "requestId": requestId,
      });

      debugPrint("AUTO SCHEDULE STATUS : ${response.statusCode}");
      debugPrint("AUTO SCHEDULE BODY : ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        final bool autoScheduled = json["autoScheduled"] ?? false;
        final bool manualRequired = json["manualRequired"] ?? false;

        if (autoScheduled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                json["message"] ?? "$requestType successful",
              ),
            ),
          );
          fetchTodayClasses();
        } else if (manualRequired) {
          setState(() => loading = false);
          openManualDialog(requestId, requestType);
        }
      } else {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiClient.messageFromBody(response.body) ??
                  "Unable to $requestType",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("AUTO SCHEDULE ERROR : $e");
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  // =====================================================
  // MANUAL SCHEDULE DIALOG
  // =====================================================

  void openManualDialog(int requestId, String requestType) {
    final days = [
      "Monday", "Tuesday", "Wednesday",
      "Thursday", "Friday", "Saturday", "Sunday",
    ];

    String selectedDay = days.first;
    TimeOfDay selectedTime = TimeOfDay.now();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                "Manual $requestType",
                style: TextStyle(
                  color: mainColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "No common slot found. Please pick a day, date and time.",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),

                    // DAY
                    const Text("Day",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedDay,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      items: days
                          .map((d) =>
                              DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedDay = val!);
                      },
                    ),

                    const SizedBox(height: 16),

                    // DATE
                    const Text("Date",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        child: Text(
                          "${selectedDate.year}-"
                          "${selectedDate.month.toString().padLeft(2, '0')}-"
                          "${selectedDate.day.toString().padLeft(2, '0')}",
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // TIME
                    const Text("Time",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setDialogState(() => selectedTime = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        child: Text(selectedTime.format(context)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await manualSchedule(
                      requestId: requestId,
                      requestType: requestType,
                      day: selectedDay,
                      time: selectedTime.format(context),
                      date: selectedDate,
                    );
                  },
                  child: const Text(
                    "Send Request",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =====================================================
  // MANUAL SCHEDULE API
  // =====================================================

  Future<void> manualSchedule({
    required int requestId,
    required String requestType,
    required String day,
    required String time,
    required DateTime date,
  }) async {
    try {
      final response = await ApiClient.post(
        '/api/Tutor/manual-schedule',
        {
          "requestId": requestId,
          "requestType": requestType,
          "day": day,
          "time": time,
          "classDate": date.toIso8601String(),
        },
      );

      debugPrint("MANUAL STATUS : ${response.statusCode}");
      debugPrint("MANUAL BODY : ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Schedule request sent to student."),
          ),
        );
        fetchTodayClasses();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiClient.messageFromBody(response.body) ??
                  "Unable to send request",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("MANUAL ERROR : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  // =====================================================
  // NAVIGATION
  // =====================================================

  void navigateScreen(int value) {
    if (value == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TutorHome()),
      );
    } else if (value == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TutorStudentRequest()),
      );
    } else if (value == 2) {
      return;
    } else if (value == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TutorAddSubject()),
      );
    }
  }

  // =====================================================
  // SINGLE-LINE ACTION BUTTON
  // =====================================================
  // FittedBox keeps Complete / Pre-Schedule / Re-Schedule /
  // Cancel from wrapping onto a second line on narrow screens.

  Widget actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // CLASS CARD
  // =====================================================

  Widget classCard(dynamic data) {
    final int requestId = (data["request_id"] as num?)?.toInt() ?? 0;
    final String time = data["time"]?.toString() ?? "";
    final String student = data["student_name"]?.toString() ?? "";
    final String subject = data["course_name"]?.toString() ?? "";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffE7E9ED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TIME BADGE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: mainColor.withOpacity(.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 15, color: mainColor),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: TextStyle(
                    color: mainColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xffE7E9ED)),
          const SizedBox(height: 12),

          // STUDENT / SUBJECT ROW
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: mainColor,
                child: const Icon(Icons.person, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff101C33),
                      ),
                    ),
                    Text(
                      subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ACTION BUTTONS (4-in-a-row, single line each)
          Row(
            children: [
              Expanded(
                child: actionButton(
                  label: "Complete",
                  icon: Icons.check_circle_outline,
                  color: const Color(0xff2DB55D),
                  onTap: () => completeClass(requestId),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: actionButton(
                  label: "Pre-Sch.",
                  icon: Icons.history_toggle_off,
                  color: const Color(0xff9B51E0),
                  onTap: () => autoSchedule(
                    requestId: requestId,
                    requestType: "Preschedule",
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: actionButton(
                  label: "Re-Sch.",
                  icon: Icons.event_repeat,
                  color: const Color(0xff2F80ED),
                  onTap: () => autoSchedule(
                    requestId: requestId,
                    requestType: "Reschedule",
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: actionButton(
                  label: "Cancel",
                  icon: Icons.cancel_outlined,
                  color: Colors.redAccent,
                  onTap: () => cancelClass(requestId),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FB),
      drawer: const TutorDrawer(),

      // =====================================================
      // APP BAR
      // =====================================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              "assets/images/logo.png",
              height: 26,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.school, color: mainColor);
              },
            ),
            const SizedBox(width: 8),
            Text(
              "House of Tutor",
              style: TextStyle(
                color: mainColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),

      // =====================================================
      // BODY
      // =====================================================

      body: loading
          ? Center(child: CircularProgressIndicator(color: mainColor))
          : RefreshIndicator(
              onRefresh: fetchTodayClasses,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  // HEADER
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Classes",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff101C33),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: mainColor.withOpacity(.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${classes.length} Sessions",
                            style: TextStyle(
                              color: mainColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
                    child: Text(
                      "Manage your active teaching schedule for today.",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),

                  // LIST
                  if (classes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text(
                          "No classes today",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ...classes.map((c) => classCard(c)),
                ],
              ),
            ),

      // =====================================================
      // BOTTOM NAVIGATION
      // =====================================================

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: mainColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (value) {
          setState(() => currentIndex = value);
          navigateScreen(value);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: "Schedule",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: "Request",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            label: "Today",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: "Add",
          ),
        ],
      ),
    );
  }
}
