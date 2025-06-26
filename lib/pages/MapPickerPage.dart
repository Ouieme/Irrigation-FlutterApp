import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  MapPickerPageState createState() => MapPickerPageState();
}

class MapPickerPageState extends State<MapPickerPage> {
  LatLng? _pickedLocation;
  GoogleMapController? _mapController; // Nullable car usage facultatif

  void _onMapTap(LatLng position) {
    setState(() {
      _pickedLocation = position;
    });

    // Exemple d’utilisation du contrôleur : centrer la carte sur le point sélectionné
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  void _onConfirm() {
    if (_pickedLocation != null) {
      Navigator.pop(context, _pickedLocation);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez sélectionner un emplacement.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choisir un emplacement')),
      body: Stack(
        children: [
          GoogleMap(
            onTap: _onMapTap,
            initialCameraPosition: const CameraPosition(
              target: LatLng(48.8566, 2.3522), // Paris par défaut
              zoom: 12,
            ),
            markers: _pickedLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('picked'),
                      position: _pickedLocation!,
                    ),
                  }
                : {},
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
          Positioned(
            bottom: 20,
            left: 40,
            right: 40,
            child: ElevatedButton(
              onPressed: _onConfirm,
              child: const Text('✅ Confirmer l\'emplacement'),
            ),
          ),
        ],
      ),
    );
  }
}
