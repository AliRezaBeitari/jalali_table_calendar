import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:jalali_table_calendar/src/persian_date.dart';

bool calendarInitialized = false;
//callback function when user change day
typedef void OnDaySelected(DateTime day);

const Duration _kMonthScrollDuration = Duration(milliseconds: 200);
const double _kDayPickerRowHeight = 50.0;
const int _kMaxDayPickerRowCount = 6; // A 31 day month that starts on Saturday.
// Two extra rows: one for the day-of-week header and one for the month header.
const double _kMaxDayPickerHeight =
    _kDayPickerRowHeight * (_kMaxDayPickerRowCount + 2);

class _DayPickerGridDelegate extends SliverGridDelegate {
  const _DayPickerGridDelegate();

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    const int columnCount = DateTime.daysPerWeek;
    final double tileWidth = constraints.crossAxisExtent / columnCount;
    final double tileHeight = math.min(_kDayPickerRowHeight,
        constraints.viewportMainAxisExtent / (_kMaxDayPickerRowCount + 1));
    return SliverGridRegularTileLayout(
      crossAxisCount: columnCount,
      mainAxisStride: tileHeight,
      crossAxisStride: tileWidth,
      childMainAxisExtent: tileHeight,
      childCrossAxisExtent: tileWidth,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(_DayPickerGridDelegate oldDelegate) => false;
}

const _DayPickerGridDelegate _kDayPickerGridDelegate = _DayPickerGridDelegate();

/// Displays the days of a given month and allows choosing a day.
///
/// The days are arranged in a rectangular grid with one column for each day of
/// the week.
///
/// The day picker widget is rarely used directly. Instead, consider using
/// [showDatePicker], which creates a date picker calendar.
///
/// See also:
///
///  * [showDatePicker].
///  * <https://material.google.com/components/pickers.html#pickers-date-pickers>
class CalendarDayPicker extends StatelessWidget {
  /// Creates a day picker.
  ///
  /// Rarely used directly. Instead, typically used as part of a [CalendarMonthPicker].
  CalendarDayPicker({
    Key key,
    @required this.selectedDates,
    @required this.currentDate,
    @required this.onChanged,
    @required this.firstDate,
    @required this.lastDate,
    @required this.displayedMonth,
    this.defaultDayDecoration,
    this.selectableDayPredicate,
  })  : assert(selectedDates != null),
        assert(currentDate != null),
        assert(onChanged != null),
        assert(displayedMonth != null),
        assert(!firstDate.isAfter(lastDate)),
        assert(selectedDates.every(
            (d) => d.isAfter(firstDate) || d.isAtSameMomentAs(firstDate))),
        super(key: key);

  /// The list of currently selected dates.
  ///
  /// These dates are highlighted in the picker.
  final List<DateTime> selectedDates;

  /// The current date at the time the picker is displayed.
  final DateTime currentDate;

  /// Called when the user picks a day.
  final ValueChanged<DateTime> onChanged;

  /// The earliest date the user is permitted to pick.
  final DateTime firstDate;

  /// The latest date the user is permitted to pick.
  final DateTime lastDate;

  /// The month whose days are displayed by this picker.
  final DateTime displayedMonth;


  /// The default decoration for days.
  final Decoration defaultDayDecoration;

  /// Optional user supplied predicate function to customize selectable days.
  final CalendarSelectableDayPredicate selectableDayPredicate;

  /// Builds widgets showing abbreviated days of week. The first widget in the
  /// returned list corresponds to the first day of week for the current locale.
  ///
  /// Examples:
  ///
  /// ```
  /// ┌ Sunday is the first day of week in the US (en_US)
  /// |
  /// S M T W T F S  <-- the returned list contains these widgets
  /// _ _ _ _ _ 1 2
  /// 3 4 5 6 7 8 9
  ///
  /// ┌ But it's Monday in the UK (en_GB)
  /// |
  /// M T W T F S S  <-- the returned list contains these widgets
  /// _ _ _ _ 1 2 3
  /// 4 5 6 7 8 9 10
  /// ```
  ///
  ///
  static List<String> dayShort = const [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه شنبه',
    'چهارشنبه',
    'پنج شنبه',
    'جمعه',
  ];

  static List<String> dayH = const [
    'ش',
    'ی',
    'د',
    'س',
    'چ',
    'پ',
    'ج',
  ];

  List<Widget> _getDayHeaders() {
    final List<Widget> result = <Widget>[];
    for (String dayHeader in dayH) {
      result.add(ExcludeSemantics(
        child: Center(child: Text(dayHeader)),
      ));
    }
    return result;
  }

  static const List<int> _daysInMonth = <int>[
    31,
    31,
    31,
    31,
    31,
    31,
    30,
    30,
    30,
    30,
    30,
    -1
  ];

// if mode year on 33 equal one of kabise array year is kabise
  static const List<int> _kabise = <int>[1, 5, 9, 13, 17, 22, 26, 30];

  static int getDaysInMonth(int year, int month) {
    var modeYear = year % 33;
    if (month == 12) return _kabise.indexOf(modeYear) != -1 ? 30 : 29;

    return _daysInMonth[month - 1];
  }

  /// Computes the offset from the first day of week that the first day of the
  /// [month] falls on.
  ///
  /// For example, September 1, 2017 falls on a Friday, which in the calendar
  /// localized for United States English appears as:
  ///
  /// ```
  /// S M T W T F S
  /// _ _ _ _ _ 1 2
  /// ```
  ///
  /// The offset for the first day of the months is the number of leading blanks
  /// in the calendar, i.e. 5.
  ///
  /// The same date localized for the Russian calendar has a different offset,
  /// because the first day of week is Monday rather than Sunday:
  ///
  /// ```
  /// M T W T F S S
  /// _ _ _ _ 1 2 3
  /// ```
  ///
  /// So the offset is 4, rather than 5.
  ///
  /// This code consolidates the following:
  ///
  /// - [DateTime.weekday] provides a 1-based index into days of week, with 1
  ///   falling on Monday.
  /// - [MaterialLocalizations.firstDayOfWeekIndex] provides a 0-based index
  ///   into the [MaterialLocalizations.narrowWeekdays] list.
  /// - [MaterialLocalizations.narrowWeekdays] list provides localized names of
  ///   days of week, always starting with Sunday and ending with Saturday.
  final PersianDate date = PersianDate.pDate();

  String _digits(int value, int length) {
    String ret = '$value';
    if (ret.length < length) {
      ret = '0' * (length - ret.length) + ret;
    }
    return ret;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData = Theme.of(context);
    final MaterialLocalizations localizations =
        MaterialLocalizations.of(context);
    final int year = displayedMonth.year;
    final int month = displayedMonth.month;
    final int mDay = displayedMonth.day;

    final PersianDate getPearData =
        PersianDate.pDate(gregorian: displayedMonth.toString());

    final List<PersianDate> selectedPersianDates = selectedDates
        .map<PersianDate>((d) => PersianDate.pDate(gregorian: d.toString()))
        .toList();

    final PersianDate currentPDate =
        PersianDate.pDate(gregorian: currentDate.toString());

    final List<Widget> labels = <Widget>[];

    var pDay = _digits(mDay, 2);
    var gMonth = _digits(month, 2);

    var parseP = date.parse("$year-$gMonth-$pDay");
    var jtgData = date.jalaliToGregorian(parseP[0], parseP[1], 01);

    var pMonth = _digits(jtgData[1], 2);

    PersianDate pDate =
        PersianDate.pDate(gregorian: "${jtgData[0]}-$pMonth-${jtgData[2]}");
    var daysInMonth = getDaysInMonth(pDate.year, pDate.month);
    var startDay = dayShort.indexOf(pDate.weekDayName);

    labels.addAll(_getDayHeaders());
    for (int i = 0; true; i += 1) {
      final int day = i - startDay + 1;
      if (day > daysInMonth) break;
      if (day < 1) {
        labels.add(Container());
      } else {
        var pDay = _digits(day, 2);
        var jtgData = date.jalaliToGregorian(
            getPearData.year, getPearData.month, int.parse(pDay));
        final DateTime dayToBuild =
            DateTime(jtgData[0], jtgData[1], jtgData[2]);
        final PersianDate getHoliday =
            PersianDate.pDate(gregorian: dayToBuild.toString());

        final bool disabled = dayToBuild.isAfter(lastDate) ||
            dayToBuild.isBefore(firstDate) ||
            (selectableDayPredicate != null &&
                !selectableDayPredicate([dayToBuild]));

        BoxDecoration decoration = defaultDayDecoration;
        TextStyle itemStyle = themeData.textTheme.bodyText1;

        final bool isSelectedDay = selectedPersianDates.any((d) =>
            d.year == getPearData.year &&
            d.month == getPearData.month &&
            d.day == day);

        if (isSelectedDay) {
          // The selected day gets a circle background highlight, and a contrasting text color.
          itemStyle = themeData.textTheme.bodyText2;
          decoration = BoxDecoration(
              color: themeData.colorScheme.secondary, shape: BoxShape.circle);
        } else if (disabled) {
          itemStyle = themeData.textTheme.bodyText1
              .copyWith(color: themeData.disabledColor);
        } else if (currentPDate.year == getPearData.year &&
            currentPDate.month == getPearData.month &&
            currentPDate.day == day) {
          // The current day gets a different text color.
          itemStyle = themeData.textTheme.bodyText2
              .copyWith(color: themeData.colorScheme.secondary);
        } else if (getHoliday.isHoliday) {
          // The current day gets a different text color.
          itemStyle = themeData.textTheme.bodyText2.copyWith(color: Colors.red);
        }

        Widget dayWidget = Container(
          decoration: decoration,
          child: Center(
            child: Semantics(
              // We want the day of month to be spoken first irrespective of the
              // locale-specific preferences or TextDirection. This is because
              // an accessibility user is more likely to be interested in the
              // day of month before the rest of the date, as they are looking
              // for the day of month. To do that we prepend day of month to the
              // formatted full date.
              label:
                  '${localizations.formatDecimal(day)}, ${localizations.formatFullDate(dayToBuild)}',
              selected: isSelectedDay,
              child: ExcludeSemantics(
                child: Text(day.toString(), style: itemStyle),
              ),
            ),
          ),
        );

        if (!disabled) {
          dayWidget = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              onChanged(dayToBuild);
            },
            child: dayWidget,
          );
        }

        labels.add(dayWidget);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: <Widget>[
              Container(
                height: _kDayPickerRowHeight,
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(
                      "${pDate.monthName}  ${pDate.year}",
                      style: themeData.textTheme.headline5,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: GridView.custom(
                  gridDelegate: _kDayPickerGridDelegate,
                  childrenDelegate: SliverChildListDelegate(labels,
                      addRepaintBoundaries: false),
                ),
              ),
            ],
          )),
    );
  }
}

/// A scrollable list of months to allow picking a month.
///
/// Shows the days of each month in a rectangular grid with one column for each
/// day of the week.
///
/// The month picker widget is rarely used directly. Instead, consider using
/// [showDatePicker], which creates a date picker calendar.
///
/// See also:
///
///  * [showDatePicker]
///  * <https://material.google.com/components/pickers.html#pickers-date-pickers>
class CalendarMonthPicker extends StatefulWidget {
  /// Creates a month picker.
  ///
  /// Rarely used directly. Instead, typically used as part of the calendar shown
  /// by [showDatePicker].
  CalendarMonthPicker({
    Key key,
    @required this.selectedDates,
    @required this.onChanged,
    @required this.firstDate,
    @required this.lastDate,
    this.defaultDayDecoration,
    this.selectableDayPredicate,
  })  : assert(selectedDates != null),
        assert(onChanged != null),
        assert(!firstDate.isAfter(lastDate)),
        assert(selectedDates.every(
            (d) => d.isAfter(firstDate) || d.isAtSameMomentAs(firstDate))),
        super(key: key);

  /// The list of currently selected dates.
  ///
  /// These dates are highlighted in the picker.
  final List<DateTime> selectedDates;

  /// Called when the user picks a month.
  final ValueChanged<DateTime> onChanged;

  /// The earliest date the user is permitted to pick.
  final DateTime firstDate;

  /// The latest date the user is permitted to pick.
  final DateTime lastDate;

  /// The default decoration for days.
  final Decoration defaultDayDecoration;

  /// Optional user supplied predicate function to customize selectable days.
  final CalendarSelectableDayPredicate selectableDayPredicate;

  @override
  _CalendarMonthPickerState createState() => _CalendarMonthPickerState();
}

class _CalendarMonthPickerState extends State<CalendarMonthPicker>
    with SingleTickerProviderStateMixin {
  static final Animatable<double> _chevronOpacityTween =
      Tween<double>(begin: 1.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    // Initially display the pre-selected date.
    final int monthPage =
        _monthDelta(widget.firstDate, widget.selectedDates.first) + 1;
    _dayPickerController = PageController(initialPage: monthPage);
    _handleMonthPageChanged(monthPage);
    _updateCurrentDate();

    // Setup the fade animation for chevrons
    _chevronOpacityController = AnimationController(
        duration: const Duration(milliseconds: 250), vsync: this);
    _chevronOpacityAnimation =
        _chevronOpacityController.drive(_chevronOpacityTween);
  }

  @override
  void didUpdateWidget(CalendarMonthPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.selectedDates, oldWidget.selectedDates)) {
      final int monthPage =
          _monthDelta(widget.firstDate, widget.selectedDates.first) + 1;
      _dayPickerController = PageController(initialPage: monthPage);
      _handleMonthPageChanged(monthPage);
    }
  }

  MaterialLocalizations localizations;
  TextDirection textDirection;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = MaterialLocalizations.of(context);
    textDirection = Directionality.of(context);
  }

  DateTime _todayDate;
  DateTime _currentDisplayedMonthDate;
  Timer _timer;
  PageController _dayPickerController;
  AnimationController _chevronOpacityController;
  Animation<double> _chevronOpacityAnimation;

  void _updateCurrentDate() {
    _todayDate = DateTime.now();
    final DateTime tomorrow =
        DateTime(_todayDate.year, _todayDate.month, _todayDate.day + 1);
    Duration timeUntilTomorrow = tomorrow.difference(_todayDate);
    timeUntilTomorrow +=
        const Duration(seconds: 1); // so we don't miss it by rounding
    _timer?.cancel();
    _timer = Timer(timeUntilTomorrow, () {
      setState(() {
        _updateCurrentDate();
      });
    });
  }

  static int _monthDelta(DateTime startDate, DateTime endDate) {
    return (endDate.year - startDate.year) * 12 +
        endDate.month -
        startDate.month;
  }

  /// Add months to a month truncated date.
  DateTime _addMonthsToMonthDate(DateTime monthDate, int monthsToAdd) {
    return DateTime(
        monthDate.year + monthsToAdd ~/ 12, monthDate.month + monthsToAdd % 12);
  }

  Widget _buildItems(BuildContext context, int index) {
    DateTime month = _addMonthsToMonthDate(widget.firstDate, index);

    // FIXME
    /*final PersianDate selectedPersianDate = PersianDate.pDate(
        gregorian: widget.selectedDate.toString()); // To Edit Month Display

    if (selectedPersianDate.day >= 1 &&
        selectedPersianDate.day < 12 &&
        !calendarInitialized) {
      month = _addMonthsToMonthDate(widget.firstDate, index + 1);
      _handleNextMonth(initialized: false);
    }*/

    // if (!widget.isSelected && !changed) {
    // }
    calendarInitialized = true;
    return CalendarDayPicker(
      selectedDates: widget.selectedDates,
      currentDate: _todayDate,
      onChanged: widget.onChanged,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      displayedMonth: month,
      defaultDayDecoration: widget.defaultDayDecoration,
      selectableDayPredicate: widget.selectableDayPredicate,
    );
  }

  void _handleNextMonth({initialized = true}) async {
    if (!_isDisplayingLastMonth) {
      _dayPickerController.nextPage(
          duration:
              initialized ? _kMonthScrollDuration : Duration(milliseconds: 1),
          curve: Curves.ease);
    }
  }

  void _handlePreviousMonth() {
    if (!_isDisplayingFirstMonth) {
      _dayPickerController.previousPage(
          duration: _kMonthScrollDuration, curve: Curves.ease);
    }
  }

  /// True if the earliest allowable month is displayed.
  bool get _isDisplayingFirstMonth {
    return !_currentDisplayedMonthDate
        .isAfter(DateTime(widget.firstDate.year, widget.firstDate.month));
  }

  /// True if the latest allowable month is displayed.
  bool get _isDisplayingLastMonth {
    return !_currentDisplayedMonthDate
        .isBefore(DateTime(widget.lastDate.year, widget.lastDate.month));
  }

  DateTime _previousMonthDate;
  DateTime _nextMonthDate;

  void _handleMonthPageChanged(int monthPage) {
    setState(() {
      _previousMonthDate =
          _addMonthsToMonthDate(widget.firstDate, monthPage - 1);
      _currentDisplayedMonthDate =
          _addMonthsToMonthDate(widget.firstDate, monthPage);
      _nextMonthDate = _addMonthsToMonthDate(widget.firstDate, monthPage + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Semantics(
          sortKey: _MonthPickerSortKey.calendar,
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (_) {
              _chevronOpacityController.forward();
              return false;
            },
            child: NotificationListener<ScrollEndNotification>(
              onNotification: (_) {
                _chevronOpacityController.reverse();
                return false;
              },
              child: PageView.builder(
                controller: _dayPickerController,
                scrollDirection: Axis.horizontal,
                itemCount: _monthDelta(widget.firstDate, widget.lastDate) + 1,
                itemBuilder: _buildItems,
                onPageChanged: _handleMonthPageChanged,
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 0.0,
          start: 8.0,
          child: Semantics(
            sortKey: _MonthPickerSortKey.previousMonth,
            child: FadeTransition(
              opacity: _chevronOpacityAnimation,
              child: IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: _isDisplayingFirstMonth
                    ? null
                    : '${localizations.previousMonthTooltip} ${localizations.formatMonthYear(_previousMonthDate)}',
                onPressed:
                    _isDisplayingFirstMonth ? null : _handlePreviousMonth,
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 0.0,
          end: 8.0,
          child: Semantics(
            sortKey: _MonthPickerSortKey.nextMonth,
            child: FadeTransition(
              opacity: _chevronOpacityAnimation,
              child: IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: _isDisplayingLastMonth
                    ? null
                    : '${localizations.nextMonthTooltip} ${localizations.formatMonthYear(_nextMonthDate)}',
                onPressed: _isDisplayingLastMonth ? null : _handleNextMonth,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dayPickerController?.dispose();
    calendarInitialized = false;
    super.dispose();
  }
}

// Defines semantic traversal order of the top-level widgets inside the month
// picker.
class _MonthPickerSortKey extends OrdinalSortKey {
  const _MonthPickerSortKey(double order) : super(order);

  static const _MonthPickerSortKey previousMonth = _MonthPickerSortKey(1.0);
  static const _MonthPickerSortKey nextMonth = _MonthPickerSortKey(2.0);
  static const _MonthPickerSortKey calendar = _MonthPickerSortKey(3.0);
}

class _DatePickerCalendar extends StatefulWidget {
  const _DatePickerCalendar(
      {Key key,
      this.initialDates,
      this.firstDate,
      this.lastDate,
      this.defaultDayDecoration,
      this.selectableDayPredicate,
      this.selectedFormat,
      this.showTimePicker,
      this.convertToGregorian,
      this.initialTime,
      this.onDaySelected,
      this.hour24Format})
      : super(key: key);

  final List<DateTime> initialDates;
  final DateTime firstDate;
  final DateTime lastDate;
  final Decoration defaultDayDecoration;
  final CalendarSelectableDayPredicate selectableDayPredicate;
  final String selectedFormat;
  final bool convertToGregorian;
  final bool showTimePicker;
  final bool hour24Format;
  final TimeOfDay initialTime;

  /// Called whenever any day gets tapped.
  final OnDaySelected onDaySelected;

  @override
  _DatePickerCalendarState createState() => _DatePickerCalendarState();
}

class _DatePickerCalendarState extends State<_DatePickerCalendar> {
  List<DateTime> _selectedDates;
  final GlobalKey _pickerKey = GlobalKey();

  MaterialLocalizations localizations;
  TextDirection textDirection;

  @override
  void initState() {
    super.initState();
    _selectedDates = widget.initialDates;
  }

  void _handleDayChanged(DateTime value) {
    if (widget.onDaySelected != null) widget.onDaySelected(value);

    final index = _selectedDates.indexWhere((d) =>
        d.year == value.year && d.month == value.month && d.day == value.day);

    setState(() {
      if (index >= 0) {
        _selectedDates.removeAt(index);
      } else {
        _selectedDates.add(value);
      }
    });
  }

  Widget _buildWidget() {
    return CalendarMonthPicker(
      key: _pickerKey,
      selectedDates: _selectedDates,
      onChanged: _handleDayChanged,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      defaultDayDecoration: widget.defaultDayDecoration,
      selectableDayPredicate: widget.selectableDayPredicate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget picker = SizedBox(
      height: _kMaxDayPickerHeight,
      child: _buildWidget(),
    );

    final Widget calendar = OrientationBuilder(
        builder: (BuildContext context, Orientation orientation) {
      assert(orientation != null);
      switch (orientation) {
        case Orientation.portrait:
          return picker;
        case Orientation.landscape:
          return picker;
      }
      return null;
    });
    // _handleDayChanged(widget.initialDate);
    return calendar;
  }
}

/// Signature for predicating dates for enabled date selections.
///
/// See [showDatePicker].
typedef CalendarSelectableDayPredicate = bool Function(List<DateTime> days);

/// Shows a dialog containing a material design date picker.
///
/// The returned [Future] resolves to the date selected by the user when the
/// user closes the dialog. If the user cancels the dialog, null is returned.
///
/// An optional [selectableDayPredicate] function can be passed in to customize
/// the days to enable for selection. If provided, only the days that
/// [selectableDayPredicate] returned true for will be selectable.
///
/// An optional [initialDatePickerMode] argument can be used to display the
/// date picker initially in the year or month+day picker mode. It defaults
/// to month+day, and must not be null.
///
/// An optional [locale] argument can be used to set the locale for the date
/// picker. It defaults to the ambient locale provided by [Localizations].
///
/// An optional [textDirection] argument can be used to set the text direction
/// (RTL or LTR) for the date picker. It defaults to the ambient text direction
/// provided by [Directionality]. If both [locale] and [textDirection] are not
/// null, [textDirection] overrides the direction chosen for the [locale].
///
/// The `context` argument is passed to [showDialog], the documentation for
/// which discusses how it is used.
///
/// See also:
///
///  * [showTimePicker]
///  * <https://material.google.com/components/pickers.html#pickers-date-pickers>
Widget jalaliCalendar({
  @required BuildContext context,
  Decoration defaultDayDecoration,
  CalendarSelectableDayPredicate selectableDayPredicate,
  String selectedFormat,
  bool toArray,
  Locale locale,
  TextDirection textDirection = TextDirection.rtl,
  bool convertToGregorian = false,
  bool showTimePicker = false,
  bool hour24Format = false,
  TimeOfDay initialTime,
  OnDaySelected onDaySelected,
}) {
  List<DateTime> initialDates = [DateTime.now()];
  DateTime firstDate = DateTime(1700);
  DateTime lastDate = DateTime(2200);

  assert(!initialDates.any((d) => d.isBefore(firstDate)),
      'initialDate must be on or after firstDate');
  assert(!initialDates.any((d) => d.isAfter(lastDate)),
      'initialDate must be on or before lastDate');
  assert(
      !firstDate.isAfter(lastDate), 'lastDate must be on or after firstDate');
  assert(selectableDayPredicate == null || selectableDayPredicate(initialDates),
      'Provided initialDate must satisfy provided selectableDayPredicate');
  // assert(context != null);
  // assert(debugCheckHasMaterialLocalizations(context));

  Widget child = _DatePickerCalendar(
    initialDates: initialDates,
    firstDate: firstDate,
    lastDate: lastDate,
    defaultDayDecoration: defaultDayDecoration,
    selectableDayPredicate: selectableDayPredicate,
    selectedFormat: selectedFormat ?? "yyyy-mm-dd HH:nn:ss",
    hour24Format: hour24Format,
    showTimePicker: showTimePicker,
    onDaySelected: onDaySelected,
    convertToGregorian: convertToGregorian,
    initialTime: initialTime ?? TimeOfDay.now(),
  );

  if (textDirection != null) {
    child = Directionality(
      textDirection: textDirection,
      child: child,
    );
  }

  if (locale != null) {
    child = Localizations.override(
      context: context,
      locale: locale,
      child: child,
    );
  }

  return child;
}
