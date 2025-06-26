import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:irrigo/auth.dart';
import 'package:irrigo/pages/login_registre_page.dart';
import 'package:intl/intl.dart';
import 'package:irrigo/pages/HomePageView.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  User? user = Auth().currentUser;

  bool isLoading = true;
  Map<String, dynamic>? firebaseData;
  String? latestKey;
  bool? irrigationNeeded;
  double? recommendedQuantity;



  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final ImagePicker picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _listenToFirebaseData(user.uid);
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void _listenToFirebaseData(String uid) {
    final dbRef = FirebaseDatabase.instance.ref('Data/$uid/');

    dbRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final dataMap = Map<String, dynamic>.from(event.snapshot.value as Map);

        final sortedKeys =
            dataMap.keys.toList()..sort(
              (a, b) => parseKeyToDateTime(b).compareTo(parseKeyToDateTime(a)),
            );

        final latestKeyLocal = sortedKeys.first;
        final latestData = Map<String, dynamic>.from(dataMap[latestKeyLocal]);

        setState(() {
          firebaseData = latestData;
          latestKey = latestKeyLocal;
          isLoading = false;
        });
        _animationController.forward();
      } else {
        setState(() {
          firebaseData = null;
          latestKey = null;
          isLoading = false;
        });
      }
    });
  }

  Future<void> _signOut(BuildContext context) async {
    await Auth().signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }


  Future<void> _onRefresh() async {
    setState(() {});
  }

  DateTime parseKeyToDateTime(String key) {
    try {
      String isoLikeKey = key.replaceAll('_', ':');
      int lastColon = isoLikeKey.lastIndexOf(':');
      if (lastColon != -1) {
        isoLikeKey = isoLikeKey.replaceRange(lastColon, lastColon + 1, '.');
      }
      return DateTime.parse(isoLikeKey).toLocal();
    } catch (_) {
      return DateTime(1900);
    }
  }

  String formatParsedDate(DateTime date) {
    return DateFormat('EEEE, dd MMM yyyy', 'en_US').format(date);
  }

  String formatTime(DateTime date) {
    return DateFormat('HH:mm', 'en_US').format(date);
  }

  Future<void> getPrediction(Map<String, dynamic> inputData) async {
    final url = Uri.parse(
      'http://192.168.1.8:5000/predict',
    ); // ✅ ton URL locale Flask
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(inputData),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      bool irrigation = data['irrigation_needed'];
      double quantity = data['recommended_quantity'];

      print('🌾 Résultat de la prédiction :');
      print('   - Irrigation requise : ${irrigation ? "✅ Oui" : "❌ Non"}');
      print('   - Quantité recommandée : $quantity mm/day');
    } else {
      print('❌ Erreur de la requête : ${response.statusCode}');
      print('Message : ${response.body}');
    }
  }

  Future<void> pickAndSendImageToFlask() async {
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);

  if (pickedFile != null) {
    File imageFile = File(pickedFile.path);
    final bytes = await imageFile.readAsBytes();
    String base64Image = base64Encode(bytes);

    final plantIdPayload = {
      "images": [base64Image],
      "organs": ["leaf", "flower", "fruit", "whole"],
      "plant_language": "en",
      "plant_details": ["common_names"],
    };

    try {
      final plantIdResponse = await http.post(
        Uri.parse('https://api.plant.id/v2/identify'),
        headers: {
          'Content-Type': 'application/json',
          'Api-Key': 'L9TWkSuDnnEOps88cClv6rUNGAK0PQJ7CzCPJ65i2SUJLftR3t',
        },
        body: jsonEncode(plantIdPayload),
      );

      if (plantIdResponse.statusCode == 200) {
        final result = jsonDecode(plantIdResponse.body);
        final suggestions = result["suggestions"] ?? [];
        String? crop;

        if (suggestions.isNotEmpty) {
          final commonNames = suggestions[0]["plant_details"]["common_names"] ?? [];
          crop = commonNames.isNotEmpty
              ? commonNames[0].toString().toLowerCase()
              : suggestions[0]["plant_name"].toString().toLowerCase();
        }

        print("🌱 Plante identifiée : $crop");

        if (crop != null) {
          // ✅ Appel à /identify pour obtenir le crop corrigé
          final identifyResponse = await http.post(
            Uri.parse('http://192.168.1.8:5000/identify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({"crop": crop}),
          );

          print("🧪 Réponse de /identify : ${identifyResponse.body}");

          final identifyJson = jsonDecode(identifyResponse.body);
          final correctedCrop = identifyJson["crop"]; 

          final sensorResponse = await http
              .get(Uri.parse('http://192.168.1.164/sensor'))
              .timeout(Duration(seconds: 5));

          if (sensorResponse.statusCode == 200) {
            final sensorData = jsonDecode(sensorResponse.body);
            final temperature = sensorData["temperature_sensor"];
            final humidity = sensorData["humidity_sensor"];
            final soilMoisture = sensorData["soil_moisture"];

            final updatePayload = {
              "timestamp": DateTime.now().toIso8601String(),
              "latitude": 36.3650,
              "longitude": 6.6147,
              "crop": correctedCrop,
              "temperature_sensor": temperature,
              "humidity_sensor": humidity,
              "soil_moisture": soilMoisture,
            };

            final updateResponse = await http.post(
              Uri.parse('http://192.168.1.8:5000/update_firebase'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(updatePayload),
            );

            if (updateResponse.statusCode == 200) {
              print("✅ Données envoyées à Firebase : ${updateResponse.body}");
            } else {
              print("❌ Erreur Firebase : ${updateResponse.statusCode}");
            }
          } else {
            print("❌ Erreur capteur ESP8266 : ${sensorResponse.statusCode}");
          }
        } else {
          print("❌ Aucune plante identifiée.");
        }
      } else {
        print('❌ Erreur Plant.id : ${plantIdResponse.statusCode}');
      }
    } catch (e) {
      print("❌ Exception : $e");
    }
  } else {
    print('❗ Aucune image sélectionnée.');
  }
}


  Future<Map<String, dynamic>?> fetchSensorData() async {
    try {
      final response = await http
          .get(Uri.parse('http://192.168.1.164/sensor'))
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("❌ Erreur capteur ESP8266 : ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Exception capteur : $e");
    }
    return null;
  }
  @override
  Widget build(BuildContext context) {
    return HomePageView(
      isLoading: isLoading,
      firebaseData: firebaseData,
      fadeAnimation: _fadeAnimation,
      onSignOut: () => _signOut(context),
      onRefresh: _onRefresh,
      formatParsedDate: formatParsedDate,
      formatTime: formatTime,
      onPickImage: pickAndSendImageToFlask,
      irrigationNeeded: irrigationNeeded,
      recommendedQuantity: recommendedQuantity,
      onSearch: (query) {
        print("Recherche utilisateur : $query");
      },
    );
  }
}
