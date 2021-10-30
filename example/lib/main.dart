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
          onDaySelected: (date) {
            print(date);
          },
        ),
      ),
    );
  }
}
