// homepage_view.dart
import 'package:flutter/material.dart';

class HomePageView extends StatelessWidget {
  final bool isLoading;
  final Map<String, dynamic>? firebaseData;
  final Animation<double> fadeAnimation;
  final VoidCallback onSignOut;
  final Future<void> Function() onRefresh;
  final String Function(DateTime) formatParsedDate;
  final String Function(DateTime) formatTime;
  final Function(String) onSearch;
  final VoidCallback onPickImage;
  final bool? irrigationNeeded;
  final double? recommendedQuantity;

  const HomePageView({
    Key? key,
    required this.isLoading,
    required this.firebaseData,
    required this.fadeAnimation,
    required this.onSignOut,
    required this.onRefresh,
    required this.formatParsedDate,
    required this.formatTime,
    required this.onPickImage,
    required this.onSearch,
    required this.irrigationNeeded,
    required this.recommendedQuantity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child:
            isLoading
                ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.fromARGB(255, 66, 179, 151),
                    ),
                  ),
                )
                : FadeTransition(
                  opacity: fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(
                          context,
                          onPickImage,
                        ), // 👈 ici on passe la fonction
                        _buildWeatherAPIDataCard(),
                        const SizedBox(height: 20),
                        _buildCropAndSoilCard(),
                        const SizedBox(height: 20),
                        _buildSensorCards(),

                        const SizedBox(height: 20),
                        _buildIrrigationCard(),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, VoidCallback onPickImage) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 1, 133, 119),
            Color.fromARGB(255, 73, 215, 175),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hello, Farmer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatParsedDate(DateTime.now()),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last update: ${formatTime(DateTime.now())}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),
          _buildSearchBar(onPickImage), // ✅ Corrigé ici
        ],
      ),
    );
  }

  Widget _buildSearchBar(VoidCallback onPickImage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onPickImage,
            icon: const Icon(Icons.image),
            label: const Text("Choose crop image"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherAPIDataCard() {
    if (firebaseData == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Weather Data',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeatherMetric(
                Icons.thermostat,
                '${firebaseData!['Tair_f_tavg']}°C',
                'Air Temp',
              ),
              _buildWeatherMetric(
                Icons.water_drop,
                '${firebaseData!['Qair_f_tavg']}%',
                'Humidity',
              ),
              _buildWeatherMetric(
                Icons.air,
                '${firebaseData!['Wind_f_tavg']} m/s',
                'Wind',
              ),
              _buildWeatherMetric(
                Icons.grain,
                '${firebaseData!['Rainf_f_tavg']} mm',
                'Rain',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeatherMetric(
                Icons.wb_sunny,
                '${firebaseData!['SWdown_f_tavg']} W/m²',
                'Radiation',
              ),
              _buildWeatherMetric(
                Icons.speed,
                '${firebaseData!['Psurf_f_tavg']} hPa',
                'Pressure',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCropAndSoilCard() {
    if (firebaseData == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Soil & Crop Info',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeatherMetric(
                Icons.terrain,
                '${firebaseData!['Soil_Type']}',
                'Soil Type',
              ),
              _buildWeatherMetric(
                Icons.agriculture,
                '${firebaseData!['crop']}',
                'Crop',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCards() {
    if (firebaseData == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(
                'Physical Sensors',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeatherMetric(
                Icons.device_thermostat,
                '${firebaseData!['temperature']}°C',
                'Temperature',
              ),
              _buildWeatherMetric(
                Icons.water_drop,
                '${firebaseData!['humidity']}%',
                'Humidity',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildWeatherMetric(
                Icons.grass,
                '${firebaseData!['soil_moisture']}',
                'Soil Moisture',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherMetric(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildIrrigationCard() {
    if (firebaseData == null) return const SizedBox.shrink();

    final irrigationNeeded = firebaseData!['irrigation_needed'];
    final irrigationQuantity = firebaseData!['irrigation_quantity'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.opacity, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                'Irrigation Info',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
                _buildWeatherMetric(
                  Icons.check_circle,
                  (irrigationQuantity != null && irrigationQuantity >= 30 && irrigationNeeded == true)
                      ? 'Yes'
                      : 'No',
                  'Necessary',
                ),
                _buildWeatherMetric(
                  Icons.water,
                  (irrigationQuantity != null && irrigationQuantity >= 30)
                      ? '${irrigationQuantity.toStringAsFixed(2)} ml/m²'
                      : '0.00 ml/m²',
                  'Quantity',
                ),

            ],
          ),
        ],
      ),
    );
  }
}
