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
  WidgetsFlutterBinding.ensureInitialized();
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
      theme: ThemeData(primarySwatch: Colors.blue),
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
  String firebaseStatus = 'Not tested yet';
  String locationStatus = 'Not requested yet';
  String currentLocation = '';
  String currentAddress = '';
  bool isLoadingLocation = false;
  String accelerometerData = 'No data yet';
  
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    listenToAccelerometer();
  }

  Future<void> testFirebase() async {
    try {
      setState(() => firebaseStatus = '⏳ Testing Firebase...');
      await firestore.collection('test').add({
        'message': 'Hello from Flutter!',
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() => firebaseStatus = '✅ Firebase connected!');
    } catch (e) {
      setState(() => firebaseStatus = '❌ Error: $e');
    }
  }

  Future<void> requestLocationPermission() async {
    setState(() => locationStatus = '⏳ Requesting permission...');
    PermissionStatus status = await Permission.location.request();
    
    if (status.isGranted) {
      setState(() => locationStatus = '✅ Permission granted!');
    } else if (status.isDenied) {
      setState(() => locationStatus = '❌ Permission denied.');
    } else if (status.isPermanentlyDenied) {
      setState(() => locationStatus = '❌ Permanently denied.');
      openAppSettings();
    }
  }

  Future<void> useMockLocation() async {
    setState(() {
      isLoadingLocation = true;
      locationStatus = '⏳ Using mock location (Cairo)...';
      currentLocation = '';
      currentAddress = '';
    });

    await Future.delayed(Duration(seconds: 1));

    double latitude = 30.0444;
    double longitude = 31.2357;

    setState(() {
      currentLocation = 'Lat: ${latitude.toStringAsFixed(4)}, Lon: ${longitude.toStringAsFixed(4)}';
      locationStatus = '⏳ Getting address...';
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude, longitude,
      ).timeout(Duration(seconds: 10));
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          currentAddress = '${place.street ?? 'Unknown'}, ${place.locality ?? 'Cairo'}, ${place.country ?? 'Egypt'}';
        });
      }
    } catch (e) {
      setState(() => currentAddress = 'Cairo, Egypt (mock)');
    }
    
    await firestore.collection('locations').add({
      'latitude': latitude,
      'longitude': longitude,
      'address': currentAddress,
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    setState(() {
      locationStatus = '✅ Mock location saved to Firebase!';
      isLoadingLocation = false;
    });
  }

  Future<void> getCurrentLocation() async {
    if (isLoadingLocation) return;

    setState(() {
      isLoadingLocation = true;
      locationStatus = '⏳ Getting real location (30s timeout)...';
      currentLocation = '';
      currentAddress = '';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          locationStatus = '❌ Location services disabled.';
          isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          locationStatus = '❌ Permission not granted.';
          isLoadingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 30),
      );
      
      setState(() {
        currentLocation = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}';
        locationStatus = '⏳ Got coordinates! Getting address...';
      });

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude,
        ).timeout(Duration(seconds: 10));
        
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            currentAddress = '${place.street ?? 'Unknown'}, ${place.locality ?? 'Unknown'}, ${place.country ?? 'Unknown'}';
          });
        }
      } catch (e) {
        setState(() => currentAddress = 'Could not get address');
      }
      
      await firestore.collection('locations').add({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': currentAddress,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        locationStatus = '✅ Real location saved!';
        isLoadingLocation = false;
      });
      
    } on TimeoutException {
      setState(() {
        locationStatus = '❌ Timeout! Try mock location.';
        isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        locationStatus = '❌ Error: ${e.toString()}';
        isLoadingLocation = false;
      });
    }
  }

  void listenToAccelerometer() {
    accelerometerEvents.listen((AccelerometerEvent event) {
      if (mounted) {
        setState(() {
          accelerometerData = 'X: ${event.x.toStringAsFixed(2)}, Y: ${event.y.toStringAsFixed(2)}, Z: ${event.z.toStringAsFixed(2)}';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Assessment Practice')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🔥 Firebase Test', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text(firebaseStatus),
                    SizedBox(height: 10),
                    ElevatedButton(onPressed: testFirebase, child: Text('Test Firebase')),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📍 Location Test', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text('Status: $locationStatus'),
                    if (currentLocation.isNotEmpty) Text('Location: $currentLocation'),
                    if (currentAddress.isNotEmpty) Text('Address: $currentAddress'),
                    SizedBox(height: 10),
                    ElevatedButton(onPressed: requestLocationPermission, child: Text('1. Request Permission')),
                    SizedBox(height: 5),
                    ElevatedButton(
                      onPressed: isLoadingLocation ? null : useMockLocation,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: Text(isLoadingLocation ? 'Loading...' : '2A. Mock Location (FAST)'),
                    ),
                    SizedBox(height: 5),
                    ElevatedButton(
                      onPressed: isLoadingLocation ? null : getCurrentLocation,
                      child: Text(isLoadingLocation ? 'Loading...' : '2B. Real Location (SLOW)'),
                    ),
                    if (isLoadingLocation) Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📱 Accelerometer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text(accelerometerData),
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