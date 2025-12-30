import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
      double.parse(widget.emergency.latitude ?? '0'),
      double.parse(widget.emergency.longitude ?? '0'),
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
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('emergency'),
        position: emergencyLatLng,
        infoWindow: const InfoWindow(title: 'Lokasi Emergency'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    if (securityLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('security'),
          position: securityLatLng!,
          infoWindow: const InfoWindow(title: 'Posisi Security'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: emergencyLatLng,
          zoom: 15,
        ),
        markers: markers,
        myLocationEnabled: true,
        zoomControlsEnabled: false,
      ),
    );
  }
}

