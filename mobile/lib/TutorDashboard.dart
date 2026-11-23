import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:house_of_tutor/TutorHome.dart';
import 'package:house_of_tutor/services/api_client.dart';

class TutorDashboard extends StatefulWidget {
  const TutorDashboard({super.key});

  @override
  State<TutorDashboard> createState() => _TutorDashboardScreenState();
}

class _TutorDashboardScreenState extends State<TutorDashboard> {
  bool loading = true;
  DashboardModel? dashboard;
  final Set<int> expandedStudents = {};

  @override
  void initState() {
    super.initState();
    fetchDashboard();
  }

  Future<void> fetchDashboard() async {
    try {
      if (mounted) setState(() => loading = true);

      final response = await ApiClient.get("/api/Tutor/my-dashboard");

      debugPrint("DASHBOARD STATUS : ${response.statusCode}");
      debugPrint("DASHBOARD BODY : ${response.body}");

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            dashboard = DashboardModel.fromJson(json);
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ApiClient.messageFromBody(response.body) ??
                    "Unable to load dashboard",
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("DASHBOARD ERROR : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

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
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            // ================ HEADER =================
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(
                left: 18,
                right: 18,
                top: 15,
                bottom: 18,
              ),
              child: Row(
                children: [
                  // ✅ SIRF BACK BUTTON
                  IconButton(
                    onPressed: _goBack,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.black,
                      size: 34,
                    ),
                  ),

                  const Spacer(),

                  Column(
                    children: [
                      Image.asset(
                        "assets/images/logo.png",
                        height: 55,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "House of Tutor",
                        style: TextStyle(
                          color: Color(0xff16897F),
                          fontWeight: FontWeight.w600,
                          fontSize: 19,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ✅ Invisible box for centering logo
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ================ BODY =================
            Expanded(
              child: RefreshIndicator(
                onRefresh: fetchDashboard,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // ================ GREEN CARD =================
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xff16897F),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Total Classes",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 25),
                              Text(
                                "${dashboard?.totalClasses ?? 0}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 60,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 25),

                        // ================ STUDENTS LIST =================
                        dashboard == null || dashboard!.students.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.only(top: 40),
                                child: Center(
                                  child: Text(
                                    "No students yet",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: dashboard!.students.length,
                                itemBuilder: (context, index) {
                                  final student = dashboard!.students[index];
                                  final expanded =
                                      expandedStudents.contains(index);

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 18),
                                    elevation: 4,
                                    shadowColor: Colors.black12,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Column(
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                if (expanded) {
                                                  expandedStudents.remove(index);
                                                } else {
                                                  expandedStudents.add(index);
                                                }
                                              });
                                            },
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        student.studentName,
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        "Total Classes: ${student.totalClasses}",
                                                        style: const TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Icon(
                                                  expanded
                                                      ? Icons.keyboard_arrow_up
                                                      : Icons.keyboard_arrow_down,
                                                  size: 32,
                                                ),
                                              ],
                                            ),
                                          ),
                                          AnimatedCrossFade(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            crossFadeState: expanded
                                                ? CrossFadeState.showSecond
                                                : CrossFadeState.showFirst,
                                            firstChild: const SizedBox(),
                                            secondChild: Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 20),
                                              child: Column(
                                                children: List.generate(
                                                  student.classes.length,
                                                  (i) {
                                                    final item =
                                                        student.classes[i];
                                                    return Column(
                                                      children: [
                                                        const Divider(height: 1),
                                                        const SizedBox(height: 18),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    "Request ID: ${item.requestId}",
                                                                    style: const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      fontSize: 18,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      height: 10),
                                                                  Text(
                                                                    "Date: ${item.classDate == null || item.classDate == 'null' ? 'N/A' : item.classDate}",
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            17),
                                                                  ),
                                                                  const SizedBox(
                                                                      height: 8),
                                                                  Text(
                                                                    "Time: ${item.time.isEmpty ? 'N/A' : item.time}",
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            17),
                                                                  ),
                                                                  const SizedBox(
                                                                      height: 8),
                                                                  Text(
                                                                    "Type: ${item.requestType.isEmpty ? 'N/A' : item.requestType}",
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            17),
                                                                  ),
                                                                  const SizedBox(
                                                                      height: 8),
                                                                  Text(
                                                                    "Status: ${item.status}",
                                                                    style: TextStyle(
                                                                      fontSize: 17,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      color: item.status.toLowerCase() ==
                                                                              "accepted"
                                                                          ? Colors
                                                                              .green
                                                                          : item.status.toLowerCase() ==
                                                                                  "complete"
                                                                              ? Colors
                                                                                  .blue
                                                                              : Colors
                                                                                  .orange,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 18),
                                                        if (i !=
                                                            student.classes
                                                                    .length -
                                                                1)
                                                          const Divider(height: 1),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
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

// ==========================================================
// Models
// ==========================================================

class DashboardModel {
  final int totalClasses;
  final List<StudentModel> students;

  DashboardModel({required this.totalClasses, required this.students});

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      totalClasses: json["totalClasses"] ?? 0,
      students: (json["students"] as List? ?? [])
          .map((e) => StudentModel.fromJson(e))
          .toList(),
    );
  }
}

class StudentModel {
  final int studentId;
  final String studentName;
  final int totalClasses;
  final List<ClassModel> classes;

  StudentModel({
    required this.studentId,
    required this.studentName,
    required this.totalClasses,
    required this.classes,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      studentId: json["studentId"] ?? 0,
      studentName: json["studentName"] ?? "",
      totalClasses: json["totalClasses"] ?? 0,
      classes: (json["classes"] as List? ?? [])
          .map((e) => ClassModel.fromJson(e))
          .toList(),
    );
  }
}

class ClassModel {
  final int requestId;
  final String? classDate;
  final String time;
  final String requestType;
  final String status;

  ClassModel({
    required this.requestId,
    required this.classDate,
    required this.time,
    required this.requestType,
    required this.status,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      requestId: json["requestId"] ?? 0,
      classDate: json["classDate"]?.toString(),
      time: json["time"] ?? "",
      requestType: json["requestType"] ?? "",
      status: json["status"] ?? "",
    );
  }
}
































































// import 'dart:convert';

// import 'package:flutter/material.dart';
// //import 'package:house_of_tutor/TutorDrawer.dart';
// import 'package:house_of_tutor/TutorHome.dart';
// import 'package:house_of_tutor/services/api_client.dart';

// class TutorDashboard extends StatefulWidget {
//   const TutorDashboard({super.key});

//   @override
//   State<TutorDashboard> createState() => _TutorDashboardScreenState();
// }

// class _TutorDashboardScreenState extends State<TutorDashboard> {
//   bool loading = true;

//   DashboardModel? dashboard;

//   final Set<int> expandedStudents = {};

//   final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

//   // void openDrawer() {
//   //   scaffoldKey.currentState?.openDrawer();
//   // }

//   @override
//   void initState() {
//     super.initState();
//     fetchDashboard();
//   }

//   Future<void> fetchDashboard() async {
//     try {
//       if (mounted) {
//         setState(() {
//           loading = true;
//         });
//       }

//       final response = await ApiClient.get("/api/Tutor/my-dashboard");

//       debugPrint("DASHBOARD STATUS : ${response.statusCode}");
//       debugPrint("DASHBOARD BODY : ${response.body}");

//       if (response.statusCode == 200) {
//         final json = jsonDecode(utf8.decode(response.bodyBytes));

//         if (mounted) {
//           setState(() {
//             dashboard = DashboardModel.fromJson(json);
//           });
//         }
//       } else {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 ApiClient.messageFromBody(response.body) ??
//                     "Unable to load dashboard",
//               ),
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       debugPrint("DASHBOARD ERROR : $e");
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text("Error : $e"),
//           ),
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

//   @override
//   Widget build(BuildContext context) {
//     if (loading) {
//       return Scaffold(
//         key: scaffoldKey,
//         body: const Center(
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }

//     return Scaffold(
//       key: scaffoldKey,
//       //drawer: const TutorDrawer(),
//       backgroundColor: const Color(0xffF3F5FB),
//       body: SafeArea(
//         child: Column(
//           children: [
//             // ================ HEADER =================
//             Container(
//               color: Colors.white,
//               padding: const EdgeInsets.only(
//                 left: 18,
//                 right: 18,
//                 top: 15,
//                 bottom: 18,
//               ),
//               child: Row(
//                 children: [
//                   // ✅ FIXED BACK BUTTON
//                   IconButton(
//                     onPressed: () {
//                       if (Navigator.canPop(context)) {
//                         Navigator.pop(context);
//                       } else {
//                         Navigator.pushReplacement(
//                           context,
//                           MaterialPageRoute(
//                             builder: (_) => TutorHome(),
//                           ),
//                         );
//                       }
//                     },
//                     icon: const Icon(
//                       Icons.arrow_back,
//                       color: Colors.black,
//                       size: 34,
//                     ),
//                   ),

//                   const Spacer(),

//                   Column(
//                     children: [
//                       Image.asset(
//                         "assets/images/logo.png",
//                         height: 55,
//                       ),
//                       const SizedBox(height: 5),
//                       const Text(
//                         "House of Tutor",
//                         style: TextStyle(
//                           color: Color(0xff16897F),
//                           fontWeight: FontWeight.w600,
//                           fontSize: 19,
//                         ),
//                       ),
//                     ],
//                   ),

//                   const Spacer(),

//                   // IconButton(
//                   //   onPressed: openDrawer,
//                   //   icon: const Icon(
//                   //     Icons.menu,
//                   //     color: Colors.black,
//                   //     size: 34,
//                   //   ),
//                   // ),
//                 ],
//               ),
//             ),

//             // ================ BODY =================
//             Expanded(
//               child: RefreshIndicator(
//                 onRefresh: fetchDashboard,
//                 child: SingleChildScrollView(
//                   physics: const AlwaysScrollableScrollPhysics(),
//                   child: Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: Column(
//                       children: [
//                         // ================ GREEN CARD =================
//                         Container(
//                           width: double.infinity,
//                           padding: const EdgeInsets.all(22),
//                           decoration: BoxDecoration(
//                             color: const Color(0xff16897F),
//                             borderRadius: BorderRadius.circular(25),
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text(
//                                 "Total Classes",
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 20,
//                                 ),
//                               ),
//                               const SizedBox(height: 25),
//                               Text(
//                                 "${dashboard?.totalClasses ?? 0}",
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 60,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),

//                         const SizedBox(height: 25),

//                         // ================ STUDENTS LIST =================
//                         dashboard == null || dashboard!.students.isEmpty
//                             ? const Padding(
//                                 padding: EdgeInsets.only(top: 40),
//                                 child: Center(
//                                   child: Text(
//                                     "No students yet",
//                                     style: TextStyle(
//                                       fontSize: 16,
//                                       color: Colors.grey,
//                                     ),
//                                   ),
//                                 ),
//                               )
//                             : ListView.builder(
//                                 shrinkWrap: true,
//                                 physics: const NeverScrollableScrollPhysics(),
//                                 itemCount: dashboard!.students.length,
//                                 itemBuilder: (context, index) {
//                                   final student = dashboard!.students[index];
//                                   final expanded =
//                                       expandedStudents.contains(index);

//                                   return Card(
//                                     margin: const EdgeInsets.only(bottom: 18),
//                                     elevation: 4,
//                                     shadowColor: Colors.black12,
//                                     shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(20),
//                                     ),
//                                     child: Padding(
//                                       padding: const EdgeInsets.all(18),
//                                       child: Column(
//                                         children: [
//                                           // ---- STUDENT HEADER ----
//                                           InkWell(
//                                             onTap: () {
//                                               setState(() {
//                                                 if (expanded) {
//                                                   expandedStudents
//                                                       .remove(index);
//                                                 } else {
//                                                   expandedStudents.add(index);
//                                                 }
//                                               });
//                                             },
//                                             child: Row(
//                                               children: [
//                                                 Expanded(
//                                                   child: Column(
//                                                     crossAxisAlignment:
//                                                         CrossAxisAlignment
//                                                             .start,
//                                                     children: [
//                                                       Text(
//                                                         student.studentName,
//                                                         style: const TextStyle(
//                                                           fontSize: 18,
//                                                           fontWeight:
//                                                               FontWeight.bold,
//                                                         ),
//                                                       ),
//                                                       const SizedBox(height: 8),
//                                                       Text(
//                                                         "Total Classes: ${student.totalClasses}",
//                                                         style: const TextStyle(
//                                                           color: Colors.grey,
//                                                           fontSize: 15,
//                                                         ),
//                                                       ),
//                                                     ],
//                                                   ),
//                                                 ),
//                                                 Icon(
//                                                   expanded
//                                                       ? Icons.keyboard_arrow_up
//                                                       : Icons
//                                                           .keyboard_arrow_down,
//                                                   size: 32,
//                                                 ),
//                                               ],
//                                             ),
//                                           ),

//                                           // ---- CLASS DETAILS (EXPANDABLE) ----
//                                           AnimatedCrossFade(
//                                             duration: const Duration(
//                                                 milliseconds: 300),
//                                             crossFadeState: expanded
//                                                 ? CrossFadeState.showSecond
//                                                 : CrossFadeState.showFirst,
//                                             firstChild: const SizedBox(),
//                                             secondChild: Padding(
//                                               padding: const EdgeInsets.only(
//                                                   top: 20),
//                                               child: Column(
//                                                 children: List.generate(
//                                                   student.classes.length,
//                                                   (i) {
//                                                     final item =
//                                                         student.classes[i];

//                                                     return Column(
//                                                       children: [
//                                                         const Divider(
//                                                             height: 1),
//                                                         const SizedBox(
//                                                             height: 18),
//                                                         Row(
//                                                           crossAxisAlignment:
//                                                               CrossAxisAlignment
//                                                                   .start,
//                                                           children: [
//                                                             Expanded(
//                                                               child: Column(
//                                                                 crossAxisAlignment:
//                                                                     CrossAxisAlignment
//                                                                         .start,
//                                                                 children: [
//                                                                   Text(
//                                                                     "Request ID: ${item.requestId}",
//                                                                     style: const TextStyle(
//                                                                       fontWeight:
//                                                                           FontWeight
//                                                                               .w500,
//                                                                       fontSize:
//                                                                           18,
//                                                                     ),
//                                                                   ),
//                                                                   const SizedBox(
//                                                                       height:
//                                                                           10),
//                                                                   Text(
//                                                                     "Date: ${item.classDate == null || item.classDate == 'null' ? 'N/A' : item.classDate}",
//                                                                     style: const TextStyle(
//                                                                         fontSize:
//                                                                             17),
//                                                                   ),
//                                                                   const SizedBox(
//                                                                       height:
//                                                                           8),
//                                                                   Text(
//                                                                     "Time: ${item.time.isEmpty ? 'N/A' : item.time}",
//                                                                     style: const TextStyle(
//                                                                         fontSize:
//                                                                             17),
//                                                                   ),
//                                                                   const SizedBox(
//                                                                       height:
//                                                                           8),
//                                                                   Text(
//                                                                     "Type: ${item.requestType.isEmpty ? 'N/A' : item.requestType}",
//                                                                     style: const TextStyle(
//                                                                         fontSize:
//                                                                             17),
//                                                                   ),
//                                                                   const SizedBox(
//                                                                       height:
//                                                                           8),
//                                                                   Text(
//                                                                     "Status: ${item.status}",
//                                                                     style:
//                                                                         TextStyle(
//                                                                       fontSize:
//                                                                           17,
//                                                                       fontWeight:
//                                                                           FontWeight
//                                                                               .w500,
//                                                                       color: item
//                                                                                   .status
//                                                                                   .toLowerCase() ==
//                                                                               "accepted"
//                                                                           ? Colors
//                                                                               .green
//                                                                           : item.status.toLowerCase() ==
//                                                                                   "complete"
//                                                                               ? Colors
//                                                                                   .blue
//                                                                               : Colors
//                                                                                   .orange,
//                                                                     ),
//                                                                   ),
//                                                                 ],
//                                                               ),
//                                                             ),
//                                                           ],
//                                                         ),
//                                                         const SizedBox(
//                                                             height: 18),
//                                                         if (i !=
//                                                             student.classes
//                                                                     .length -
//                                                                 1)
//                                                           const Divider(
//                                                               height: 1),
//                                                       ],
//                                                     );
//                                                   },
//                                                 ),
//                                               ),
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   );
//                                 },
//                               ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // Dashboard Model

// class DashboardModel {
//   final int totalClasses;
//   final List<StudentModel> students;

//   DashboardModel({
//     required this.totalClasses,
//     required this.students,
//   });

//   factory DashboardModel.fromJson(Map<String, dynamic> json) {
//     return DashboardModel(
//       totalClasses: json["totalClasses"] ?? 0,
//       students: (json["students"] as List? ?? [])
//           .map((e) => StudentModel.fromJson(e))
//           .toList(),
//     );
//   }
// }


// // Student Model

// class StudentModel {
//   final int studentId;
//   final String studentName;
//   final int totalClasses;
//   final List<ClassModel> classes;

//   StudentModel({
//     required this.studentId,
//     required this.studentName,
//     required this.totalClasses,
//     required this.classes,
//   });

//   factory StudentModel.fromJson(Map<String, dynamic> json) {
//     return StudentModel(
//       studentId: json["studentId"] ?? 0,
//       studentName: json["studentName"] ?? "",
//       totalClasses: json["totalClasses"] ?? 0,
//       classes: (json["classes"] as List? ?? [])
//           .map((e) => ClassModel.fromJson(e))
//           .toList(),
//     );
//   }
// }

// // ==========================================================
// // Class Model
// // ==========================================================

// class ClassModel {
//   final int requestId;
//   final String? classDate;
//   final String time;
//   final String requestType;
//   final String status;

//   ClassModel({
//     required this.requestId,
//     required this.classDate,
//     required this.time,
//     required this.requestType,
//     required this.status,
//   });

//   factory ClassModel.fromJson(Map<String, dynamic> json) {
//     return ClassModel(
//       requestId: json["requestId"] ?? 0,
//       classDate: json["classDate"]?.toString(),
//       time: json["time"] ?? "",
//       requestType: json["requestType"] ?? "",
//       status: json["status"] ?? "",
//     );
//   }
// }