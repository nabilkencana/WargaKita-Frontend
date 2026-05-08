import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:warga_app/models/security_location.dart';
import 'package:warga_app/models/sos_model.dart';

class EmergencyMap extends StatefulWidget {
  final Emergency emergency;
  final SecurityLocation? securityLocation;

  const EmergencyMap({
    super.key,
    required this.emergency,
    this.securityLocation,
  });

  @override
  State<EmergencyMap> createState() => _EmergencyMapState();
}

class _EmergencyMapState extends State<EmergencyMap> {
  late LatLng emergencyLatLng;
  LatLng? securityLatLng;

  @override
  void initState() {
    super.initState();

    emergencyLatLng = LatLng(
      double.tryParse(widget.emergency.latitude ?? '0') ?? 0.0,
      double.tryParse(widget.emergency.longitude ?? '0') ?? 0.0,
    );

    if (widget.securityLocation != null) {
      securityLatLng = LatLng(
        widget.securityLocation!.lat,
        widget.securityLocation!.lng,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      Marker(
        width: 40.0,
        height: 40.0,
        point: emergencyLatLng,
        child: const Icon(Icons.location_on, color: Colors.red, size: 40.0),
      ),
    ];

    if (securityLatLng != null) {
      markers.add(
        Marker(
          width: 40.0,
          height: 40.0,
          point: securityLatLng!,
          child: const Icon(Icons.security, color: Colors.blue, size: 40.0),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: emergencyLatLng,
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.warga_app',
          ),
          MarkerLayer(
            markers: markers,
          ),
        ],
      ),
    );
  }
}

