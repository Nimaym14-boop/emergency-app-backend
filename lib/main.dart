import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import your secret config file
import 'package:flutter_app/config.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Use the constants from your ignored config.dart
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: FirebaseConfig.apiKey,
      authDomain: FirebaseConfig.authDomain,
      projectId: FirebaseConfig.projectId,
      storageBucket: FirebaseConfig.storageBucket,
      messagingSenderId: FirebaseConfig.messagingSenderId,
      appId: FirebaseConfig.appId,
      measurementId: FirebaseConfig.measurementId,
    ),
  );
  runApp(const RapidCrisisApp());
}

class RapidCrisisApp extends StatelessWidget {
  const RapidCrisisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rapid Crisis Response',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
          elevation: 2,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// --- 1. AUTH GATE: THE ROUTER ---
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If not logged in, show Login Screen
        if (!snapshot.hasData) return const LoginScreen();

        // If logged in, check role in Firestore
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('Users').doc(snapshot.data!.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            
            final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
            final role = userData?['role'] ?? 'staff';

            if (role == 'admin') {
              return const DashboardScreen();
            } else {
              return StaffResponderView(uid: snapshot.data!.uid);
            }
          },
        );
      },
    );
  }
}

// --- 2. LOGIN SCREEN ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _login() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Person 3's Logic: Set staff to available upon successful login
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userCredential.user!.uid).get();
      if (userDoc.exists && userDoc['role'] == 'staff') {
        await FirebaseFirestore.instance.collection('Staff').doc(userCredential.user!.uid).set({
          'isAvailable': true,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("CRISIS LOGIN", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 30),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
              TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.red[900]),
                onPressed: _login,
                child: const Text("ACCESS TERMINAL"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- 3. DISPATCHER DASHBOARD (ADMIN VIEW) ---
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _selectedIncidentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        title: const Text("🚨 COORDINATION DASHBOARD"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: Row(
        children: [
          // Sidebar: Incident List
          SizedBox(
            width: 380,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Incidents')
                  .where('status', isNotEqualTo: 'Resolved')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final id = docs[index].id;
                    return ListTile(
                      selected: _selectedIncidentId == id,
                      selectedTileColor: Colors.white10,
                      onTap: () => setState(() => _selectedIncidentId = id),
                      leading: Icon(Icons.warning, color: data['type'] == 'Fire' ? Colors.red : Colors.blue),
                      title: Text("Room ${data['location']}"),
                      subtitle: Text("${data['type']} • ${data['status']}"),
                    );
                  },
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          // Main Panel: Incident Details & Dispatch
          Expanded(
            child: _selectedIncidentId == null
                ? const Center(child: Text("Select an active incident from the sidebar"))
                : IncidentDetails(
                    key: ValueKey(_selectedIncidentId), 
                    incidentId: _selectedIncidentId!,
                    onResolved: () => setState(() => _selectedIncidentId = null),
                  ),
          ),
        ],
      ),
    );
  }
}

// --- 4. INCIDENT DETAILS & DISPATCH LOGIC ---
class IncidentDetails extends StatefulWidget {
  final String incidentId;
  final VoidCallback onResolved;
  const IncidentDetails({super.key, required this.incidentId, required this.onResolved});

  @override
  State<IncidentDetails> createState() => _IncidentDetailsState();
}

class _IncidentDetailsState extends State<IncidentDetails> {
  String? _selectedStaffId;
  String? _selectedStaffName;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Incidents').doc(widget.incidentId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text("Loading..."));
        final data = snapshot.data!.data() as Map<String, dynamic>;

        return Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['type']?.toUpperCase() ?? "EMERGENCY", 
                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.red)),
              Text("Location: Room ${data['location']}", style: const TextStyle(fontSize: 24)),
              const Divider(height: 60),
              const Text("AVAILABLE STAFF", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const SizedBox(height: 20),
              // Horizontal list of online staff
              SizedBox(
                height: 120,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('Staff').where('isAvailable', isEqualTo: true).snapshots(),
                  builder: (context, staffSnapshot) {
                    if (!staffSnapshot.hasData) return const LinearProgressIndicator();
                    final staffDocs = staffSnapshot.data!.docs;
                    if (staffDocs.isEmpty) return const Text("No staff currently online.");

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: staffDocs.length,
                      itemBuilder: (context, index) {
                        final staff = staffDocs[index].data() as Map<String, dynamic>;
                        final sId = staffDocs[index].id;
                        final isSelected = _selectedStaffId == sId;
                        return GestureDetector(
                          onTap: () => setState(() { _selectedStaffId = sId; _selectedStaffName = staff['name']; }),
                          child: Container(
                            width: 150, margin: const EdgeInsets.only(right: 15),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.withValues(alpha : 0.2) : Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? Colors.blue : Colors.transparent, width: 2),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person, color: isSelected ? Colors.blue : Colors.white),
                                Text(staff['name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Spacer(),
              if (data['assignedStaff'] != null)
                Text("Assigned to: ${data['assignedStaff']}", style: const TextStyle(color: Colors.green, fontSize: 18)),
              const SizedBox(height: 20),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _selectedStaffId == null ? null : _dispatchStaff,
                    child: const Text("DISPATCH"),
                  ),
                  const SizedBox(width: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                    onPressed: () => _updateStatus("Resolved", data['assignedStaffId']),
                    child: const Text("MARK RESOLVED"),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  void _dispatchStaff() async {
    await FirebaseFirestore.instance.collection('Incidents').doc(widget.incidentId).update({
      'status': 'Assigned',
      'assignedStaff': _selectedStaffName,
      'assignedStaffId': _selectedStaffId,
    });
    // Set staff member to busy
    await FirebaseFirestore.instance.collection('Staff').doc(_selectedStaffId).update({'isAvailable': false});
  }

  void _updateStatus(String status, String? staffId) async {
    Map<String, dynamic> updateData = {'status': status};
    if (status == "Resolved") {
      updateData['assignedStaff'] = FieldValue.delete();
      updateData['assignedStaffId'] = FieldValue.delete();
      // Free up the staff member again
      if (staffId != null) {
        await FirebaseFirestore.instance.collection('Staff').doc(staffId).update({'isAvailable': true});
      }
      widget.onResolved();
    }
    await FirebaseFirestore.instance.collection('Incidents').doc(widget.incidentId).update(updateData);
  }
}

// --- 5. STAFF RESPONDER VIEW ---
class StaffResponderView extends StatelessWidget {
  final String uid;
  const StaffResponderView({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RESPONDER TERMINAL"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            // Person 3's Logic: Set unavailable when logging out
            await FirebaseFirestore.instance.collection('Staff').doc(uid).update({'isAvailable': false});
            await FirebaseAuth.instance.signOut();
          }),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.radar, size: 80, color: Colors.greenAccent),
            const SizedBox(height: 20),
            const Text("Online & Waiting for Alerts...", style: TextStyle(fontSize: 20)),
            const SizedBox(height: 10),
            Text("User ID: $uid", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}