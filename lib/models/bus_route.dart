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
}
