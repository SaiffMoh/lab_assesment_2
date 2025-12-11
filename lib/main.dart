// main.dart - Check-In Logger App
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(CheckInLoggerApp());
}

class CheckInLoggerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Check-In Logger',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginScreen(),
    );
  }
}

// ==================== LOGIN / REGISTER SCREEN ====================
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLogin = true;
  String _errorMessage = '';
  bool _isLoading = false;

  Future<void> _handleAuth() async {
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Email and password are required';
        _isLoading = false;
      });
      return;
    }

    if (!email.contains('@')) {
      setState(() {
        _errorMessage = 'Please enter a valid email';
        _isLoading = false;
      });
      return;
    }

    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(email: email, password: password);
      } else {
        await _auth.createUserWithEmailAndPassword(email: email, password: password);
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => CheckInListScreen()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = 'No user found with this email';
        } else if (e.code == 'wrong-password') {
          _errorMessage = 'Wrong password';
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = 'Email already in use';
        } else if (e.code == 'weak-password') {
          _errorMessage = 'Password is too weak';
        } else {
          _errorMessage = e.message ?? 'Authentication error';
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Register')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            SizedBox(height: 10),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: TextStyle(color: Colors.red)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleAuth,
              child: Text(_isLoading ? 'Loading...' : (_isLogin ? 'Login' : 'Register')),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 45),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                  _errorMessage = '';
                });
              },
              child: Text(_isLogin ? 'Go to Register' : 'Go to Login'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== CHECK-IN LIST SCREEN ====================
class CheckInListScreen extends StatelessWidget {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    String uid = _auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: Text('My Check-Ins')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(uid)
            .collection('checkins')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No check-ins yet. Tap + to add one!'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text(data['title'] ?? 'No Title'),
                  subtitle: Text(
                    data['address'] ?? 'No Address',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CheckInDetailsScreen(
                          checkinId: doc.id,
                          data: data,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddCheckInScreen()),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

// ==================== ADD CHECK-IN SCREEN ====================
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
      appBar: AppBar(title: Text('Add Check-In')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Note / Description',
                border: OutlineInputBorder(),
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
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _useProvidedAddress,
                      icon: Icon(Icons.location_on),
                      label: Text('Use This Address'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 40),
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
                color: Colors.green.shade50,
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
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== CHECK-IN DETAILS SCREEN ====================
class CheckInDetailsScreen extends StatelessWidget {
  final String checkinId;
  final Map<String, dynamic> data;

  CheckInDetailsScreen({required this.checkinId, required this.data});

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

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
      appBar: AppBar(title: Text('Check-In Details')),
      body: Padding(
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
            ElevatedButton.icon(
              onPressed: () => _deleteCheckIn(context),
              icon: Icon(Icons.delete),
              label: Text('Delete Check-In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: Size(double.infinity, 45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}