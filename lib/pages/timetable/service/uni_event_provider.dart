import 'dart:async';

import 'package:acs_upb_mobile/pages/timetable/model/academic_calendar.dart';
import 'package:acs_upb_mobile/pages/timetable/model/uni_event.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rrule/rrule.dart';
import 'package:rrule/src/codecs/string/string.dart';
import 'package:time_machine/src/date_interval.dart';
import 'package:time_machine/src/localdate.dart';
import 'package:time_machine/time_machine.dart';
import 'package:timetable/timetable.dart';

extension UniEventTypeExtension on UniEventType {
  static UniEventType fromString(String string) {
    switch (string) {
      case 'lab':
        return UniEventType.lab;
      case 'lecture':
        return UniEventType.lecture;
      case 'seminar':
        return UniEventType.seminar;
      case 'sports':
        return UniEventType.sports;
    }
  }
}

extension PeriodExtension on Period {
  static Period fromJSON(Map<String, dynamic> json) {
    return Period(
      years: int.parse(json['years'] ?? '0'),
      months: int.parse(json['months'] ?? '0'),
      weeks: int.parse(json['weeks'] ?? '0'),
      days: int.parse(json['days'] ?? '0'),
      hours: int.parse(json['hours'] ?? '0'),
      minutes: int.parse(json['minutes'] ?? '0'),
      seconds: int.parse(json['seconds'] ?? '0'),
      milliseconds: int.parse(json['milliseconds'] ?? '0'),
      microseconds: int.parse(json['microseconds'] ?? '0'),
      nanoseconds: int.parse(json['nanoseconds'] ?? '0'),
    );
  }
}

extension RecurrenceRuleExtension on RecurrenceRule {
  static RecurrenceRule fromJSON(Map<String, dynamic> json) {
    if (json == null || json['frequency'] == null || json['until'] == null)
      return null;

    return RecurrenceRule(
      frequency: recurFreqValues[(json['frequency'] as String).toUpperCase()],
      interval: int.parse(json['interval'] ?? '1'),
      until: (json['until'] as Timestamp).toLocalDateTime(),
    );
  }
}

extension TimestampExtension on Timestamp {
  LocalDateTime toLocalDateTime() => LocalDateTime.dateTime(this.toDate())
      .inZoneStrictly(DateTimeZone.utc)
      .withZone(DateTimeZone.local)
      .localDateTime;
}

extension UniEventExtension on UniEvent {
  static UniEvent fromSnap(DocumentSnapshot snap) {
    return UniEvent(
      rrule: RecurrenceRuleExtension.fromJSON(snap['rrule']),
      id: snap.documentID,
      type: UniEventTypeExtension.fromString(snap.data['type']),
      name: snap.data['name'],
      // Convert time to UTC and then to local time
      start: (snap.data['start'] as Timestamp).toLocalDateTime(),
      duration: PeriodExtension.fromJSON(snap.data['duration']),
      location: snap.data['location'],
      // TODO: Allow users to set event colours in settings
      color: Colors.blue,
    );
  }
}

class UniEventProvider extends EventProvider<UniEventInstance>
    with ChangeNotifier {
  AcademicCalendar calendar = AcademicCalendar();

  Stream<List<UniEventInstance>> get _events {
    Stream<List<UniEvent>> e = Firestore.instance
        .collection('events')
        .snapshots()
        .map((snapshot) => snapshot.documents
            .map((document) => UniEventExtension.fromSnap(document))
            .toList());

    return e.map((events) =>
        events
            .map((event) => event.generateInstances(calendar: calendar))
            .expand((i) => i)
            .toList() +
        calendar.generateHolidayInstances());
  }

  @override
  Stream<Iterable<UniEventInstance>> getAllDayEventsIntersecting(
      DateInterval interval) {
    return _events
        .map((events) => events.allDayEvents.intersectingInterval(interval));
  }

  @override
  Stream<Iterable<UniEventInstance>> getPartDayEventsIntersecting(
      LocalDate date) {
    return _events.map((events) => events.partDayEvents.intersectingDate(date));
  }

  @override
  void dispose() {
    // TODO: Find a better way to prevent Timetable from calling dispose on this provider
  }
}
