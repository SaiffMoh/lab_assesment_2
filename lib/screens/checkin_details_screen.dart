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
        title: Center(
          child: Text(
            'Check-In Details',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Section
              Text(
                'Title',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 5),
              Text(
                data['title'] ?? 'No Title',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              Divider(color: Colors.grey[300], thickness: 1, height: 30),

              // Note Section
              Text(
                'Note',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 5),
              Text(
                data['note'] ?? 'No Note',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              Divider(color: Colors.grey[300], thickness: 1, height: 30),

              // Address Section
              Text(
                'Address',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 5),
              Text(
                data['address'] ?? 'No Address',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              Divider(color: Colors.grey[300], thickness: 1, height: 30),

              // Coordinates Section
              Text(
                'Coordinates',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.blue[700], size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Latitude: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    data['latitude']?.toStringAsFixed(4) ?? 'N/A',
                    style: TextStyle(
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.blue[700], size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Longitude: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    data['longitude']?.toStringAsFixed(4) ?? 'N/A',
                    style: TextStyle(
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),

              // Delete Button
              Center(
                child: TextButton.icon(
                  onPressed: () => _deleteCheckIn(context),
                  icon: Icon(Icons.delete, color: Colors.red),
                  label: Text(
                    'Delete Check-In',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: Size(200, 45),
                    backgroundColor: Colors.red[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
