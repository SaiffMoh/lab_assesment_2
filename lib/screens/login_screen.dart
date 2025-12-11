import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/checkin_list_screen.dart';

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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CheckInListScreen()),
        );
      } else {
        await _auth.createUserWithEmailAndPassword(email: email, password: password);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration successful! Please navigate to Login.'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isLogin = true;
          _isLoading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = 'No user found with this email';
        } else if (e.code == 'wrong-password') {
          _errorMessage = 'Wrong password';
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = 'Email already in use';
        } else {
          _errorMessage = e.message ?? 'Authentication error';
        }
      });
    } finally {
      if (_isLogin) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text(_isLogin ? 'Login' : 'Register')),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 40),
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue[100],
                child: Icon(
                  Icons.check_circle_outline,
                  size: 60,
                  color: Colors.blue[700],
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Check-In Logger',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
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
                child: Text(_isLogin ? 'Need an account? Register' : 'Already have an account? Login'),
                style: TextButton.styleFrom(foregroundColor: Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
