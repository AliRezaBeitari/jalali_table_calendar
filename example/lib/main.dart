import 'package:flutter/material.dart';
import 'package:jalali_table_calendar/jalali_table_calendar.dart';

extension DateTimeComparison on DateTime {
  bool isSameOrAfter(DateTime dt) {
    return this.isAtSameMomentAs(dt) || this.isAfter(dt);
  }

  bool isSameOrBefore(DateTime dt) {
    return this.isAtSameMomentAs(dt) || this.isBefore(dt);
  }
}

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

  List ranges = [];

  @override
  void initState() {
    super.initState();

    final past = DateTime.now().subtract(Duration(days: 5));
    final then = DateTime.now().add(Duration(days: 15));

    ranges = [
      [
        past.subtract(Duration(
            hours: past.hour,
            minutes: past.minute,
            seconds: past.second,
            milliseconds: past.millisecond,
            microseconds: past.microsecond)),
        then.subtract(Duration(
            hours: then.hour,
            minutes: then.minute,
            seconds: then.second,
            milliseconds: then.millisecond,
            microseconds: then.microsecond)),
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
        child: Theme(
          data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    secondary: Colors.red,
                  )),
          child: jalaliCalendar(
            context: context,
            firstDate: DateTime(currentYear - 1),
            lastDate: DateTime(currentYear + 2),
            isSelected: _isSelected,
            defaultDayDecoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            onDaySelected: _onDaySelected,
          ),
        ),
      ),
    );
  }

  void _onDaySelected(DateTime dt) {
    if (ranges.isEmpty) {
      // TODO: Assign [ranges] to newly created range
      return;
    }

    final s = ranges.first[0] as DateTime;
    if (dt.isBefore(s)) {
      // Add (dt, dt) at 0
      ranges.insert(0, [dt, dt]);

      setState(() => {}); // Update UI
      return;
    }

    final e = ranges.last[1] as DateTime;
    if (dt.isAfter(e)) {
      // Append (dt, dt) to ranges
      ranges.add([dt, dt]);

      setState(() => {}); // Update UI
      return;
    }

    for (int i = 0; i < ranges.length; i++) {
      final s = ranges[i][0] as DateTime;
      final e = ranges[i][1] as DateTime;

      if (dt.isSameOrAfter(s) && dt.isSameOrBefore(e)) {
        // Split (s, e) using [dt] pivot
        ranges[i] = [s, dt.subtract(Duration(days: 1))];
        ranges.insert(i + 1, [dt.add(Duration(days: 1)), e]);

        setState(() => {}); // Update UI
        return;
      }

      if (i + 1 < ranges.length) {
        final ns = ranges[i + 1][0] as DateTime;
        if (dt.isAfter(e) && dt.isBefore(ns)) {
          // Add (dt, dt) at i + 1
          ranges.insert(i + 1, [dt, dt]);

          setState(() => {}); // Update UI
          return;
        }
      }
    }
  }

  bool _isSelected(DateTime dt) {
    for (final r in ranges) {
      final s = r[0] as DateTime;
      final e = r[1] as DateTime;

      if (dt.isSameOrAfter(s) && dt.isSameOrBefore(e)) {
        return false;
      }
    }
    return true;
  }
}
