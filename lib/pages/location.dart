import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPageView extends StatefulWidget {
  const LocationPageView({Key? key}) : super(key: key);

  @override
  _LocationPageViewState createState() => _LocationPageViewState();
}

class _LocationPageViewState extends State<LocationPageView> {
  LatLng _pickedLocation = const LatLng(36.3182022, 6.6918667);

  void _onMapTap(LatLng position) {
    setState(() {
      _pickedLocation = position;
    });
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: const Color(0xFF009688),
      elevation: 0,
      title: const Text(
        'Location',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    ), // ← Missing comma was here
    body: Column(
      children: [
        Expanded(
          flex: 3,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickedLocation,
              zoom: 15,
            ),
            onTap: _onMapTap,
            markers: {
              Marker(
                markerId: const MarkerId("picked"),
                position: _pickedLocation,
              ),
            },
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Selected Coordinates",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Latitude: ${_pickedLocation.latitude.toStringAsFixed(5)}\n"
                    "Longitude: ${_pickedLocation.longitude.toStringAsFixed(5)}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}