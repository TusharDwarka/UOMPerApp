import 'dart:convert'; void main() { var l = [1]; var res = l.map((s) => ({ 'key': s })).toList(); print(res); print(res.runtimeType); print(jsonEncode(res)); }
