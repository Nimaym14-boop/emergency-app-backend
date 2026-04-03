import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configuration provided by Person 3
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBmy69cqwvJi9q5I98AVln_qGglL9lCRNM",
      authDomain: "emergency-app-16163.firebaseapp.com",
      projectId: "emergency-app-16163",
      storageBucket: "emergency-app-16163.firebasestorage.app",
      messagingSenderId: "594138423990",
      appId: "1:594138423990:web:9f4cfb0d5187da80fffc17",
      measurementId: "G-RXF3EE7LCH",
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
        // FIXED: Using CardTheme correctly for modern Flutter versions
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
          elevation: 2,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

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
        title: const Text("🚨 CRISIS COORDINATION DASHBOARD"),
        actions: const [
          Center(child: Text("LIVE FEED ", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
          SizedBox(width: 20),
        ],
      ),
      body: Row(
        children: [
          // SIDEBAR: List of incidents
          SizedBox(
            width: 380,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Incidents')
                  .orderBy('timeSent', descending: true)
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
                      onTap: () => setState(() => _selectedIncidentId = id),
                      leading: Icon(Icons.warning, color: _getStatusColor(data['type'])),
                      title: Text("Room ${data['location']}"),
                      subtitle: Text("${data['type']} • ${data['status']}"),
                    );
                  },
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          // MAIN AREA: Incident details
          Expanded(
            child: _selectedIncidentId == null
                ? const Center(child: Text("Select an incident to begin coordination"))
                : IncidentDetails(incidentId: _selectedIncidentId!),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? type) {
    if (type == 'Fire') return Colors.red;
    if (type == 'Medical') return Colors.blue;
    return Colors.orange;
  }
}

class IncidentDetails extends StatelessWidget {
  final String incidentId;
  const IncidentDetails({super.key, required this.incidentId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Incidents').doc(incidentId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data() as Map<String, dynamic>;

        return Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['type']?.toUpperCase() ?? "EMERGENCY", 
                  style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.red)),
              Text("Location: Room ${data['location']}", style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              Text("Guest: ${data['guestName']}", style: const TextStyle(fontSize: 18)),
              Text("Coordinates: ${data['lat']}, ${data['lng']}"),
              const Spacer(),
              Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.all(20)),
                    onPressed: () => _updateStatus("Assigned"),
                    child: const Text("DISPATCH TEAM"),
                  ),
                  const SizedBox(width: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(20)),
                    onPressed: () => _updateStatus("Resolved"),
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

  void _updateStatus(String status) {
    FirebaseFirestore.instance.collection('Incidents').doc(incidentId).update({
      'status': status,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
}