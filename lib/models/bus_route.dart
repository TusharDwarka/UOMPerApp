import 'package:isar_community/isar.dart';

part 'bus_route.g.dart';

@collection
class BusRoute {
  Id id = Isar.autoIncrement;

  late String routeNumber;
  late String destination;
  
  // Storing as string "HH:mm" for simplicity based on prompt, or DateTime
  late String arrivalTime; 
  
  // Optional: Bus name/provider if available (e.g. "UBS", "Private")
  String? busName;

  BusRoute({
    this.routeNumber = '',
    this.destination = '',
    this.arrivalTime = '',
    this.busName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'routeNumber': routeNumber,
        'destination': destination,
        'arrivalTime': arrivalTime,
        'busName': busName,
      };

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    final route = BusRoute(
      routeNumber: json['routeNumber'] ?? '',
      destination: json['destination'] ?? '',
      arrivalTime: json['arrivalTime'] ?? '',
      busName: json['busName'],
    );
    if (json['id'] != null) {
      route.id = json['id'];
    }
    return route;
  }
}
