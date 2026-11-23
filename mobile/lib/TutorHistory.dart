import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:house_of_tutor/TutorHome.dart';
import 'package:house_of_tutor/services/api_client.dart';

class TutorHistory extends StatefulWidget {
  const TutorHistory({super.key});

  @override
  State<TutorHistory> createState() => _TutorHistoryState();
}

class _TutorHistoryState extends State<TutorHistory> {
  bool loading = true;
  List<dynamic> history = [];

  @override
  void initState() {
    super.initState();
    fetchHistory();
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

  // =====================================================
  // FETCH HISTORY
  // =====================================================

  Future<void> fetchHistory() async {
    try {
      if (mounted) setState(() => loading = true);

      final response =
          await ApiClient.get('/api/Tutor/tutor-class-history');

      debugPrint("HISTORY STATUS : ${response.statusCode}");
      debugPrint("HISTORY BODY : ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded["success"] == true) {
          history = decoded["data"] ?? [];
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiClient.messageFromBody(response.body) ??
                  "Failed : ${response.statusCode}",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("HISTORY ERROR : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // =====================================================
  // HISTORY CARD
  // =====================================================

  Widget historyCard(dynamic data) {
    final String studentName =
        data["student_name"]?.toString() ?? "Student";
    final String courseName =
        data["course_name"]?.toString() ?? "Course";
    final String classDate =
        data["class_date"]?.toString() ?? "";
    final String time = data["time"]?.toString() ?? "";
    final String type =
        data["request_type"]?.toString() ?? "Normal";

    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  studentName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  "Complete",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          Row(
            children: [
              const Icon(Icons.menu_book, size: 30),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  courseName,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              const Icon(Icons.calendar_month, size: 30),
              const SizedBox(width: 15),
              Text(classDate, style: const TextStyle(fontSize: 20)),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              const Icon(Icons.access_time, size: 30),
              const SizedBox(width: 15),
              Text(time, style: const TextStyle(fontSize: 20)),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              const Icon(Icons.compare_arrows, size: 30),
              const SizedBox(width: 15),
              Text(type, style: const TextStyle(fontSize: 20)),
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
      backgroundColor: const Color(0xfff5eff7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ================================
              // TOP BAR — sirf back arrow
              // ================================
              Row(
                children: [
                  // ✅ SIRF BACK BUTTON
                  IconButton(
                    onPressed: _goBack,
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 32,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              const Text(
                "Class History",
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // ================================
              // BODY
              // ================================
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : history.isEmpty
                        ? const Center(
                            child: Text(
                              "No History Found",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: fetchHistory,
                            child: ListView.builder(
                              itemCount: history.length,
                              itemBuilder: (context, index) {
                                return historyCard(history[index]);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}






























































// import 'dart:convert';
// import 'package:flutter/material.dart';
// //import 'package:house_of_tutor/TutorDrawer.dart';
// import 'package:house_of_tutor/services/api_client.dart';

// class TutorHistory extends StatefulWidget {
//   const TutorHistory({super.key});

//   @override
//   State<TutorHistory> createState() => _TutorHistoryState();
// }

// class _TutorHistoryState extends State<TutorHistory> {
//   final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

//   // STATES
//   bool loading = true;
//   List<dynamic> history = [];

//   // INIT
//   @override
//   void initState() {
//     super.initState();
//     fetchHistory();
//   }

//   // FETCH HISTORY
//   Future<void> fetchHistory() async {
//     try {
//       if (mounted) {
//         setState(() {
//           loading = true;
//         });
//       }

//       final response = await ApiClient.get('/api/Tutor/tutor-class-history');

//       debugPrint("HISTORY STATUS : ${response.statusCode}");
//       debugPrint("HISTORY BODY : ${response.body}");

//       // CRITICAL FIX: Ensure widget is still mounted after network request finishes
//       if (!mounted) return;

//       if (response.statusCode == 200) {
//         final body = utf8.decode(response.bodyBytes);
//         final decoded = jsonDecode(body);

//         if (decoded["success"] == true) {
//           history = decoded["data"] ?? [];
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text("Failed : ${response.statusCode}"),
//           ),
//         );
//       }
//     } catch (e) {
//       debugPrint("HISTORY ERROR : $e");
      
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

//   // HISTORY CARD
//   Widget historyCard(dynamic data) {
//     final studentName = data["student_name"]?.toString() ?? "Student";
//     final courseName = data["course_name"]?.toString() ?? "Course";
//     final classDate = data["class_date"]?.toString() ?? "";
//     final time = data["time"]?.toString() ?? "";
//     final type = data["request_type"]?.toString() ?? "Normal";

//     return Container(
//       margin: const EdgeInsets.only(bottom: 25),
//       padding: const EdgeInsets.all(25),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(30),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 10,
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // =================================================
//           // TOP ROW
//           // =================================================
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Expanded(
//                 child: Text(
//                   studentName,
//                   style: const TextStyle(
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//                 decoration: BoxDecoration(
//                   color: Colors.green,
//                   borderRadius: BorderRadius.circular(30),
//                 ),
//                 child: const Text(
//                   "Complete",
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 18,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 25),

//           // =================================================
//           // SUBJECT
//           // =================================================
//           Row(
//             children: [
//               const Icon(Icons.menu_book, size: 30),
//               const SizedBox(width: 15),
//               Expanded(
//                 child: Text(
//                   courseName,
//                   style: const TextStyle(fontSize: 20),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),

//           // =================================================
//           // DATE
//           // =================================================
//           Row(
//             children: [
//               const Icon(Icons.calendar_month, size: 30),
//               const SizedBox(width: 15),
//               Text(
//                 classDate,
//                 style: const TextStyle(fontSize: 20),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),

//           // =================================================
//           // TIME
//           // =================================================
//           Row(
//             children: [
//               const Icon(Icons.access_time, size: 30),
//               const SizedBox(width: 15),
//               Text(
//                 time,
//                 style: const TextStyle(fontSize: 20),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),

//           // =================================================
//           // TYPE
//           // =================================================
//           Row(
//             children: [
//               const Icon(Icons.compare_arrows, size: 30),
//               const SizedBox(width: 15),
//               Text(
//                 type,
//                 style: const TextStyle(fontSize: 20),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // UI
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       key: scaffoldKey,
//       backgroundColor: const Color(0xfff5eff7),
//       //drawer: const TutorDrawer(),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
           
//               // TOP BAR
             
//               Row(
//                 children: [
//                   IconButton(
//                     onPressed: () {
//                       scaffoldKey.currentState?.openDrawer();
//                     },
//                     icon: const Icon(Icons.menu, size: 32),
//                   ),
//                   IconButton(
//                     onPressed: () {
//                       if (Navigator.canPop(context)) {
//                         Navigator.pop(context);
//                       }
//                     },
//                     icon: const Icon(Icons.arrow_back, size: 32),
//                   ),
//                   const Spacer(),
//                 ],
//               ),
//               const SizedBox(height: 10),

//               // =================================================
//               // TITLE
//               // =================================================
//               const Text(
//                 "Class History",
//                 style: TextStyle(
//                   fontSize: 40,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 20),

//               // =================================================
//               // BODY
//               // =================================================
//               Expanded(
//                 child: loading
//                     ? const Center(
//                         child: CircularProgressIndicator(),
//                       )
//                     : history.isEmpty
//                         ? const Center(
//                             child: Text(
//                               "No History Found",
//                               style: TextStyle(
//                                 fontSize: 20,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           )
//                         : RefreshIndicator(
//                             onRefresh: fetchHistory,
//                             child: ListView.builder(
//                               itemCount: history.length,
//                               itemBuilder: (context, index) {
//                                 return historyCard(history[index]);
//                               },
//                             ),
//                           ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }




































// import 'dart:convert';

// import 'package:flutter/material.dart';

// import 'package:house_of_tutor/TutorDrawer.dart';
// import 'package:house_of_tutor/services/api_client.dart';

// class TutorHistory extends StatefulWidget {

//   const TutorHistory({
//     super.key,
//   });

//   @override
//   State<TutorHistory> createState() =>
//       _TutorHistoryState();
// }

// class _TutorHistoryState
//     extends State<TutorHistory> {

//   final GlobalKey<ScaffoldState>
//       scaffoldKey =
//       GlobalKey<ScaffoldState>();

//   // =====================================================
//   // STATES
//   // =====================================================

//   bool loading = true;

//   List<dynamic> history = [];

//   // =====================================================
//   // INIT
//   // =====================================================

//   @override
//   void initState() {
//     super.initState();

//     fetchHistory();
//   }

//   // =====================================================
//   // FETCH HISTORY
//   // =====================================================

//   Future<void> fetchHistory() async {

//     try {

//       setState(() {
//         loading = true;
//       });

//       final response =
//           await ApiClient.get(
//         '/api/Tutor/tutor-class-history',
//       );

//       debugPrint(
//         "HISTORY STATUS : ${response.statusCode}",
//       );

//       debugPrint(
//         "HISTORY BODY : ${response.body}",
//       );

//       if (response.statusCode == 200) {

//         final body = utf8.decode(
//           response.bodyBytes,
//         );

//         final decoded =
//             jsonDecode(body);

//         if (decoded["success"] ==
//             true) {

//           history =
//               decoded["data"] ?? [];
//         }

//       } else {

//         ScaffoldMessenger.of(context)
//             .showSnackBar(
//           SnackBar(
//             content: Text(
//               "Failed : ${response.statusCode}",
//             ),
//           ),
//         );
//       }

//     } catch (e) {

//       debugPrint(
//         "HISTORY ERROR : $e",
//       );

//       ScaffoldMessenger.of(context)
//           .showSnackBar(
//         SnackBar(
//           content: Text(
//             "Error : $e",
//           ),
//         ),
//       );
//     }

//     if (mounted) {

//       setState(() {
//         loading = false;
//       });
//     }
//   }

//   // =====================================================
//   // HISTORY CARD
//   // =====================================================

//   Widget historyCard(
//     dynamic data,
//   ) {

//     final studentName =
//         data["student_name"]
//                 ?.toString() ??
//             "Student";

//     final courseName =
//         data["course_name"]
//                 ?.toString() ??
//             "Course";

//     final classDate =
//         data["class_date"]
//                 ?.toString() ??
//             "";

//     final time =
//         data["time"]
//                 ?.toString() ??
//             "";

//     final type =
//         data["request_type"]
//                 ?.toString() ??
//             "Normal";

//     return Container(

//       margin:
//           const EdgeInsets.only(
//         bottom: 25,
//       ),

//       padding:
//           const EdgeInsets.all(25),

//       decoration: BoxDecoration(

//         color: Colors.white,

//         borderRadius:
//             BorderRadius.circular(30),

//         boxShadow: [

//           BoxShadow(
//             color: Colors.black
//                 .withOpacity(0.1),

//             blurRadius: 10,
//           ),
//         ],
//       ),

//       child: Column(

//         crossAxisAlignment:
//             CrossAxisAlignment.start,

//         children: [

//           // =================================================
//           // TOP ROW
//           // =================================================

//           Row(

//             mainAxisAlignment:
//                 MainAxisAlignment
//                     .spaceBetween,

//             children: [

//               Expanded(

//                 child: Text(

//                   studentName,

//                   style:
//                       const TextStyle(

//                     fontSize: 24,

//                     fontWeight:
//                         FontWeight.bold,
//                   ),
//                 ),
//               ),

//               Container(

//                 padding:
//                     const EdgeInsets
//                         .symmetric(

//                   horizontal: 20,

//                   vertical: 10,
//                 ),

//                 decoration:
//                     BoxDecoration(

//                   color: Colors.green,

//                   borderRadius:
//                       BorderRadius.circular(
//                           30),
//                 ),

//                 child: const Text(

//                   "Complete",

//                   style: TextStyle(

//                     color:
//                         Colors.white,

//                     fontWeight:
//                         FontWeight.bold,

//                     fontSize: 18,
//                   ),
//                 ),
//               ),
//             ],
//           ),

//           const SizedBox(height: 25),

//           // =================================================
//           // SUBJECT
//           // =================================================

//           Row(
//             children: [

//               const Icon(
//                 Icons.menu_book,
//                 size: 30,
//               ),

//               const SizedBox(width: 15),

//               Expanded(
//                 child: Text(

//                   courseName,

//                   style:
//                       const TextStyle(
//                     fontSize: 20,
//                   ),
//                 ),
//               ),
//             ],
//           ),

//           const SizedBox(height: 20),

//           // =================================================
//           // DATE
//           // =================================================

//           Row(
//             children: [

//               const Icon(
//                 Icons.calendar_month,
//                 size: 30,
//               ),

//               const SizedBox(width: 15),

//               Text(

//                 classDate,

//                 style:
//                     const TextStyle(
//                   fontSize: 20,
//                 ),
//               ),
//             ],
//           ),

//           const SizedBox(height: 20),

//           // =================================================
//           // TIME
//           // =================================================

//           Row(
//             children: [

//               const Icon(
//                 Icons.access_time,
//                 size: 30,
//               ),

//               const SizedBox(width: 15),

//               Text(

//                 time,

//                 style:
//                     const TextStyle(
//                   fontSize: 20,
//                 ),
//               ),
//             ],
//           ),

//           const SizedBox(height: 20),

//           // =================================================
//           // TYPE
//           // =================================================

//           Row(
//             children: [

//               const Icon(
//                 Icons.compare_arrows,
//                 size: 30,
//               ),

//               const SizedBox(width: 15),

//               Text(

//                 type,

//                 style:
//                     const TextStyle(
//                   fontSize: 20,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // =====================================================
//   // UI
//   // =====================================================

//   @override
//   Widget build(BuildContext context) {

//     return Scaffold(

//       key: scaffoldKey,

//       backgroundColor:
//           const Color(0xfff5eff7),

//       drawer: const TutorDrawer(),

//       body: SafeArea(

//         child: Padding(

//           padding:
//               const EdgeInsets.all(
//             20,
//           ),

//           child: Column(

//             crossAxisAlignment:
//                 CrossAxisAlignment
//                     .start,

//             children: [

//               // =================================================
//               // TOP BAR
//               // =================================================

//               Row(

//                 children: [

//                   // MENU

//                   IconButton(

//                     onPressed: () {

//                       scaffoldKey
//                           .currentState
//                           ?.openDrawer();
//                     },

//                     icon: const Icon(
//                       Icons.menu,
//                       size: 32,
//                     ),
//                   ),

//                   // BACK

//                   IconButton(

//                     onPressed: () {

//                       if (Navigator.canPop(
//                           context)) {

//                         Navigator.pop(
//                             context);
//                       }
//                     },

//                     icon: const Icon(
//                       Icons.arrow_back,
//                       size: 32,
//                     ),
//                   ),

//                   const Spacer(),
//                 ],
//               ),

//               const SizedBox(
//                   height: 10),

//               // =================================================
//               // TITLE
//               // =================================================

//               const Text(

//                 "Class History",

//                 style: TextStyle(

//                   fontSize: 40,

//                   fontWeight:
//                       FontWeight.bold,
//                 ),
//               ),

//               const SizedBox(
//                   height: 20),

//               // =================================================
//               // BODY
//               // =================================================

//               Expanded(

//                 child: loading

//                     ? const Center(
//                         child:
//                             CircularProgressIndicator(),
//                       )

//                     : history.isEmpty

//                         ? const Center(
//                             child: Text(

//                               "No History Found",

//                               style: TextStyle(

//                                 fontSize: 20,

//                                 fontWeight:
//                                     FontWeight.bold,
//                               ),
//                             ),
//                           )

//                         : RefreshIndicator(

//                             onRefresh:
//                                 fetchHistory,

//                             child:
//                                 ListView.builder(

//                               itemCount:
//                                   history.length,

//                               itemBuilder:
//                                   (context,
//                                       index) {

//                                 return historyCard(
//                                   history[index],
//                                 );
//                               },
//                             ),
//                           ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }