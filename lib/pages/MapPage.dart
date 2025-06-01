import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:urbanai/scripts/secret.dart';
import 'package:http/http.dart' as http;

class MapPage extends StatefulWidget {
  final String address;

  const MapPage({Key? key, required this.address}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng? _location;
  String? _error;
  late GoogleMapController _mapController;
  final String apiKey = googleMapsApiKey;

  @override
  void initState() {
    super.initState();
    _getCoordinatesFromAddress(widget.address);
  }

  Future<void> _getCoordinatesFromAddress(String address) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$apiKey',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['results'][0]['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];
          setState(() {
            _location = LatLng(lat, lng);
          });
        } else {
          setState(() {
            _error = 'Endereço inválido: ${data['status']}';
          });
        }
      } else {
        setState(() {
          _error = 'Erro HTTP: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao buscar localização: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mapa')),
      body:
          _error != null
              ? Center(
                child: Text(_error!, style: TextStyle(color: Colors.red)),
              )
              : _location == null
              ? Center(child: CircularProgressIndicator())
              : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _location!,
                  zoom: 16,
                ),
                onMapCreated: (controller) => _mapController = controller,
                markers: {
                  Marker(
                    markerId: MarkerId('destino'),
                    position: _location!,
                    infoWindow: InfoWindow(title: widget.address),
                  ),
                },
              ),
    );
  }
}
