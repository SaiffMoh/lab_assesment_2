import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/login_screen.dart';

class CheckInDetailsScreen extends StatelessWidget {
  final String checkinId;
  final Map<String, dynamic> data;

  CheckInDetailsScreen({required this.checkinId, required this.data});

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> _logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteCheckIn(BuildContext context) async {
    try {
      String uid = _auth.currentUser!.uid;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('checkins')
          .doc(checkinId)
          .delete();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting check-in: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('Check-In Details')),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title', style: TextStyle(fontSize: 14, color: Colors.grey)),
            Text(data['title'] ?? 'No Title', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Text('Note', style: TextStyle(fontSize: 14, color: Colors.grey)),
            Text(data['note'] ?? 'No Note', style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),
            Text('Address', style: TextStyle(fontSize: 14, color: Colors.grey)),
            Text(data['address'] ?? 'No Address', style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),
            Text('Coordinates', style: TextStyle(fontSize: 14, color: Colors.grey)),
            Text(
              'Latitude: ${data['latitude']?.toStringAsFixed(4) ?? 'N/A'}',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              'Longitude: ${data['longitude']?.toStringAsFixed(4) ?? 'N/A'}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 30),
            TextButton.icon(
              onPressed: () => _deleteCheckIn(context),
              icon: Icon(Icons.delete, color: Colors.red),
              label: Text('Delete Check-In', style: TextStyle(color: Colors.red)),
              style: TextButton.styleFrom(
                minimumSize: Size(double.infinity, 45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
