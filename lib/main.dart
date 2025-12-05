import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'firebase_options.dart';
import 'dart:async';


void main() async {
  // Initialize Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Assessment Practice',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  // Firebase test variables
  String firebaseStatus = 'Not tested yet';
  
  // Location variables
  String locationStatus = 'Not requested yet';
  String currentLocation = '';
  String currentAddress = '';
  bool isLoadingLocation = false;
  
  // Sensor variables
  String accelerometerData = 'No data yet';
  
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Start listening to accelerometer
    listenToAccelerometer();
  }

  // TEST 1: Firebase Connection
  Future<void> testFirebase() async {
    try {
      setState(() {
        firebaseStatus = '⏳ Testing Firebase...';
      });

      // Try to write to Firestore
      await firestore.collection('test').add({
        'message': 'Hello from Flutter!',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        firebaseStatus = '✅ Firebase connected! Data written successfully.';
      });
    } catch (e) {
      setState(() {
        firebaseStatus = '❌ Firebase error: $e';
      });
    }
  }

  // TEST 2: Request Location Permission
  Future<void> requestLocationPermission() async {
    setState(() {
      locationStatus = '⏳ Requesting permission...';
    });

    PermissionStatus status = await Permission.location.request();
    
    if (status.isGranted) {
      setState(() {
        locationStatus = '✅ Permission granted! Now get location.';
      });
    } else if (status.isDenied) {
      setState(() {
        locationStatus = '❌ Permission denied. Try again.';
      });
    } else if (status.isPermanentlyDenied) {
      setState(() {
        locationStatus = '❌ Permanently denied. Open settings.';
      });
      openAppSettings();
    }
  }

  // TEST 3: Get Current Location (WITH TIMEOUT)
  Future<void> getCurrentLocation() async {
    if (isLoadingLocation) {
      return; // Prevent multiple simultaneous requests
    }

    setState(() {
      isLoadingLocation = true;
      locationStatus = '⏳ Getting location... (this may take 30 seconds)';
      currentLocation = '';
      currentAddress = '';
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          locationStatus = '❌ Location services disabled. Enable in emulator settings.';
          isLoadingLocation = false;
        });
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          locationStatus = '❌ Permission not granted. Click "Request Permission" first.';
          isLoadingLocation = false;
        });
        return;
      }

      // Get position with TIMEOUT
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // Changed to low for faster response
        timeLimit: Duration(seconds: 100), // 30 second timeout
      );
      
      setState(() {
        currentLocation = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}';
        locationStatus = '⏳ Got coordinates! Getting address...';
      });

      // Get address from coordinates (reverse geocoding) with timeout
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(Duration(seconds: 10));
        
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            currentAddress = '${place.street ?? 'Unknown Street'}, ${place.locality ?? 'Unknown City'}, ${place.country ?? 'Unknown Country'}';
          });
        }
      } catch (e) {
        setState(() {
          currentAddress = 'Could not get address (timeout or error)';
        });
      }
      
      // Save to Firebase
      await firestore.collection('locations').add({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': currentAddress,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        locationStatus = '✅ Location saved to Firebase!';
        isLoadingLocation = false;
      });
      
    } on TimeoutException {
      setState(() {
        locationStatus = '❌ Timeout! Location took too long. Try again or restart emulator.';
        isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        locationStatus = '❌ Error: ${e.toString()}';
        isLoadingLocation = false;
      });
    }
  }

  // TEST 4: Listen to Accelerometer
  void listenToAccelerometer() {
    accelerometerEvents.listen((AccelerometerEvent event) {
      if (mounted) {
        setState(() {
          accelerometerData = 'X: ${event.x.toStringAsFixed(2)}, '
                             'Y: ${event.y.toStringAsFixed(2)}, '
                             'Z: ${event.z.toStringAsFixed(2)}';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Assessment Practice Tests'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Firebase Test Section
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔥 Firebase Test',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(firebaseStatus),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: testFirebase,
                      child: Text('Test Firebase Connection'),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Location Test Section
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📍 Location Test',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text('Status: $locationStatus'),
                    SizedBox(height: 5),
                    if (currentLocation.isNotEmpty) Text('Location: $currentLocation'),
                    if (currentAddress.isNotEmpty) Text('Address: $currentAddress'),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: requestLocationPermission,
                      child: Text('1. Request Permission'),
                    ),
                    SizedBox(height: 5),
                    ElevatedButton(
                      onPressed: isLoadingLocation ? null : getCurrentLocation,
                      child: Text(isLoadingLocation ? 'Loading...' : '2. Get Location'),
                    ),
                    if (isLoadingLocation)
                      Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Sensor Test Section
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📱 Accelerometer (Live)',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(accelerometerData),
                    SizedBox(height: 10),
                    Text(
                      'Move your device to see changes!',
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Tips Section
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Tips',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• Set location in emulator: Click "..." → Location → Search "Cairo"'),
                    Text('• If location times out, close and restart the emulator'),
                    Text('• Check Firebase Console to see saved data'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}