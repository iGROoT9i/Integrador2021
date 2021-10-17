import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'place.dart';

class StubData {
  static const List<Place> places = [
    Place(
      id: '1',
      latLng: LatLng(45.430489, -122.831802),
      name: 'Amor Verde',
      description:
          '--',
      category: PlaceCategory.visited,
      starRating: 4,
    ),
    Place(
      id: '2',
      latLng: LatLng(45.383030, -122.758372),
      name: 'Rincón Verde',
      description:
          '--',
      category: PlaceCategory.visited,
      starRating: 4,
    ),
    Place(
      id: '3',
      latLng: LatLng(45.493321, -122.669330),
      name: 'Alisflores',
      description:
          '--',
      category: PlaceCategory.visited,
      starRating: 4,
    ),
    Place(
      id: '4',
      latLng: LatLng(45.548606, -122.675286),
      name: 'Inspira Vida',
      description:
          '--',
      category: PlaceCategory.wantToGo,
      starRating: 4,
    ),
    Place(
      id: '5',
      latLng: LatLng(45.541202, -122.676432),
      name: 'Teygarden Sac',
      description:
          '--',
      category: PlaceCategory.wantToGo,
      starRating: 4,
    ),
    Place(
      id: '6',
      latLng: LatLng(45.559783, -122.924103),
      name: 'Tisgho',
      description:
          '--',
      category: PlaceCategory.wantToGo,
      starRating: 5,
    )
  ];

}