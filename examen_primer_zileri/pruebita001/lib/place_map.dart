 
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'place.dart';
import 'place_details.dart';
import 'place_tracker_app.dart';

class MapConfiguration {
  final List<Place> places;

  final PlaceCategory selectedCategory;

  const MapConfiguration({
    required this.places,
    required this.selectedCategory,
  });

  @override
  int get hashCode => places.hashCode ^ selectedCategory.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other.runtimeType != runtimeType) {
      return false;
    }

    return other is MapConfiguration &&
        other.places == places &&
        other.selectedCategory == selectedCategory;
  }

  static MapConfiguration of(AppState appState) {
    return MapConfiguration(
      places: appState.places,
      selectedCategory: appState.selectedCategory,
    );
  }
}

class PlaceMap extends StatefulWidget {
  final LatLng? center;

  const PlaceMap({
    Key? key,
    this.center,
  }) : super(key: key);

  @override
  PlaceMapState createState() => PlaceMapState();
}

class PlaceMapState extends State<PlaceMap> {
  Completer<GoogleMapController> mapController = Completer();

  MapType _currentMapType = MapType.normal;

  LatLng? _lastMapPosition;

  final Map<Marker, Place> _markedPlaces = <Marker, Place>{};

  final Set<Marker> _markers = {};

  Marker? _pendingMarker;

  MapConfiguration? _configuration;

  @override
  Widget build(BuildContext context) {
    _maybeUpdateMapConfiguration();
    var state = Provider.of<AppState>(context);

    return Builder(builder: (context) {
      return Center(
        child: Stack(
          children: [
            GoogleMap(
              onMapCreated: onMapCreated,
              initialCameraPosition: CameraPosition(
                target: widget.center!,
                zoom: 16,
              ),
              mapType: _currentMapType,
              markers: _markers,
              onCameraMove: (position) => _lastMapPosition = position.target,
            ),
            _CategoryButtonBar(
              selectedPlaceCategory: state.selectedCategory,
              visible: _pendingMarker == null,
              onChanged: _switchSelectedCategory,
            ),
            _AddPlaceButtonBar(
              visible: _pendingMarker != null,
              onSavePressed: () => _confirmAddPlace(context),
              onCancelPressed: _cancelAddPlace,
            ),
            _MapFabs(
              visible: _pendingMarker == null,
              onAddPlacePressed: _onAddPlacePressed,
              onToggleMapTypePressed: _onToggleMapTypePressed,
            ),
          ],
        ),
      );
    });
  }

  Future<void> onMapCreated(GoogleMapController controller) async {
    mapController.complete(controller);
    _lastMapPosition = widget.center;

    // Dibujar marcadores de posición inicial en la creación para que tengamos algo
    // interesante de ver.
    var markers = <Marker>{};
    for (var place in Provider.of<AppState>(context, listen: false).places) {
      markers.add(await _createPlaceMarker(context, place));
    }
    setState(() {
      _markers.addAll(markers);
    });

    // Zoom para ajustar la categoría seleccionada inicialmente.
    _zoomToFitSelectedCategory();
  }

  @override
  void didUpdateWidget(PlaceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (mounted) {
      _zoomToFitSelectedCategory();
    }
  }

  void _zoomToFitSelectedCategory() {
    _zoomToFitPlaces(
      _getPlacesForCategory(
        Provider.of<AppState>(context, listen: false).selectedCategory,
        _markedPlaces.values.toList(),
      ),
    );
  }

  void _cancelAddPlace() {
    if (_pendingMarker != null) {
      setState(() {
        _markers.remove(_pendingMarker);
        _pendingMarker = null;
      });
    }
  }

  Future<void> _confirmAddPlace(BuildContext context) async {
    if (_pendingMarker != null) {
      // Crea un nuevo lugar y mapea el marcador que acabamos de agregar.
      final newPlace = Place(
        id: const Uuid().v1(),
        latLng: _pendingMarker!.position,
        name: _pendingMarker!.infoWindow.title!,
        category:
            Provider.of<AppState>(context, listen: false).selectedCategory,
      );

      var placeMarker = await _getPlaceMarkerIcon(context,
          Provider.of<AppState>(context, listen: false).selectedCategory);

      setState(() {
        final updatedMarker = _pendingMarker!.copyWith(
          iconParam: placeMarker,
          infoWindowParam: InfoWindow(
            title: 'New Place',
            snippet: null,
            onTap: () => _pushPlaceDetailsScreen(newPlace),
          ),
          draggableParam: false,
        );

        _updateMarker(
          marker: _pendingMarker,
          updatedMarker: updatedMarker,
          place: newPlace,
        );

        _pendingMarker = null;
      });

      // Muestra un snackbar de confirmación que tiene una acción para editar el nuevo lugar.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content:
              const Text('New place added.', style: TextStyle(fontSize: 16.0)),
          action: SnackBarAction(
            label: 'Edit',
            onPressed: () async {
              _pushPlaceDetailsScreen(newPlace);
            },
          ),
        ),
      );

     // Agrega el nuevo lugar a los lugares almacenados en appState.
      final newPlaces =
          List<Place>.from(Provider.of<AppState>(context, listen: false).places)
            ..add(newPlace);

      _configuration = MapConfiguration(
        places: newPlaces,
        selectedCategory:
            Provider.of<AppState>(context, listen: false).selectedCategory,
      );

      Provider.of<AppState>(context, listen: false).setPlaces(newPlaces);
    }
  }

  Future<Marker> _createPlaceMarker(BuildContext context, Place place) async {
    final marker = Marker(
      markerId: MarkerId(place.latLng.toString()),
      position: place.latLng,
      infoWindow: InfoWindow(
        title: place.name,
        snippet: '${place.starRating} Star Rating',
        onTap: () => _pushPlaceDetailsScreen(place),
      ),
      icon: await _getPlaceMarkerIcon(context, place.category),
      visible: place.category ==
          Provider.of<AppState>(context, listen: false).selectedCategory,
    );
    _markedPlaces[marker] = place;
    return marker;
  }

  Future<void> _maybeUpdateMapConfiguration() async {
    _configuration ??=
        MapConfiguration.of(Provider.of<AppState>(context, listen: false));
    final newConfiguration =
        MapConfiguration.of(Provider.of<AppState>(context, listen: false));

    if (_configuration != newConfiguration) {
      if (_configuration!.places == newConfiguration.places &&
          _configuration!.selectedCategory !=
              newConfiguration.selectedCategory) {

        await _showPlacesForSelectedCategory(newConfiguration.selectedCategory);
      } else {
        
        newConfiguration.places
            .where((p) => !_configuration!.places.contains(p))
            .map((value) => _updateExistingPlaceMarker(place: value));

        await _zoomToFitPlaces(
          _getPlacesForCategory(
            newConfiguration.selectedCategory,
            newConfiguration.places,
          ),
        );
      }
      _configuration = newConfiguration;
    }
  }

  Future<void> _onAddPlacePressed() async {
    setState(() {
      final newMarker = Marker(
        markerId: MarkerId(_lastMapPosition.toString()),
        position: _lastMapPosition!,
        infoWindow: const InfoWindow(title: 'New Place'),
        draggable: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );
      _markers.add(newMarker);
      _pendingMarker = newMarker;
    });
  }

  void _onPlaceChanged(Place value) {
    
    final newPlaces =
        List<Place>.from(Provider.of<AppState>(context, listen: false).places);
    final index = newPlaces.indexWhere((place) => place.id == value.id);
    newPlaces[index] = value;

    _updateExistingPlaceMarker(place: value);

    _configuration = MapConfiguration(
      places: newPlaces,
      selectedCategory:
          Provider.of<AppState>(context, listen: false).selectedCategory,
    );

    Provider.of<AppState>(context, listen: false).setPlaces(newPlaces);
  }

  void _onToggleMapTypePressed() {
    final nextType =
        MapType.values[(_currentMapType.index + 1) % MapType.values.length];

    setState(() {
      _currentMapType = nextType;
    });
  }

  void _pushPlaceDetailsScreen(Place place) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) {
        return PlaceDetails(
          place: place,
          onChanged: (value) => _onPlaceChanged(value),
        );
      }),
    );
  }

  Future<void> _showPlacesForSelectedCategory(PlaceCategory category) async {
    setState(() {
      for (var marker in List.of(_markedPlaces.keys)) {
        final place = _markedPlaces[marker]!;
        final updatedMarker = marker.copyWith(
          visibleParam: place.category == category,
        );

        _updateMarker(
          marker: marker,
          updatedMarker: updatedMarker,
          place: place,
        );
      }
    });

    await _zoomToFitPlaces(_getPlacesForCategory(
      category,
      _markedPlaces.values.toList(),
    ));
  }

  Future<void> _switchSelectedCategory(PlaceCategory category) async {
    Provider.of<AppState>(context, listen: false).setSelectedCategory(category);
    await _showPlacesForSelectedCategory(category);
  }

  void _updateExistingPlaceMarker({required Place place}) {
    var marker = _markedPlaces.keys
        .singleWhere((value) => _markedPlaces[value]!.id == place.id);

    setState(() {
      final updatedMarker = marker.copyWith(
        infoWindowParam: InfoWindow(
          title: place.name,
          snippet:
              place.starRating != 0 ? '${place.starRating} Star Rating' : null,
        ),
      );
      _updateMarker(marker: marker, updatedMarker: updatedMarker, place: place);
    });
  }

  void _updateMarker({
    required Marker? marker,
    required Marker updatedMarker,
    required Place place,
  }) {
    _markers.remove(marker);
    _markedPlaces.remove(marker);

    _markers.add(updatedMarker);
    _markedPlaces[updatedMarker] = place;
  }

  Future<void> _zoomToFitPlaces(List<Place> places) async {
    var controller = await mapController.future;

    var minLat = widget.center!.latitude;
    var maxLat = widget.center!.latitude;
    var minLong = widget.center!.longitude;
    var maxLong = widget.center!.longitude;

    for (var place in places) {
      minLat = min(minLat, place.latitude);
      maxLat = max(maxLat, place.latitude);
      minLong = min(minLong, place.longitude);
      maxLong = max(maxLong, place.longitude);
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLong),
          northeast: LatLng(maxLat, maxLong),
        ),
        48.0,
      ),
    );
  }

  static Future<BitmapDescriptor> _getPlaceMarkerIcon(
      BuildContext context, PlaceCategory category) async {
    switch (category) {
      case PlaceCategory.visited:
        return BitmapDescriptor.fromAssetImage(
            createLocalImageConfiguration(context, size: const Size.square(32)),
            'assets/visited.png');
      case PlaceCategory.wantToGo:
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  static List<Place> _getPlacesForCategory(
      PlaceCategory category, List<Place> places) {
    return places.where((place) => place.category == category).toList();
  }
}

class _AddPlaceButtonBar extends StatelessWidget {
  final bool visible;

  final VoidCallback onSavePressed;
  final VoidCallback onCancelPressed;

  const _AddPlaceButtonBar({
    Key? key,
    required this.visible,
    required this.onSavePressed,
    required this.onCancelPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: visible,
      child: Container(
        padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 14.0),
        alignment: Alignment.bottomCenter,
        child: ButtonBar(
          alignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(primary: Colors.blue),
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontSize: 16.0),
              ),
              onPressed: onSavePressed,
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(primary: Colors.red),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white, fontSize: 16.0),
              ),
              onPressed: onCancelPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryButtonBar extends StatelessWidget {
  final PlaceCategory selectedPlaceCategory;
  final bool visible;
  final ValueChanged<PlaceCategory> onChanged;

  const _CategoryButtonBar({
    Key? key,
    required this.selectedPlaceCategory,
    required this.visible,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: visible,
      child: Container(
        padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 14.0),
        alignment: Alignment.bottomCenter,
        child: ButtonBar(
          alignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  primary: selectedPlaceCategory == PlaceCategory.visited
                      ? Colors.green[700]
                      : Colors.lightGreen),
              child: const Text(
                'Visited',
                style: TextStyle(color: Colors.white, fontSize: 14.0),
              ),
              onPressed: () => onChanged(PlaceCategory.visited),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  primary: selectedPlaceCategory == PlaceCategory.wantToGo
                      ? Colors.green[700]
                      : Colors.lightGreen),
              child: const Text(
                'Want To Go',
                style: TextStyle(color: Colors.white, fontSize: 14.0),
              ),
              onPressed: () => onChanged(PlaceCategory.wantToGo),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapFabs extends StatelessWidget {
  final bool visible;
  final VoidCallback onAddPlacePressed;
  final VoidCallback onToggleMapTypePressed;

  const _MapFabs({
    Key? key,
    required this.visible,
    required this.onAddPlacePressed,
    required this.onToggleMapTypePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topRight,
      margin: const EdgeInsets.only(top: 12.0, right: 12.0),
      child: Visibility(
        visible: visible,
        child: Column(
          children: [
            FloatingActionButton(
              heroTag: 'add_place_button',
              onPressed: onAddPlacePressed,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              backgroundColor: Colors.green,
              child: const Icon(Icons.add_location, size: 36.0),
            ),
            const SizedBox(height: 12.0),
            FloatingActionButton(
              heroTag: 'toggle_map_type_button',
              onPressed: onToggleMapTypePressed,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              mini: true,
              backgroundColor: Colors.green,
              child: const Icon(Icons.layers, size: 28.0),
            ),
          ],
        ),
      ),
    );
  }
}