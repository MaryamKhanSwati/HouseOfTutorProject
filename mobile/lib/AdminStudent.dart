
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:house_of_tutor/AdminApprovedTutor.dart';
import 'package:house_of_tutor/AdminDrawer.dart';
import 'package:house_of_tutor/AdminHome.dart';
import 'package:house_of_tutor/AdminSubject.dart';
import 'package:house_of_tutor/services/api_client.dart';

class AdminStudent extends StatefulWidget {
  const AdminStudent({super.key});

  @override
  State<AdminStudent> createState() => _AdminStudentState();
}

class _AdminStudentState extends State<AdminStudent> {
  List<dynamic> students = [];

  bool isLoading = true;

  final Set<int> processingStudents = {};

  @override
  void initState() {
    super.initState();
    getAllStudents();
  }

  // =========================================================
  // GET ALL ACTIVE STUDENTS
  // =========================================================

  Future<void> getAllStudents() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final response = await ApiClient.get(
        "/api/Admin/all-students",
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);

        if (decodedData is List) {
          setState(() {
            students = decodedData.where((student) {
              final status = (student["status"] ?? "Active")
                  .toString()
                  .trim()
                  .toLowerCase();

              return status != "blocked" &&
                  status != "rejected";
            }).toList();

            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });

          showMessage("Invalid students response");
        }
      } else {
        setState(() {
          isLoading = false;
        });

        showMessage("Failed to load students");
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage("Error: $e");
    }
  }

  // =========================================================
  // SHOW MESSAGE
  // =========================================================

  void showMessage(
    String message, {
    Color backgroundColor = const Color(0xff333333),
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // CONFIRMATION DIALOG
  // =========================================================

  Future<bool> showConfirmationDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xff17233B),
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xff68768A),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: Color(0xff68768A),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  // =========================================================
  // REMOVE STUDENT FROM LIST
  // =========================================================

  void removeStudentFromList(int id) {
    if (!mounted) return;

    setState(() {
      students.removeWhere(
        (student) =>
            student["id"].toString() == id.toString(),
      );
    });
  }

  // =========================================================
  // REJECT STUDENT
  // =========================================================

  Future<void> rejectStudent(int id) async {
    if (processingStudents.contains(id)) return;

    final confirm = await showConfirmationDialog(
      title: "Reject Student",
      message:
          "Are you sure you want to reject this student's registration?",
      confirmText: "Reject",
      confirmColor: const Color(0xffE67E22),
    );

    if (!confirm || !mounted) return;

    setState(() {
      processingStudents.add(id);
    });

    try {
      final response = await ApiClient.put(
        "/api/Admin/reject-student/$id",
        {},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Remove immediately after successful API response.
        removeStudentFromList(id);

        showMessage(
          "Student rejected successfully",
          backgroundColor: const Color(0xffE67E22),
        );
      } else {
        showMessage(
          "Failed to reject student: ${response.body}",
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;

      showMessage(
        "Error rejecting student: $e",
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          processingStudents.remove(id);
        });
      }
    }
  }

  // =========================================================
  // BLOCK STUDENT
  // =========================================================

  Future<void> blockStudent(int id) async {
    if (processingStudents.contains(id)) return;

    final confirm = await showConfirmationDialog(
      title: "Block Student",
      message:
          "Are you sure you want to block this student's account?",
      confirmText: "Block Account",
      confirmColor: const Color(0xffE74C4C),
    );

    if (!confirm || !mounted) return;

    setState(() {
      processingStudents.add(id);
    });

    try {
      final response = await ApiClient.put(
        "/api/Admin/block-student/$id",
        {},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Remove immediately after successful API response.
        removeStudentFromList(id);

        showMessage(
          "Student blocked successfully",
          backgroundColor: const Color(0xffE74C4C),
        );
      } else {
        showMessage(
          "Failed to block student: ${response.body}",
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;

      showMessage(
        "Error blocking student: $e",
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          processingStudents.remove(id);
        });
      }
    }
  }

  // =========================================================
  // INFO ROW
  // =========================================================

  Widget infoItem(IconData icon, String text) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xff68768A),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xff17233B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // STUDENT AVATAR
  // =========================================================

  Widget studentAvatar(
    dynamic student,
    String fullName,
  ) {
    final String? pictureUrl =
        (student["profilePicture"] ??
                student["profileImage"] ??
                student["picture"] ??
                student["image"])
            ?.toString();

    final String initials = fullName.trim().isEmpty
        ? "?"
        : fullName
            .trim()
            .split(" ")
            .where((e) => e.isNotEmpty)
            .map((e) => e[0])
            .take(2)
            .join()
            .toUpperCase();

    final bool hasPicture =
        pictureUrl != null &&
        pictureUrl.trim().isNotEmpty;

    return CircleAvatar(
      radius: 27.5,
      backgroundColor: const Color(0xffF0F1FF),
      backgroundImage:
          hasPicture ? NetworkImage(pictureUrl) : null,
      onBackgroundImageError:
          hasPicture ? (_, __) {} : null,
      child: hasPicture
          ? null
          : Text(
              initials,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xff5146D8),
              ),
            ),
    );
  }

  // =========================================================
  // ACTION BUTTON
  // =========================================================

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color bgColor,
    required Color fgColor,
    Color? borderColor,
    bool outlined = false,
    bool loading = false,
  }) {
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: fgColor,
              ),
            )
          else
            Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(
            loading ? "Please wait" : label,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );

    if (outlined) {
      return OutlinedButton(
        onPressed: loading ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: fgColor,
          side: BorderSide(
            color: borderColor ?? Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 10,
        ),
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: child,
    );
  }

  // =========================================================
  // STUDENT CARD
  // =========================================================

  Widget studentCard(dynamic student) {
    final String fullName =
        student["fullName"]?.toString() ?? "";

    final String email =
        student["email"]?.toString() ?? "Not Available";

    final String phone =
        student["phone"]?.toString() ?? "Not Available";

    final String cnic =
        student["cnic"]?.toString() ?? "Not Available";

    final String location =
        (student["location"] == null ||
                student["location"].toString().trim().isEmpty)
            ? "Not Available"
            : student["location"].toString();

    final int id = int.tryParse(
          student["id"].toString(),
        ) ??
        0;

    final String status =
        (student["status"] ?? "Active").toString();

    final bool isProcessing =
        processingStudents.contains(id);

    return Container(
      key: ValueKey(id),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xffE7E9ED),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NAME ROW
          Row(
            children: [
              studentAvatar(student, fullName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff101C33),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffEFFFF7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 8,
                            color: Color(0xff20B486),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            status.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xff20B486),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Divider(
            color: Color(0xffE7E9ED),
          ),

          const SizedBox(height: 8),

          // EMAIL + PHONE
          Row(
            children: [
              infoItem(Icons.email_outlined, email),
              infoItem(Icons.phone_outlined, phone),
            ],
          ),

          const SizedBox(height: 10),

          // CNIC + LOCATION
          Row(
            children: [
              infoItem(
                Icons.badge_outlined,
                "CNIC: $cnic",
              ),
              infoItem(
                Icons.location_on_outlined,
                location,
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Divider(
            color: Color(0xffE7E9ED),
          ),

          const SizedBox(height: 10),

          // ACTION BUTTONS
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  label: "Reject",
                  icon: Icons.cancel_outlined,
                  onTap: () => rejectStudent(id),
                  bgColor: const Color(0xffFFF7E8),
                  fgColor: const Color(0xffC77400),
                  borderColor: const Color(0xffF5D67B),
                  outlined: true,
                  loading: isProcessing,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  label: "Block Account",
                  icon: Icons.block,
                  onTap: () => blockStudent(id),
                  bgColor: const Color(0xffFDECEC),
                  fgColor: const Color(0xffE74C4C),
                  loading: isProcessing,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // EMPTY STUDENTS VIEW
  // =========================================================

  Widget emptyStudentsView() {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.school_outlined,
              size: 65,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 15),
            const Text(
              "No Active Students Found",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xff68768A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "All students are either blocked, rejected or no students are registered.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xff8993A3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FB),

      drawer: const AdminDrawer(),

      // =====================================================
      // APP BAR
      // =====================================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        centerTitle: true,

        leading: Builder(
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.only(
                left: 18,
                top: 13,
                bottom: 13,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xffF8F9FC),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.menu,
                    size: 29,
                    color: Color(0xff17233B),
                  ),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
            );
          },
        ),

        title: Image.asset(
          "assets/images/logo.png",
          height: 50,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Text(
              "House of Tutor",
              style: TextStyle(
                color: Color(0xff17233B),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 18,
              top: 12,
              bottom: 12,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xffF8F9FC),
                borderRadius: BorderRadius.circular(15),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.refresh,
                  size: 26,
                  color: Color(0xff20B486),
                ),
                onPressed: isLoading ? null : getAllStudents,
              ),
            ),
          ),
        ],
      ),

      // =====================================================
      // BODY
      // =====================================================

      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: getAllStudents,
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    25,
                    18,
                    25,
                  ),
                  children: [
                    // HEADER
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "All Students",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff101C33),
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffEDEFF3),
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${students.length} Total",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff17233B),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // STUDENTS LIST
                    if (students.isEmpty)
                      emptyStudentsView()
                    else
                      ...students.map(
                        (student) => studentCard(student),
                      ),
                  ],
                ),
        ),
      ),

      // =====================================================
      // BOTTOM NAVIGATION
      // =====================================================

      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: 2,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 8,
          selectedItemColor: const Color(0xff258F81),
          unselectedItemColor: const Color(0xff68768A),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          iconSize: 24,

          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),

          unselectedLabelStyle: const TextStyle(
            height: 1.0,
          ),

          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups),
              label: "Tutors",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school),
              label: "Students",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: "Subjects",
            ),
          ],

          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminHome(),
                ),
              );
            }

            if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const AdminApprovedTutor(),
                ),
              );
            }

            if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminSubject(),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
