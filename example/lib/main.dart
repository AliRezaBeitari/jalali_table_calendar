import 'package:flutter/material.dart';
import 'package:jalali_table_calendar/jalali_table_calendar.dart';

void main() {
  runApp(new MaterialApp(
    debugShowCheckedModeBanner: false,
    home: new MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  @override
  _State createState() => new _State();
}

class _State extends State<MyApp> {
  final currentYear = DateTime.now().year;

  List ranges = [
    [
      DateTime.now(),
      DateTime.now().add(Duration(days: 7)),
    ],
  ];

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final then = DateTime.now().add(Duration(days: 7));

    ranges = [
      [
        now.subtract(Duration(hours: now.hour, minutes: now.minute, seconds: now.second, milliseconds: now.millisecond, microseconds: now.microsecond)),
        then.subtract(Duration(hours: then.hour, minutes: then.minute, seconds: then.second, milliseconds: then.millisecond, microseconds: then.microsecond)),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jalili Table Calendar'),
        centerTitle: true,
      ),
      body: Container(
        child: jalaliCalendar(
          context: context,
          firstDate: DateTime(currentYear - 1),
          lastDate: DateTime(currentYear + 2),
          isSelected: _isSelected,
          defaultDayDecoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          onDaySelected: (date) {
            print(date);
          },
        ),
      ),
    );
  }

  bool _isSelected(DateTime dt) {
    for (final r in ranges) {
      final s = r[0] as DateTime;
      final e = r[1] as DateTime;

      print('dt: $dt \t s: $s \t e: $e');

      if ((dt.isAtSameMomentAs(s) || dt.isAfter(s)) && (dt.isAtSameMomentAs(e) || dt.isBefore(e))) {
        return true;
      }
    }
    return false;
  }
}
