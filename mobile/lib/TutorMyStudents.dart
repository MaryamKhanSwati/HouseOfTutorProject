import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:house_of_tutor/TutorDrawer.dart';
import 'package:house_of_tutor/TutorHome.dart';
import 'services/api_client.dart';

class TutorStudent {
  final int studentId;
  final String studentName;
  final int courseId;
  final String courseName;
  final bool isCompleted;
  final bool feedbackGiven;

  TutorStudent({
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.courseName,
    required this.isCompleted,
    required this.feedbackGiven,
  });

  factory TutorStudent.fromJson(Map<String, dynamic> json) {
    return TutorStudent(
      studentId: json["studentId"] ?? 0,
      studentName: json["studentName"] ?? "",
      courseId: json["courseId"] ?? 0,
      courseName: json["courseName"] ?? "",
      isCompleted: json["isCompleted"] ?? false,
      feedbackGiven: json["feedbackGiven"] ?? false,
    );
  }
}

/// Tutor My Students Screen

class TutorMyStudents extends StatefulWidget {
  const TutorMyStudents({super.key});

  @override
  State<TutorMyStudents> createState() => _TutorMyStudentsState();
}

class _TutorMyStudentsState extends State<TutorMyStudents> {
  bool loading = false;
  int selectedRating = 5;
  final TextEditingController commentController = TextEditingController();
  List<TutorStudent> students = [];

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  void openDrawer() {
    scaffoldKey.currentState?.openDrawer();
  }

  // ✅ FIXED BACK FUNCTION
  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TutorHome()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  //==========================================================
  // FETCH STUDENTS
  //==========================================================

  Future<void> fetchStudents() async {
    try {
      if (mounted) {
        setState(() {
          loading = true;
        });
      }

      final response = await ApiClient.get("/api/Tutor/my-students");

      debugPrint("MY STUDENTS STATUS : ${response.statusCode}");
      debugPrint("MY STUDENTS BODY : ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(response.bodyBytes));
        students = data.map((e) => TutorStudent.fromJson(e)).toList();
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiClient.messageFromBody(response.body) ??
                  "Unable to load students",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("MY STUDENTS ERROR : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error : $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  //==========================================================
  // COMPLETE COURSE
  //==========================================================

  Future<void> completeCourse(TutorStudent student) async {
    try {
      final response = await ApiClient.post(
        "/api/Tutor/complete-course",
        {"courseId": student.courseId},
      );

      debugPrint("COMPLETE COURSE : ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Course completed successfully")),
        );
        fetchStudents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiClient.messageFromBody(response.body) ??
                  "Unable to complete course",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("COMPLETE COURSE ERROR : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error : $e")),
        );
      }
    }
  }
  Future<void> giveFeedback({
    required BuildContext dialogContext,
    required TutorStudent student,
    required int rating,
    required String comment,
  }) async {
    try {
      final response = await ApiClient.post(
        "/api/Tutor/give-feedback",
        {
          "studentId": student.studentId,
          "courseId": student.courseId,
          "rating": rating,
          "comment": comment,
        },
      );
      debugPrint("GIVE FEEDBACK : ${response.body}");
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Feedback submitted successfully")),
        );
        fetchStudents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiClient.messageFromBody(response.body) ??
                  "Unable to submit feedback",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("GIVE FEEDBACK ERROR : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error : $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      drawer: const TutorDrawer(),
      backgroundColor: const Color(0xffF3F4F8),
      body: SafeArea(
        child: Column(
          children: [
            //================ HEADER =================
            Container(
              height: 80,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  // ✅ FIXED BACK BUTTON
                  InkWell(
                    onTap: _goBack,
                    child: const Icon(Icons.arrow_back, size: 32),
                  ),
                  const Spacer(),
                  Image.asset("assets/images/logo.png", height: 55),
                  const Spacer(),
                  IconButton(
                    onPressed: openDrawer,
                    icon: const Icon(Icons.menu, size: 32),
                  ),
                ],
              ),
            ),

            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : students.isEmpty
                      ? const Center(
                          child: Text(
                            "No Students Found",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: fetchStudents,
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              const Text(
                                "My Students",
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ...students.map((student) => studentCard(student)),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget studentCard(TutorStudent student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            student.studentName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          const SizedBox(height: 5),
          Text(
            student.courseName,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 18),
          ),
          const SizedBox(height: 20),
          if (!student.isCompleted)
            completeCourseButton(student)
          else
            completedSection(student),
        ],
      ),
    );
  }

  Widget completeCourseButton(TutorStudent student) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (alertContext) {
              return AlertDialog(
                title: const Text("Complete Course"),
                content: const Text(
                  "Are you sure you want to mark this course as completed?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(alertContext),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(alertContext);
                      completeCourse(student);
                    },
                    child: const Text("Complete"),
                  ),
                ],
              );
            },
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff2DB55D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.check_circle, color: Colors.white, size: 28),
        label: const Text(
          "Complete Course",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
    );
  }

  Widget completedSection(TutorStudent student) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            "Course Completed",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!student.feedbackGiven)
          feedbackButton(student)
        else
          feedbackSubmittedWidget(),
      ],
    );
  }

  Widget feedbackButton(TutorStudent student) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: () => openFeedbackDialog(student),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff2F80ED),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.rate_review, color: Colors.white),
        label: const Text(
          "Give Feedback",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget feedbackSubmittedWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Text(
          "Feedback Submitted",
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Future<void> openFeedbackDialog(TutorStudent student) async {
    selectedRating = 5;
    commentController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Student Feedback",
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        "Rating",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(5, (index) {
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedRating = index + 1;
                              });
                            },
                            child: Icon(
                              index < selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 45,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        "Comment",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: commentController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: "Write feedback...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 55,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade300,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: SizedBox(
                              height: 55,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (commentController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(statefulContext)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text("Please enter feedback"),
                                      ),
                                    );
                                    return;
                                  }
                                  await giveFeedback(
                                    dialogContext: dialogContext,
                                    student: student,
                                    rating: selectedRating,
                                    comment: commentController.text.trim(),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  "Submit",
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
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
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }
}

























































































































// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:house_of_tutor/TutorDrawer.dart';
// import 'services/api_client.dart';

// /// Tutor Student Model

// class TutorStudent {
//   final int studentId;
//   final String studentName;
//   final int courseId;
//   final String courseName;
//   final bool isCompleted;
//   final bool feedbackGiven;

//   TutorStudent({
//     required this.studentId,
//     required this.studentName,
//     required this.courseId,
//     required this.courseName,
//     required this.isCompleted,
//     required this.feedbackGiven,
//   });

//   factory TutorStudent.fromJson(Map<String, dynamic> json) {
//     return TutorStudent(
//       studentId: json["studentId"] ?? 0,
//       studentName: json["studentName"] ?? "",
//       courseId: json["courseId"] ?? 0,
//       courseName: json["courseName"] ?? "",
//       isCompleted: json["isCompleted"] ?? false,
//       feedbackGiven: json["feedbackGiven"] ?? false,
//     );
//   }
// }

// // Tutor My Students Screen

// class TutorMyStudents extends StatefulWidget {
//   const TutorMyStudents({super.key});

//   @override
//   State<TutorMyStudents> createState() => _TutorMyStudentsState();
// }

// class _TutorMyStudentsState extends State<TutorMyStudents> {
//   bool loading = false;
//   int selectedRating = 5;
//   final TextEditingController commentController = TextEditingController();
//   List<TutorStudent> students = [];

//   // Used to open the drawer from the custom header
//   final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

//   void openDrawer() {
//     scaffoldKey.currentState?.openDrawer();
//   }

//   @override
//   void initState() {
//     super.initState();
//     fetchStudents();
//   }

//   Future<void> fetchStudents() async {
//     try {
//       if (mounted) {
//         setState(() {
//           loading = true;
//         });
//       }

//       final response = await ApiClient.get("/api/Tutor/my-students");
//       print(response.body);

//       if (!mounted) return;

//       if (response.statusCode == 200) {
//         final List data = jsonDecode(utf8.decode(response.bodyBytes));
//         students = data.map((e) => TutorStudent.fromJson(e)).toList();
//         setState(() {});
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               ApiClient.messageFromBody(response.body) ?? "Unable to load students",
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Error : $e")),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           loading = false;
//         });
//       }
//     }
//   }

//   Future<void> completeCourse(TutorStudent student) async {
//     try {
//       final response = await ApiClient.post(
//         "/api/Tutor/complete-course",
//         {"courseId": student.courseId},
//       );

//       print(response.body);

//       if (!mounted) return;

//       if (response.statusCode == 200) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Course completed successfully")),
//         );
//         fetchStudents();
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               ApiClient.messageFromBody(response.body) ?? "Unable to complete course",
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Error : $e")),
//         );
//       }
//     }
//   }

//   // FIXED: Passed dialogContext into this method to pop the dialog layout, not the screen layout
//   Future<void> giveFeedback({
//     required BuildContext dialogContext,
//     required TutorStudent student,
//     required int rating,
//     required String comment,
//   }) async {
//     try {
//       final response = await ApiClient.post(
//         "/api/Tutor/give-feedback",
//         {
//           "studentId": student.studentId,
//           "courseId": student.courseId,
//           "rating": rating,
//           "comment": comment,
//         },
//       );

//       print(response.body);

//       // Safe pop using the specific dialog context instance
//       if (dialogContext.mounted) {
//         Navigator.pop(dialogContext);
//       }

//       if (!mounted) return;

//       if (response.statusCode == 200) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Feedback submitted successfully")),
//         );
//         fetchStudents();
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               ApiClient.messageFromBody(response.body) ?? "Unable to submit feedback",
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Error : $e")),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       key: scaffoldKey,
//       drawer: const TutorDrawer(),
//       backgroundColor: const Color(0xffF3F4F8),
//       body: SafeArea(
//         child: Column(
//           children: [
//             //================ HEADER =================
//             Container(
//               height: 80,
//               color: Colors.white,
//               padding: const EdgeInsets.symmetric(horizontal: 15),
//               child: Row(
//                 children: [
//                   InkWell(
//                     onTap: () => Navigator.pop(context),
//                     child: const Icon(Icons.arrow_back, size: 32),
//                   ),
//                   const Spacer(),
//                   Image.asset("assets/images/logo.png", height: 55),
//                   const Spacer(),
//                   IconButton(
//                     onPressed: openDrawer,
//                     icon: const Icon(Icons.menu, size: 32),
//                   ),
//                 ],
//               ),
//             ),
//             Expanded(
//               child: loading
//                   ? const Center(child: CircularProgressIndicator())
//                   : students.isEmpty
//                       ? const Center(
//                           child: Text(
//                             "No Students Found",
//                             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                           ),
//                         )
//                       : ListView(
//                           padding: const EdgeInsets.all(20),
//                           children: [
//                             const Text(
//                               "My Students",
//                               style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold),
//                             ),
//                             const SizedBox(height: 20),
//                             ...students.map((student) => studentCard(student)),
//                             const SizedBox(height: 30),
//                           ],
//                         ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget studentCard(TutorStudent student) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 22),
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(22),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.shade300,
//             blurRadius: 10,
//             offset: const Offset(0, 4),
//           )
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             student.studentName,
//             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
//           ),
//           const SizedBox(height: 5),
//           Text(
//             student.courseName,
//             style: TextStyle(color: Colors.grey.shade700, fontSize: 18),
//           ),
//           const SizedBox(height: 20),
//           if (!student.isCompleted)
//             completeCourseButton(student)
//           else
//             completedSection(student),
//         ],
//       ),
//     );
//   }

//   Widget completeCourseButton(TutorStudent student) {
//     return SizedBox(
//       width: double.infinity,
//       height: 58,
//       child: ElevatedButton.icon(
//         onPressed: () {
//           showDialog(
//             context: context,
//             builder: (alertContext) {
//               return AlertDialog(
//                 title: const Text("Complete Course"),
//                 content: const Text("Are you sure you want to mark this course as completed?"),
//                 actions: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(alertContext),
//                     child: const Text("Cancel"),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.pop(alertContext);
//                       completeCourse(student);
//                     },
//                     child: const Text("Complete"),
//                   )
//                 ],
//               );
//             },
//           );
//         },
//         style: ElevatedButton.styleFrom(
//           backgroundColor: const Color(0xff2DB55D),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         ),
//         icon: const Icon(Icons.check_circle, color: Colors.white, size: 28),
//         label: const Text(
//           "Complete Course",
//           style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
//         ),
//       ),
//     );
//   }

//   Widget completedSection(TutorStudent student) {
//     return Column(
//       children: [
//         Container(
//           width: double.infinity,
//           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//           decoration: BoxDecoration(
//             color: Colors.green.shade100,
//             borderRadius: BorderRadius.circular(14),
//           ),
//           child: const Text(
//             "Course Completed",
//             style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18),
//           ),
//         ),
//         const SizedBox(height: 16),
//         if (!student.feedbackGiven) feedbackButton(student) else feedbackSubmittedWidget(),
//       ],
//     );
//   }

//   Widget feedbackButton(TutorStudent student) {
//     return SizedBox(
//       width: double.infinity,
//       height: 58,
//       child: ElevatedButton.icon(
//         onPressed: () => openFeedbackDialog(student),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: const Color(0xff2F80ED),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         ),
//         icon: const Icon(Icons.rate_review, color: Colors.white),
//         label: const Text(
//           "Give Feedback",
//           style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
//         ),
//       ),
//     );
//   }

//   Widget feedbackSubmittedWidget() {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.symmetric(vertical: 16),
//       decoration: BoxDecoration(
//         color: Colors.green.shade100,
//         borderRadius: BorderRadius.circular(14),
//       ),
//       child: const Center(
//         child: Text(
//           "Feedback Submitted",
//           style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
//         ),
//       ),
//     );
//   }

//   Future<void> openFeedbackDialog(TutorStudent student) async {
//     selectedRating = 5;
//     commentController.clear();

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (dialogContext) {
//         return StatefulBuilder(
//           builder: (statefulContext, setDialogState) {
//             return Dialog(
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
//               child: Padding(
//                 padding: const EdgeInsets.all(25),
//                 child: SingleChildScrollView(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         "Student Feedback",
//                         style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
//                       ),
//                       const SizedBox(height: 30),
//                       const Text(
//                         "Rating",
//                         style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                       ),
//                       const SizedBox(height: 15),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: List.generate(5, (index) {
//                           return InkWell(
//                             onTap: () {
//                               setDialogState(() {
//                                 selectedRating = index + 1;
//                               });
//                             },
//                             child: Icon(
//                               index < selectedRating ? Icons.star : Icons.star_border,
//                               color: Colors.amber,
//                               size: 45,
//                             ),
//                           );
//                         }),
//                       ),
//                       const SizedBox(height: 30),
//                       const Text(
//                         "Comment",
//                         style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                       ),
//                       const SizedBox(height: 10),
//                       TextField(
//                         controller: commentController,
//                         maxLines: 5,
//                         decoration: InputDecoration(
//                           hintText: "Write feedback...",
//                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
//                         ),
//                       ),
//                       const SizedBox(height: 30),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: SizedBox(
//                               height: 55,
//                               child: ElevatedButton(
//                                 onPressed: () => Navigator.pop(dialogContext),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.grey.shade300,
//                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                                 ),
//                                 child: const Text(
//                                   "Cancel",
//                                   style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 15),
//                           Expanded(
//                             child: SizedBox(
//                               height: 55,
//                               child: ElevatedButton(
//                                 onPressed: () async {
//                                   if (commentController.text.trim().isEmpty) {
//                                     ScaffoldMessenger.of(statefulContext).showSnackBar(
//                                       const SnackBar(content: Text("Please enter feedback")),
//                                     );
//                                     return;
//                                   }

//                                   await giveFeedback(
//                                     dialogContext: dialogContext, // Pass context explicitly here
//                                     student: student,
//                                     rating: selectedRating,
//                                     comment: commentController.text.trim(),
//                                   );
//                                 },
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.blue,
//                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                                 ),
//                                 child: const Text(
//                                   "Submit",
//                                   style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       )
//                     ],
//                   ),
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//   void dispose() {
//     commentController.dispose();
//     super.dispose();
//   }
// }
















































































// // import 'dart:convert';

// // import 'package:flutter/material.dart';
// // import 'package:house_of_tutor/TutorDrawer.dart';


// // import 'services/api_client.dart';

// // ///==========================================================
// // /// Tutor Student Model
// // ///==========================================================

// // class TutorStudent {
// //   final int studentId;

// //   final String studentName;

// //   final int courseId;

// //   final String courseName;

// //   final bool isCompleted;

// //   final bool feedbackGiven;

// //   TutorStudent({
// //     required this.studentId,
// //     required this.studentName,
// //     required this.courseId,
// //     required this.courseName,
// //     required this.isCompleted,
// //     required this.feedbackGiven,
// //   });

// //   factory TutorStudent.fromJson(Map<String, dynamic> json) {
// //     return TutorStudent(
// //       studentId: json["studentId"] ?? 0,
// //       studentName: json["studentName"] ?? "",
// //       courseId: json["courseId"] ?? 0,
// //       courseName: json["courseName"] ?? "",
// //       isCompleted: json["isCompleted"] ?? false,
// //       feedbackGiven: json["feedbackGiven"] ?? false,
// //     );
// //   }
// // }

// // ///==========================================================
// // /// Tutor My Students Screen
// // ///==========================================================

// // class TutorMyStudents extends StatefulWidget {
// //   const TutorMyStudents({super.key});

// //   @override
// //   State<TutorMyStudents> createState() => _TutorMyStudentsState();
// // }

// // class _TutorMyStudentsState extends State<TutorMyStudents> {
// //   bool loading = false;
// //   int selectedRating = 5;

// //   final TextEditingController commentController = TextEditingController();

// //   List<TutorStudent> students = [];

// //   /// Used to open the drawer from the custom header
// //   final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

// //   void openDrawer() {
// //     scaffoldKey.currentState?.openDrawer();
// //   }

// //   @override
// //   void initState() {
// //     super.initState();

// //     fetchStudents();
// //   }

// //   Future<void> fetchStudents() async {
// //     try {
// //       if (mounted) {
// //         setState(() {
// //           loading = true;
// //         });
// //       }

// //       final response = await ApiClient.get(
// //         "/api/Tutor/my-students",
// //       );

// //       print(response.body);

// //       if (response.statusCode == 200) {
// //         final List data = jsonDecode(
// //           utf8.decode(response.bodyBytes),
// //         );

// //         students = data
// //             .map(
// //               (e) => TutorStudent.fromJson(e),
// //             )
// //             .toList();

// //         if (mounted) {
// //           setState(() {});
// //         }
// //       } else {
// //         if (mounted) {
// //           ScaffoldMessenger.of(context).showSnackBar(
// //             SnackBar(
// //               content: Text(
// //                 ApiClient.messageFromBody(
// //                       response.body,
// //                     ) ??
// //                     "Unable to load students",
// //               ),
// //             ),
// //           );
// //         }
// //       }
// //     } catch (e) {
// //       if (mounted) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(
// //             content: Text(
// //               "Error : $e",
// //             ),
// //           ),
// //         );
// //       }
// //     } finally {
// //       if (mounted) {
// //         setState(() {
// //           loading = false;
// //         });
// //       }
// //     }
// //   }

// //   Future<void> completeCourse(TutorStudent student) async {
// //     try {
// //       final response = await ApiClient.post(
// //         "/api/Tutor/complete-course",
// //         {
// //           "courseId": student.courseId,
// //         },
// //       );

// //       print(response.body);

// //       if (response.statusCode == 200) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(
// //             content: Text(
// //               "Course completed successfully",
// //             ),
// //           ),
// //         );

// //         fetchStudents();
// //       } else {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(
// //             content: Text(
// //               ApiClient.messageFromBody(
// //                     response.body,
// //                   ) ??
// //                   "Unable to complete course",
// //             ),
// //           ),
// //         );
// //       }
// //     } catch (e) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //           content: Text(
// //             "Error : $e",
// //           ),
// //         ),
// //       );
// //     }
// //   }

// //   Future<void> giveFeedback({
// //     required TutorStudent student,
// //     required int rating,
// //     required String comment,
// //   }) async {
// //     try {
// //       final response = await ApiClient.post(
// //         "/api/Tutor/give-feedback",
// //         {
// //           "studentId": student.studentId,
// //           "courseId": student.courseId,
// //           "rating": rating,
// //           "comment": comment,
// //         },
// //       );

// //       print(response.body);

// //       if (response.statusCode == 200) {
// //         Navigator.pop(context);

// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(
// //             content: Text(
// //               "Feedback submitted successfully",
// //             ),
// //           ),
// //         );

// //         fetchStudents();
// //       } else {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(
// //             content: Text(
// //               ApiClient.messageFromBody(
// //                     response.body,
// //                   ) ??
// //                   "Unable to submit feedback",
// //             ),
// //           ),
// //         );
// //       }
// //     } catch (e) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //           content: Text(
// //             "Error : $e",
// //           ),
// //         ),
// //       );
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       key: scaffoldKey,
// //       drawer: const TutorDrawer(),
// //       backgroundColor: const Color(0xffF3F4F8),
// //       body: SafeArea(
// //         child: Column(
// //           children: [
// //             //================ HEADER =================

// //             Container(
// //               height: 80,
// //               color: Colors.white,
// //               padding: const EdgeInsets.symmetric(horizontal: 15),
// //               child: Row(
// //                 children: [
// //                   InkWell(
// //                     onTap: () {
// //                       Navigator.pop(context);
// //                     },
// //                     child: const Icon(
// //                       Icons.arrow_back,
// //                       size: 32,
// //                     ),
// //                   ),
// //                   const Spacer(),
// //                   Image.asset(
// //                     "assets/images/logo.png",
// //                     height: 55,
// //                   ),
// //                   const Spacer(),
// //                   IconButton(
// //                     onPressed: openDrawer,
// //                     icon: const Icon(
// //                       Icons.menu,
// //                       size: 32,
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),

// //             Expanded(
// //               child: loading
// //                   ? const Center(
// //                       child: CircularProgressIndicator(),
// //                     )
// //                   : students.isEmpty
// //                       ? const Center(
// //                           child: Text(
// //                             "No Students Found",
// //                             style: TextStyle(
// //                               fontSize: 18,
// //                               fontWeight: FontWeight.bold,
// //                             ),
// //                           ),
// //                         )
// //                       : ListView(
// //                           padding: const EdgeInsets.all(20),
// //                           children: [
// //                             const Text(
// //                               "My Students",
// //                               style: TextStyle(
// //                                 fontSize: 38,
// //                                 fontWeight: FontWeight.bold,
// //                               ),
// //                             ),
// //                             const SizedBox(height: 20),
// //                             ...students.map(
// //                               (student) => studentCard(student),
// //                             ),
// //                             const SizedBox(height: 30),
// //                           ],
// //                         ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   Widget studentCard(TutorStudent student) {
// //     return Container(
// //       margin: const EdgeInsets.only(bottom: 22),
// //       padding: const EdgeInsets.all(18),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(22),
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.grey.shade300,
// //             blurRadius: 10,
// //             offset: const Offset(0, 4),
// //           )
// //         ],
// //       ),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Text(
// //             student.studentName,
// //             style: const TextStyle(
// //               fontWeight: FontWeight.bold,
// //               fontSize: 22,
// //             ),
// //           ),
// //           const SizedBox(height: 5),
// //           Text(
// //             student.courseName,
// //             style: TextStyle(
// //               color: Colors.grey.shade700,
// //               fontSize: 18,
// //             ),
// //           ),
// //           const SizedBox(height: 20),
// //           if (!student.isCompleted)
// //             completeCourseButton(student)
// //           else
// //             completedSection(student),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget completeCourseButton(TutorStudent student) {
// //     return SizedBox(
// //       width: double.infinity,
// //       height: 58,
// //       child: ElevatedButton.icon(
// //         onPressed: () {
// //           showDialog(
// //             context: context,
// //             builder: (_) {
// //               return AlertDialog(
// //                 title: const Text("Complete Course"),
// //                 content: const Text(
// //                   "Are you sure you want to mark this course as completed?",
// //                 ),
// //                 actions: [
// //                   TextButton(
// //                     onPressed: () {
// //                       Navigator.pop(context);
// //                     },
// //                     child: const Text("Cancel"),
// //                   ),
// //                   ElevatedButton(
// //                     onPressed: () {
// //                       Navigator.pop(context);

// //                       completeCourse(student);
// //                     },
// //                     child: const Text("Complete"),
// //                   )
// //                 ],
// //               );
// //             },
// //           );
// //         },
// //         style: ElevatedButton.styleFrom(
// //           backgroundColor: const Color(0xff2DB55D),
// //           shape: RoundedRectangleBorder(
// //             borderRadius: BorderRadius.circular(16),
// //           ),
// //         ),
// //         icon: const Icon(
// //           Icons.check_circle,
// //           color: Colors.white,
// //           size: 28,
// //         ),
// //         label: const Text(
// //           "Complete Course",
// //           style: TextStyle(
// //             color: Colors.white,
// //             fontWeight: FontWeight.bold,
// //             fontSize: 22,
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   Widget completedSection(TutorStudent student) {
// //     return Column(
// //       children: [
// //         Container(
// //           width: double.infinity,
// //           padding: const EdgeInsets.symmetric(
// //             horizontal: 20,
// //             vertical: 16,
// //           ),
// //           decoration: BoxDecoration(
// //             color: Colors.green.shade100,
// //             borderRadius: BorderRadius.circular(14),
// //           ),
// //           child: const Text(
// //             "Course Completed",
// //             style: TextStyle(
// //               fontWeight: FontWeight.bold,
// //               color: Colors.green,
// //               fontSize: 18,
// //             ),
// //           ),
// //         ),
// //         const SizedBox(height: 16),
// //         if (!student.feedbackGiven)
// //           feedbackButton(student)
// //         else
// //           feedbackSubmittedWidget(),
// //       ],
// //     );
// //   }

// //   Widget feedbackButton(TutorStudent student) {
// //     return SizedBox(
// //       width: double.infinity,
// //       height: 58,
// //       child: ElevatedButton.icon(
// //         onPressed: () {
// //           openFeedbackDialog(student);
// //         },
// //         style: ElevatedButton.styleFrom(
// //           backgroundColor: const Color(0xff2F80ED),
// //           shape: RoundedRectangleBorder(
// //             borderRadius: BorderRadius.circular(16),
// //           ),
// //         ),
// //         icon: const Icon(
// //           Icons.rate_review,
// //           color: Colors.white,
// //         ),
// //         label: const Text(
// //           "Give Feedback",
// //           style: TextStyle(
// //             color: Colors.white,
// //             fontSize: 22,
// //             fontWeight: FontWeight.bold,
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   Widget feedbackSubmittedWidget() {
// //     return Container(
// //       width: double.infinity,
// //       padding: const EdgeInsets.symmetric(
// //         vertical: 16,
// //       ),
// //       decoration: BoxDecoration(
// //         color: Colors.green.shade100,
// //         borderRadius: BorderRadius.circular(14),
// //       ),
// //       child: const Center(
// //         child: Text(
// //           "Feedback Submitted",
// //           style: TextStyle(
// //             color: Colors.green,
// //             fontWeight: FontWeight.bold,
// //             fontSize: 18,
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   Future<void> openFeedbackDialog(TutorStudent student) async {
// //     selectedRating = 5;
// //     commentController.clear();

// //     showDialog(
// //       context: context,
// //       barrierDismissible: false,
// //       builder: (context) {
// //         return StatefulBuilder(
// //           builder: (context, setDialogState) {
// //             return Dialog(
// //               shape: RoundedRectangleBorder(
// //                 borderRadius: BorderRadius.circular(25),
// //               ),
// //               child: Padding(
// //                 padding: const EdgeInsets.all(25),
// //                 child: SingleChildScrollView(
// //                   child: Column(
// //                     mainAxisSize: MainAxisSize.min,
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       const Text(
// //                         "Student Feedback",
// //                         style: TextStyle(
// //                           fontSize: 34,
// //                           fontWeight: FontWeight.bold,
// //                         ),
// //                       ),
// //                       const SizedBox(height: 30),
// //                       const Text(
// //                         "Rating",
// //                         style: TextStyle(
// //                           fontSize: 24,
// //                           fontWeight: FontWeight.bold,
// //                         ),
// //                       ),
// //                       const SizedBox(height: 15),
// //                       Row(
// //                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //                         children: List.generate(5, (index) {
// //                           return InkWell(
// //                             onTap: () {
// //                               setDialogState(() {
// //                                 selectedRating = index + 1;
// //                               });
// //                             },
// //                             child: Icon(
// //                               index < selectedRating
// //                                   ? Icons.star
// //                                   : Icons.star_border,
// //                               color: Colors.amber,
// //                               size: 45,
// //                             ),
// //                           );
// //                         }),
// //                       ),
// //                       const SizedBox(height: 30),
// //                       const Text(
// //                         "Comment",
// //                         style: TextStyle(
// //                           fontSize: 24,
// //                           fontWeight: FontWeight.bold,
// //                         ),
// //                       ),
// //                       const SizedBox(height: 10),
// //                       TextField(
// //                         controller: commentController,
// //                         maxLines: 5,
// //                         decoration: InputDecoration(
// //                           hintText: "Write feedback...",
// //                           border: OutlineInputBorder(
// //                             borderRadius: BorderRadius.circular(16),
// //                           ),
// //                         ),
// //                       ),
// //                       const SizedBox(height: 30),
// //                       Row(
// //                         children: [
// //                           Expanded(
// //                             child: SizedBox(
// //                               height: 55,
// //                               child: ElevatedButton(
// //                                 onPressed: () {
// //                                   Navigator.pop(context);
// //                                 },
// //                                 style: ElevatedButton.styleFrom(
// //                                   backgroundColor: Colors.grey.shade300,
// //                                   shape: RoundedRectangleBorder(
// //                                     borderRadius: BorderRadius.circular(16),
// //                                   ),
// //                                 ),
// //                                 child: const Text(
// //                                   "Cancel",
// //                                   style: TextStyle(
// //                                     color: Colors.black,
// //                                     fontSize: 20,
// //                                     fontWeight: FontWeight.bold,
// //                                   ),
// //                                 ),
// //                               ),
// //                             ),
// //                           ),
// //                           const SizedBox(width: 15),
// //                           Expanded(
// //                             child: SizedBox(
// //                               height: 55,
// //                               child: ElevatedButton(
// //                                 onPressed: () async {
// //                                   if (commentController.text.trim().isEmpty) {
// //                                     ScaffoldMessenger.of(context).showSnackBar(
// //                                       const SnackBar(
// //                                         content: Text(
// //                                           "Please enter feedback",
// //                                         ),
// //                                       ),
// //                                     );

// //                                     return;
// //                                   }

// //                                   await giveFeedback(
// //                                     student: student,
// //                                     rating: selectedRating,
// //                                     comment: commentController.text.trim(),
// //                                   );
// //                                 },
// //                                 style: ElevatedButton.styleFrom(
// //                                   backgroundColor: Colors.blue,
// //                                   shape: RoundedRectangleBorder(
// //                                     borderRadius: BorderRadius.circular(16),
// //                                   ),
// //                                 ),
// //                                 child: const Text(
// //                                   "Submit",
// //                                   style: TextStyle(
// //                                     fontSize: 20,
// //                                     color: Colors.white,
// //                                     fontWeight: FontWeight.bold,
// //                                   ),
// //                                 ),
// //                               ),
// //                             ),
// //                           ),
// //                         ],
// //                       )
// //                     ],
// //                   ),
// //                 ),
// //               ),
// //             );
// //           },
// //         );
// //       },
// //     );
// //   }

// //   @override
// //   void dispose() {
// //     commentController.dispose();
// //     super.dispose();
// //   }
// // }