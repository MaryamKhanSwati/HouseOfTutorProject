
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:house_of_tutor/services/api_config.dart';
import 'package:house_of_tutor/services/auth_store.dart';

class AdminVenueManagement extends StatefulWidget {
  const AdminVenueManagement({super.key});

  @override
  State<AdminVenueManagement> createState() =>
      _AdminVenueManagementState();
}

class _AdminVenueManagementState extends State<AdminVenueManagement> {
  // ============================================================
  // COLORS
  // ============================================================

  final Color primaryColor = const Color(0xFF1E8E7E);
  final Color backgroundColor = const Color(0xFFF4F4F4);
  final Color textColor = const Color(0xFF333333);
  final Color secondaryColor = const Color(0xFF6A1B9A);

  // ============================================================
  // FORM CONTROLLERS
  // ============================================================

  final TextEditingController roomNameController =
      TextEditingController();

  final TextEditingController capacityController =
      TextEditingController();

  final GlobalKey formCardKey = GlobalKey();

  // ============================================================
  // DAYS
  // ============================================================

  final List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final Map<String, bool> selectedDays = {
    'Monday': false,
    'Tuesday': false,
    'Wednesday': false,
    'Thursday': false,
    'Friday': false,
    'Saturday': false,
    'Sunday': false,
  };

  // ============================================================
  // SCHEDULE FORM
  // ============================================================

  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;

  DateTime? selectedStartDate;
  DateTime? selectedEndDate;

  // Existing schedules retain their database IDs.
  // New schedules have ltScheduleId = 0.
  List<Map<String, dynamic>> schedules = [];

  // ============================================================
  // ROOM DATA
  // ============================================================

  List<dynamic> rooms = [];

  bool isLoadingRooms = false;
  bool isSavingRoom = false;
  bool isDeletingRoom = false;

  int? expandedRoomId;

  // ============================================================
  // EDIT MODE
  // ============================================================

  bool isEditingRoom = false;
  int? editingRoomId;

  @override
  void initState() {
    super.initState();
    loadLTRooms();
  }

  @override
  void dispose() {
    roomNameController.dispose();
    capacityController.dispose();
    super.dispose();
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  dynamic getValue(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (data.containsKey(key)) {
        return data[key];
      }
    }

    return null;
  }

  int getInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;

    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String getString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  String getToken() {
    return AuthStore.instance.token ?? '';
  }

  Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${getToken()}',
    };
  }

  DateTime? parseApiDate(dynamic value) {
    if (value == null) return null;

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) return null;

    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
    );
  }

  String? formatDateFromApi(dynamic value) {
    final date = parseApiDate(value);

    if (date == null) return null;

    return formatDate(date);
  }

  // ============================================================
  // LOAD LT ROOMS
  //
  // GET /api/Admin/get-lt-rooms
  // ============================================================

  Future<void> loadLTRooms() async {
    if (!mounted) return;

    setState(() {
      isLoadingRooms = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/Admin/get-lt-rooms'),
        headers: getHeaders(),
      );

      debugPrint('GET LT ROOMS STATUS: ${response.statusCode}');
      debugPrint('GET LT ROOMS RESPONSE: ${response.body}');

      final dynamic decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        dynamic roomData;

        if (decoded is List) {
          roomData = decoded;
        } else if (decoded is Map) {
          roomData = decoded['rooms'] ??
              decoded['data'] ??
              decoded['ltRooms'] ??
              decoded['LT_Room'];
        }

        if (roomData is List) {
          if (!mounted) return;

          setState(() {
            rooms = roomData;
          });
        } else {
          throw Exception(
            'The API response does not contain a rooms list.',
          );
        }
      } else {
        final message = decoded is Map
            ? getString(
                decoded['message'] ?? decoded['title'],
                fallback: 'Unable to load LT rooms.',
              )
            : 'Unable to load LT rooms.';

        showMessage(message, isError: true);
      }
    } catch (e) {
      debugPrint('GET LT ROOMS ERROR: $e');

      showMessage(
        'Unable to load LT rooms. Check your API connection.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoadingRooms = false;
        });
      }
    }
  }

  // ============================================================
  // RESET FORM
  // ============================================================

  void resetVenueForm() {
    roomNameController.clear();
    capacityController.clear();

    if (!mounted) return;

    setState(() {
      isEditingRoom = false;
      editingRoomId = null;

      schedules.clear();

      for (final day in days) {
        selectedDays[day] = false;
      }

      selectedStartTime = null;
      selectedEndTime = null;
      selectedStartDate = null;
      selectedEndDate = null;
    });
  }

  void cancelEditRoom() {
    resetVenueForm();

    showMessage(
      'Editing cancelled.',
      isError: false,
    );
  }

  // ============================================================
  // TIME PICKERS
  // ============================================================

  Future<void> selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedStartTime ?? TimeOfDay.now(),
    );

    if (picked != null && mounted) {
      setState(() {
        selectedStartTime = picked;

        if (selectedEndTime != null) {
          final startMinutes =
              picked.hour * 60 + picked.minute;

          final endMinutes =
              selectedEndTime!.hour * 60 +
                  selectedEndTime!.minute;

          if (endMinutes <= startMinutes) {
            selectedEndTime = null;
          }
        }
      });
    }
  }

  Future<void> selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedEndTime ??
          const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null && mounted) {
      setState(() {
        selectedEndTime = picked;
      });
    }
  }

  // ============================================================
  // DATE PICKERS
  // ============================================================

  Future<void> selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      setState(() {
        selectedStartDate = picked;

        if (selectedEndDate != null &&
            picked.isAfter(selectedEndDate!)) {
          selectedEndDate = null;
        }
      });
    }
  }

  Future<void> selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          selectedEndDate ?? selectedStartDate ?? DateTime.now(),
      firstDate: selectedStartDate ?? DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      setState(() {
        selectedEndDate = picked;
      });
    }
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String formatClockTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0
        ? 12
        : time.hourOfPeriod;

    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String formatTime(TimeOfDay time) {
    final period = time.period == DayPeriod.am ? 'am' : 'pm';

    return '${formatClockTime(time)} $period';
  }

  String getTimeString() {
    final start = selectedStartTime!;
    final end = selectedEndTime!;

    final startPeriod =
        start.period == DayPeriod.am ? 'am' : 'pm';

    final endPeriod =
        end.period == DayPeriod.am ? 'am' : 'pm';

    if (startPeriod == endPeriod) {
      return '${formatClockTime(start)}-'
          '${formatClockTime(end)} $endPeriod';
    }

    return '${formatTime(start)} - ${formatTime(end)}';
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  // ============================================================
  // ADD SCHEDULE
  // ============================================================

  void addSchedule() {
    final selectedDayList = days
        .where((day) => selectedDays[day] == true)
        .toList();

    if (selectedDayList.isEmpty) {
      showMessage(
        'Please select at least one day.',
        isError: true,
      );
      return;
    }

    if (selectedStartTime == null) {
      showMessage(
        'Please select start time.',
        isError: true,
      );
      return;
    }

    if (selectedEndTime == null) {
      showMessage(
        'Please select end time.',
        isError: true,
      );
      return;
    }

    final startMinutes =
        selectedStartTime!.hour * 60 +
            selectedStartTime!.minute;

    final endMinutes =
        selectedEndTime!.hour * 60 +
            selectedEndTime!.minute;

    if (endMinutes <= startMinutes) {
      showMessage(
        'End time must be greater than start time.',
        isError: true,
      );
      return;
    }

    if (selectedStartDate != null &&
        selectedEndDate != null &&
        selectedStartDate!.isAfter(selectedEndDate!)) {
      showMessage(
        'Start date cannot be after end date.',
        isError: true,
      );
      return;
    }

    final timeString = getTimeString();

    setState(() {
      for (final day in selectedDayList) {
        schedules.add({
          // New schedule ID = 0
          'ltScheduleId': 0,
          'day': day,
          'time': timeString,
          'startDate': selectedStartDate != null
              ? formatDate(selectedStartDate!)
              : null,
          'endDate': selectedEndDate != null
              ? formatDate(selectedEndDate!)
              : null,
          'status': 'Available',
        });

        selectedDays[day] = false;
      }

      selectedStartTime = null;
      selectedEndTime = null;
      selectedStartDate = null;
      selectedEndDate = null;
    });

    showMessage(
      '${selectedDayList.length} schedule(s) added.',
      isError: false,
    );
  }

  // ============================================================
  // DELETE TEMPORARY SCHEDULE
  // ============================================================

  void deleteSchedule(int index) {
    if (index < 0 || index >= schedules.length) return;

    setState(() {
      schedules.removeAt(index);
    });
  }

  // ============================================================
  // ADD LT ROOM
  //
  // POST /api/Admin/add-lt-room
  // ============================================================

  Future<void> addLTRoom() async {
    final roomName = roomNameController.text.trim();

    if (roomName.isEmpty) {
      showMessage(
        'Please enter venue name.',
        isError: true,
      );
      return;
    }

    final capacity =
        int.tryParse(capacityController.text.trim());

    if (capacity == null || capacity <= 0) {
      showMessage(
        'Please enter a valid capacity.',
        isError: true,
      );
      return;
    }

    if (schedules.isEmpty) {
      showMessage(
        'Please add at least one schedule.',
        isError: true,
      );
      return;
    }

    if (getToken().isEmpty) {
      showMessage(
        'Authentication token is missing. Please log in again.',
        isError: true,
      );
      return;
    }

    setState(() {
      isSavingRoom = true;
    });

    try {
      final body = {
        'roomName': roomName,
        'capacity': capacity,
        'status': 'Active',
        'schedules': schedules.map((schedule) {
          return {
            'day': schedule['day'],
            'time': schedule['time'],
            'startDate': schedule['startDate'],
            'endDate': schedule['endDate'],
            'status': schedule['status'] ?? 'Available',
          };
        }).toList(),
      };

      debugPrint('========== ADD LT ROOM ==========');
      debugPrint(jsonEncode(body));
      debugPrint('=================================');

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/Admin/add-lt-room'),
        headers: getHeaders(),
        body: jsonEncode(body),
      );

      debugPrint('ADD LT ROOM STATUS: ${response.statusCode}');
      debugPrint('ADD LT ROOM RESPONSE: ${response.body}');

      dynamic decoded;

      if (response.body.trim().isNotEmpty) {
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {
          decoded = null;
        }
      }

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        final message = decoded is Map
            ? getString(
                decoded['message'],
                fallback: 'LT venue added successfully.',
              )
            : 'LT venue added successfully.';

        if (!mounted) return;

        resetVenueForm();

        showMessage(message, isError: false);

        await loadLTRooms();
      } else {
        final message = decoded is Map
            ? getString(
                decoded['message'] ?? decoded['title'],
                fallback: 'Unable to add LT venue.',
              )
            : 'Unable to add LT venue.';

        showMessage(
          '$message (HTTP ${response.statusCode})',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('ADD LT ROOM ERROR: $e');

      showMessage(
        'Unable to connect with server.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isSavingRoom = false;
        });
      }
    }
  }

  // ============================================================
  // EDIT LT ROOM
  //
  // Fill existing venue details into the form.
  // ============================================================

  void editLTRoom(Map<String, dynamic> room) {
    final roomId = getInt(
      getValue(room, [
        'ltRoomId',
        'lt_room_id',
        'LT_Room_Id',
        'LtRoomId',
      ]),
    );

    if (roomId <= 0) {
      showMessage(
        'Invalid LT Room ID.',
        isError: true,
      );
      return;
    }

    final roomName = getString(
      getValue(room, [
        'roomName',
        'room_name',
        'RoomName',
      ]),
    );

    final capacity = getInt(
      getValue(room, [
        'capacity',
        'Capacity',
      ]),
    );

    final rawSchedules = getValue(
      room,
      [
        'schedules',
        'Schedules',
        'ltRoomSchedules',
      ],
    );

    final List<Map<String, dynamic>> loadedSchedules = [];

    if (rawSchedules is List) {
      for (final item in rawSchedules) {
        if (item is! Map) continue;

        final schedule =
            Map<String, dynamic>.from(item);

        loadedSchedules.add({
          'ltScheduleId': getInt(
            getValue(schedule, [
              'ltScheduleId',
              'lt_schedule_id',
              'LtScheduleId',
            ]),
          ),
          'day': getString(
            getValue(schedule, ['day', 'Day']),
          ),
          'time': getString(
            getValue(schedule, ['time', 'Time']),
          ),
          'startDate': formatDateFromApi(
            getValue(schedule, [
              'startDate',
              'start_date',
              'StartDate',
            ]),
          ),
          'endDate': formatDateFromApi(
            getValue(schedule, [
              'endDate',
              'end_date',
              'EndDate',
            ]),
          ),
          'status': getString(
            getValue(schedule, ['status', 'Status']),
            fallback: 'Available',
          ),
        });
      }
    }

    if (loadedSchedules.isEmpty) {
      showMessage(
        'This venue has no schedules to update.',
        isError: true,
      );
      return;
    }

    setState(() {
      isEditingRoom = true;
      editingRoomId = roomId;

      roomNameController.text = roomName;
      capacityController.text = capacity.toString();

      schedules = loadedSchedules;

      for (final day in days) {
        selectedDays[day] = false;
      }

      selectedStartTime = null;
      selectedEndTime = null;
      selectedStartDate = null;
      selectedEndDate = null;

      expandedRoomId = roomId;
    });

    showMessage(
      'Venue loaded. Edit the details and press Update Venue.',
      isError: false,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && formCardKey.currentContext != null) {
        Scrollable.ensureVisible(
          formCardKey.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ============================================================
  // UPDATE LT ROOM
  //
  // PUT /api/Admin/update-lt-room/{roomId}
  //
  // Existing schedules:
  // ltScheduleId = actual database ID
  //
  // New schedules:
  // ltScheduleId = 0
  // ============================================================

  Future<void> updateLTRoom() async {
    if (editingRoomId == null) {
      showMessage(
        'Please select a venue to update.',
        isError: true,
      );
      return;
    }

    final roomName = roomNameController.text.trim();

    if (roomName.isEmpty) {
      showMessage(
        'Please enter venue name.',
        isError: true,
      );
      return;
    }

    final capacity =
        int.tryParse(capacityController.text.trim());

    if (capacity == null || capacity <= 0) {
      showMessage(
        'Please enter a valid capacity.',
        isError: true,
      );
      return;
    }

    if (schedules.isEmpty) {
      showMessage(
        'Please add at least one schedule.',
        isError: true,
      );
      return;
    }

    if (getToken().isEmpty) {
      showMessage(
        'Authentication token is missing. Please log in again.',
        isError: true,
      );
      return;
    }

    setState(() {
      isSavingRoom = true;
    });

    try {
      final body = {
        'roomName': roomName,
        'capacity': capacity,
        'schedules': schedules.map((schedule) {
          return {
            'ltScheduleId': getInt(
              schedule['ltScheduleId'],
            ),
            'day': schedule['day'],
            'time': schedule['time'],
            'startDate': schedule['startDate'],
            'endDate': schedule['endDate'],
          };
        }).toList(),
      };

      debugPrint('========== UPDATE LT ROOM ==========');
      debugPrint('ROOM ID: $editingRoomId');
      debugPrint(jsonEncode(body));
      debugPrint('====================================');

      final response = await http.put(
        Uri.parse(
          '$apiBaseUrl/api/Admin/update-lt-room/$editingRoomId',
        ),
        headers: getHeaders(),
        body: jsonEncode(body),
      );

      debugPrint('UPDATE STATUS: ${response.statusCode}');
      debugPrint('UPDATE RESPONSE: ${response.body}');

      dynamic decoded;

      if (response.body.trim().isNotEmpty) {
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {
          decoded = null;
        }
      }

      if (response.statusCode == 200) {
        final message = decoded is Map
            ? getString(
                decoded['message'],
                fallback: 'LT Room updated successfully.',
              )
            : 'LT Room updated successfully.';

        if (!mounted) return;

        resetVenueForm();

        showMessage(
          message,
          isError: false,
        );

        await loadLTRooms();
      } else {
        final message = decoded is Map
            ? getString(
                decoded['message'] ?? decoded['title'],
                fallback: 'Unable to update LT Room.',
              )
            : 'Unable to update LT Room.';

        showMessage(
          '$message (HTTP ${response.statusCode})',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('UPDATE LT ROOM ERROR: $e');

      showMessage(
        'Unable to connect with server.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isSavingRoom = false;
        });
      }
    }
  }

  // ============================================================
  // DELETE LT ROOM
  //
  // DELETE /api/Admin/delete-lt-room/{roomId}
  // ============================================================

  Future<void> deleteLTRoom(
    int roomId,
    String roomName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text('Delete Venue?'),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "$roomName"?\n\n'
            'All schedules associated with this venue will also be deleted. '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (getToken().isEmpty) {
      showMessage(
        'Authentication token is missing. Please log in again.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      isDeletingRoom = true;
    });

    try {
      final response = await http.delete(
        Uri.parse(
          '$apiBaseUrl/api/Admin/delete-lt-room/$roomId',
        ),
        headers: getHeaders(),
      );

      debugPrint('DELETE LT ROOM STATUS: ${response.statusCode}');
      debugPrint('DELETE LT ROOM RESPONSE: ${response.body}');

      dynamic decoded;

      if (response.body.trim().isNotEmpty) {
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {
          decoded = null;
        }
      }

      if (response.statusCode == 200) {
        final message = decoded is Map
            ? getString(
                decoded['message'],
                fallback: 'LT Room deleted successfully.',
              )
            : 'LT Room deleted successfully.';

        if (!mounted) return;

        if (editingRoomId == roomId) {
          resetVenueForm();
        }

        setState(() {
          if (expandedRoomId == roomId) {
            expandedRoomId = null;
          }
        });

        showMessage(
          message,
          isError: false,
        );

        await loadLTRooms();
      } else {
        final message = decoded is Map
            ? getString(
                decoded['message'] ?? decoded['title'],
                fallback: 'Unable to delete LT Room.',
              )
            : 'Unable to delete LT Room.';

        showMessage(
          '$message (HTTP ${response.statusCode})',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('DELETE LT ROOM ERROR: $e');

      showMessage(
        'Unable to connect with server.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isDeletingRoom = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
    String message, {
    required bool isError,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // MAIN SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Venue Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: isLoadingRooms ? null : loadLTRooms,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh venues',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadLTRooms,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildAddVenueCard(),

              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Existing LT Venues',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${rooms.length} Venues',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (isLoadingRooms && rooms.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (rooms.isEmpty)
                buildEmptyRooms()
              else
                ListView.builder(
                  itemCount: rooms.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final room = rooms[index];

                    if (room is! Map) {
                      return const SizedBox.shrink();
                    }

                    return buildRoomCard(
                      Map<String, dynamic>.from(room),
                    );
                  },
                ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ADD / EDIT VENUE CARD
  // ============================================================

  Widget buildAddVenueCard() {
    return Container(
      key: formCardKey,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isEditingRoom
            ? Border.all(
                color: secondaryColor.withOpacity(0.5),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isEditingRoom
                          ? secondaryColor
                          : primaryColor)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isEditingRoom
                      ? Icons.edit_note
                      : Icons.meeting_room,
                  color: isEditingRoom
                      ? secondaryColor
                      : primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditingRoom
                          ? 'Edit LT Venue'
                          : 'Add LT Venue',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isEditingRoom
                          ? 'Update venue details and schedules.'
                          : 'Add a venue and its available schedule.',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isEditingRoom)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: secondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'EDIT MODE',
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          buildTextField(
            controller: roomNameController,
            label: 'Venue Name',
            hint: 'e.g. LT-1',
            icon: Icons.meeting_room_outlined,
          ),

          const SizedBox(height: 14),

          buildTextField(
            controller: capacityController,
            label: 'Capacity',
            hint: 'e.g. 10',
            icon: Icons.people_outline,
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 22),

          Row(
            children: [
              Icon(
                Icons.calendar_month,
                color: secondaryColor,
              ),
              const SizedBox(width: 8),
              const Text(
                'LT Schedule',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          const Text(
            'Select days, time and optional date range.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 15),

          const Text(
            'Select Days',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          buildDaysSelection(),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: buildTimeButton(
                  title: 'Start Time',
                  value: selectedStartTime == null
                      ? 'Select time'
                      : formatTime(selectedStartTime!),
                  onTap: selectStartTime,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildTimeButton(
                  title: 'End Time',
                  value: selectedEndTime == null
                      ? 'Select time'
                      : formatTime(selectedEndTime!),
                  onTap: selectEndTime,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: buildDateButton(
                  title: 'Start Date',
                  value: selectedStartDate == null
                      ? 'Optional'
                      : formatDate(selectedStartDate!),
                  onTap: selectStartDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildDateButton(
                  title: 'End Date',
                  value: selectedEndDate == null
                      ? 'Optional'
                      : formatDate(selectedEndDate!),
                  onTap: selectEndDate,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isSavingRoom ? null : addSchedule,
              icon: const Icon(Icons.add),
              label: const Text('Add Schedule'),
              style: OutlinedButton.styleFrom(
                foregroundColor: secondaryColor,
                side: BorderSide(color: secondaryColor),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          if (schedules.isNotEmpty) ...[
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Added Schedules',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${schedules.length} Schedule(s)',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            ...List.generate(
              schedules.length,
              (index) => buildScheduleCard(
                schedules[index],
                index,
              ),
            ),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSavingRoom
                  ? null
                  : (isEditingRoom
                      ? updateLTRoom
                      : addLTRoom),
              icon: isSavingRoom
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isEditingRoom
                          ? Icons.update
                          : Icons.save,
                    ),
              label: Text(
                isSavingRoom
                    ? (isEditingRoom
                        ? 'Updating Venue...'
                        : 'Saving Venue...')
                    : (isEditingRoom
                        ? 'Update Venue'
                        : 'Save Venue'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isEditingRoom
                    ? secondaryColor
                    : primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          if (isEditingRoom) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isSavingRoom
                    ? null
                    : cancelEditRoom,
                icon: const Icon(Icons.close),
                label: const Text('Cancel Editing'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: primaryColor,
        ),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: primaryColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DAY SELECTION
  // ============================================================

  Widget buildDaysSelection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: days.map((day) {
          return CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              day,
              style: const TextStyle(fontSize: 14),
            ),
            value: selectedDays[day] ?? false,
            activeColor: primaryColor,
            onChanged: isSavingRoom
                ? null
                : (value) {
                    setState(() {
                      selectedDays[day] = value ?? false;
                    });
                  },
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // TIME BUTTON
  // ============================================================

  Widget buildTimeButton({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 19,
                  color: primaryColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DATE BUTTON
  // ============================================================

  Widget buildDateButton({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: secondaryColor,
                ),
                const SizedBox(width: 6),
                Expanded(
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
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TEMPORARY SCHEDULE CARD
  // ============================================================

  Widget buildScheduleCard(
    Map<String, dynamic> schedule,
    int index,
  ) {
    final isNew =
        getInt(schedule['ltScheduleId']) == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: primaryColor,
            child: const Icon(
              Icons.schedule,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getString(schedule['day']),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  getString(schedule['time']),
                  style: const TextStyle(fontSize: 13),
                ),
                if (schedule['startDate'] != null ||
                    schedule['endDate'] != null)
                  Text(
                    '${schedule['startDate'] ?? 'No start'}'
                    ' → '
                    '${schedule['endDate'] ?? 'No end'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Text(
                      'Available',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isEditingRoom && !isNew) ...[
                      const SizedBox(width: 7),
                      const Text(
                        '• Existing',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                    if (isEditingRoom && isNew) ...[
                      const SizedBox(width: 7),
                      const Text(
                        '• New',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isSavingRoom
                ? null
                : () => deleteSchedule(index),
            tooltip: 'Remove schedule',
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EXISTING ROOM CARD
  // ============================================================

  Widget buildRoomCard(Map<String, dynamic> room) {
    final roomId = getInt(
      getValue(room, [
        'ltRoomId',
        'lt_room_id',
        'LT_Room_Id',
        'LtRoomId',
      ]),
    );

    final roomName = getString(
      getValue(room, [
        'roomName',
        'room_name',
        'RoomName',
      ]),
      fallback: 'Unknown Venue',
    );

    final capacity = getInt(
      getValue(room, [
        'capacity',
        'Capacity',
      ]),
    );

    final status = getString(
      getValue(room, [
        'status',
        'Status',
      ]),
      fallback: 'Active',
    );

    final rawSchedules = getValue(
      room,
      [
        'schedules',
        'Schedules',
        'ltRoomSchedules',
      ],
    );

    final List<dynamic> roomSchedules =
        rawSchedules is List ? rawSchedules : [];

    final isExpanded = expandedRoomId == roomId;

    final isActive = status.toLowerCase() == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ----------------------------------------------------
          // ROOM HEADER
          // ----------------------------------------------------

          InkWell(
            onTap: () {
              setState(() {
                expandedRoomId =
                    isExpanded ? null : roomId;
              });
            },
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.meeting_room,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roomName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 10,
                          runSpacing: 5,
                          crossAxisAlignment:
                              WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Capacity: $capacity',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: primaryColor,
                  ),
                ],
              ),
            ),
          ),

          // ----------------------------------------------------
          // EDIT AND DELETE BUTTONS
          // ----------------------------------------------------

          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        (isSavingRoom || isDeletingRoom || roomId <= 0)
                            ? null
                            : () => editLTRoom(room),
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                    ),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        (isSavingRoom || isDeletingRoom || roomId <= 0)
                            ? null
                            : () => deleteLTRoom(
                                  roomId,
                                  roomName,
                                ),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                    ),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ----------------------------------------------------
          // EXPANDED SCHEDULES
          // ----------------------------------------------------

          if (isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                15,
                0,
                15,
                15,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 19,
                        color: secondaryColor,
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'Venue Schedule',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (roomSchedules.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'No schedule available.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ...roomSchedules.map((item) {
                      if (item is! Map) {
                        return const SizedBox.shrink();
                      }

                      return buildSavedSchedule(
                        Map<String, dynamic>.from(item),
                      );
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // SAVED SCHEDULE CARD
  // ============================================================

  Widget buildSavedSchedule(
    Map<String, dynamic> schedule,
  ) {
    final day = getString(
      getValue(schedule, ['day', 'Day']),
      fallback: 'Unknown Day',
    );

    final time = getString(
      getValue(schedule, ['time', 'Time']),
      fallback: 'No time',
    );

    final startDate = getValue(
      schedule,
      [
        'startDate',
        'start_date',
        'StartDate',
      ],
    );

    final endDate = getValue(
      schedule,
      [
        'endDate',
        'end_date',
        'EndDate',
      ],
    );

    final status = getString(
      getValue(schedule, ['status', 'Status']),
      fallback: 'Available',
    );

    final isAvailable =
        status.toLowerCase() == 'available';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: secondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.schedule,
              color: secondaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                if (startDate != null || endDate != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${startDate ?? 'No start date'}'
                    ' → '
                    '${endDate ?? 'No end date'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: isAvailable
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: isAvailable ? Colors.green : Colors.red,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY ROOM SCREEN
  // ============================================================

  Widget buildEmptyRooms() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(
            Icons.meeting_room_outlined,
            size: 55,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          const Text(
            'No LT Venues Found',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Add your first LT venue above.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
