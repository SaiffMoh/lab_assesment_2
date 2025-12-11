import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../screens/login_screen.dart';

class AddCheckInScreen extends StatefulWidget {
  @override
  _AddCheckInScreenState createState() => _AddCheckInScreenState();
}

class _AddCheckInScreenState extends State<AddCheckInScreen> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _addressController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  double? _latitude;
  double? _longitude;
  String? _address;
  bool _isLoading = false;
  String _locationMessage = '';

  Future<void> _logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _locationMessage = 'Requesting permission...';
    });
    PermissionStatus status = await Permission.location.request();
    if (!status.isGranted) {
      setState(() {
        _isLoading = false;
        _locationMessage = 'Location permission is required to use current location.';
      });
      return;
    }
    try {
      setState(() => _locationMessage = 'Getting location...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 60),
      );
      print('Current location: ${position.latitude}, ${position.longitude}');
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationMessage = 'Getting address...';
      });
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _address = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}';
          _locationMessage = 'Location set!';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _locationMessage = 'Error getting location: $e';
      });
    }
  }

  Future<void> _useProvidedAddress() async {
    String addressText = _addressController.text.trim();
    if (addressText.isEmpty) {
      setState(() => _locationMessage = 'Please enter an address');
      return;
    }
    setState(() {
      _isLoading = true;
      _locationMessage = 'Geocoding address...';
    });
    try {
      List<Location> locations = await locationFromAddress(addressText);
      if (locations.isNotEmpty) {
        Location location = locations[0];
        print('Geocoded coordinates: ${location.latitude}, ${location.longitude}');
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );
        setState(() {
          _latitude = location.latitude;
          _longitude = location.longitude;
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            _address = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}';
          } else {
            _address = addressText;
          }
          _locationMessage = 'Address set!';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _locationMessage = 'Error: Invalid address or geocoding failed';
      });
    }
  }

  Future<void> _saveCheckIn() async {
    String title = _titleController.text.trim();
    String note = _noteController.text.trim();
    if (title.isEmpty || note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Title and note are required')),
      );
      return;
    }
    if (_latitude == null || _longitude == null || _address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please set a location')),
      );
      return;
    }
    try {
      String uid = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(uid).collection('checkins').add({
        'title': title,
        'note': note,
        'latitude': _latitude,
        'longitude': _longitude,
        'address': _address,
        'createdAt': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving check-in: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('Add Check-In')),
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
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              SizedBox(height: 15),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Note / Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 20),
              Text('Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _useCurrentLocation,
                        icon: Icon(Icons.my_location),
                        label: Text('Use My Current Location'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 40),
                        ),
                      ),
                      SizedBox(height: 15),
                      Text('OR', textAlign: TextAlign.center),
                      SizedBox(height: 15),
                      TextField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: 'Enter location (address)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),
                      SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _isLoading ? null : _useProvidedAddress,
                        icon: Icon(Icons.location_on),
                        label: Text('Use This Address'),
                        style: TextButton.styleFrom(
                          minimumSize: Size(double.infinity, 40),
                          foregroundColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              if (_locationMessage.isNotEmpty)
                Text(_locationMessage, style: TextStyle(color: Colors.blue)),
              if (_latitude != null && _longitude != null)
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Location Set:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Address: $_address'),
                        Text('Lat: ${_latitude!.toStringAsFixed(4)}, Lon: ${_longitude!.toStringAsFixed(4)}'),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveCheckIn,
                child: Text('Save Check-In'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
