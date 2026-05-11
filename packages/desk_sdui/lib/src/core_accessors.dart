import 'runtime.dart';

/// Registers the built-in `dart:core` getters that desk_sdui supports out of
/// the box. Call this once during runtime setup (codegen does this for you
/// via `registerAllScreens`).
void registerCoreAccessors(Runtime rt) {
  // String
  rt.registerGetter('String.length',     (r) => (r as String).length);
  rt.registerGetter('String.isEmpty',    (r) => (r as String).isEmpty);
  rt.registerGetter('String.isNotEmpty', (r) => (r as String).isNotEmpty);
  rt.registerGetter('String.hashCode',   (r) => (r as String).hashCode);
  rt.registerGetter('String.runes',      (r) => (r as String).runes);
  rt.registerGetter('String.codeUnits',  (r) => (r as String).codeUnits);

  // Iterable<T> — covers List, Set, Iterable, Map.keys/values
  Object? _iterLen(Object? r)    => (r as Iterable).length;
  Object? _iterEmpty(Object? r)  => (r as Iterable).isEmpty;
  Object? _iterNonEmpty(Object? r) => (r as Iterable).isNotEmpty;
  Object? _iterFirst(Object? r)  {
    final it = r as Iterable;
    return it.isEmpty ? null : it.first;
  }
  Object? _iterLast(Object? r)   {
    final it = r as Iterable;
    return it.isEmpty ? null : it.last;
  }
  Object? _iterSingle(Object? r) {
    final it = r as Iterable;
    return it.length == 1 ? it.single : null;
  }
  for (final t in const ['Iterable', 'List', 'Set']) {
    rt.registerGetter('$t.length',     _iterLen);
    rt.registerGetter('$t.isEmpty',    _iterEmpty);
    rt.registerGetter('$t.isNotEmpty', _iterNonEmpty);
    rt.registerGetter('$t.first',      _iterFirst);
    rt.registerGetter('$t.last',       _iterLast);
    rt.registerGetter('$t.single',     _iterSingle);
  }

  // Map
  rt.registerGetter('Map.length',     (r) => (r as Map).length);
  rt.registerGetter('Map.isEmpty',    (r) => (r as Map).isEmpty);
  rt.registerGetter('Map.isNotEmpty', (r) => (r as Map).isNotEmpty);
  rt.registerGetter('Map.keys',       (r) => (r as Map).keys);
  rt.registerGetter('Map.values',     (r) => (r as Map).values);
  rt.registerGetter('Map.entries',    (r) => (r as Map).entries);

  // num / int / double
  for (final t in const ['num', 'int', 'double']) {
    rt.registerGetter('$t.isNaN',      (r) => (r as num).isNaN);
    rt.registerGetter('$t.isFinite',   (r) => (r as num).isFinite);
    rt.registerGetter('$t.isInfinite', (r) => (r as num).isInfinite);
    rt.registerGetter('$t.isNegative', (r) => (r as num).isNegative);
    rt.registerGetter('$t.sign',       (r) => (r as num).sign);
    rt.registerGetter('$t.abs',        (r) => (r as num).abs());
    rt.registerGetter('$t.round',      (r) => (r as num).round());
    rt.registerGetter('$t.floor',      (r) => (r as num).floor());
    rt.registerGetter('$t.ceil',       (r) => (r as num).ceil());
    rt.registerGetter('$t.truncate',   (r) => (r as num).truncate());
  }
  rt.registerGetter('int.isEven', (r) => (r as int).isEven);
  rt.registerGetter('int.isOdd',  (r) => (r as int).isOdd);

  // DateTime
  rt.registerGetter('DateTime.year',         (r) => (r as DateTime).year);
  rt.registerGetter('DateTime.month',        (r) => (r as DateTime).month);
  rt.registerGetter('DateTime.day',          (r) => (r as DateTime).day);
  rt.registerGetter('DateTime.hour',         (r) => (r as DateTime).hour);
  rt.registerGetter('DateTime.minute',       (r) => (r as DateTime).minute);
  rt.registerGetter('DateTime.second',       (r) => (r as DateTime).second);
  rt.registerGetter('DateTime.millisecond',  (r) => (r as DateTime).millisecond);
  rt.registerGetter('DateTime.weekday',      (r) => (r as DateTime).weekday);
  rt.registerGetter('DateTime.isUtc',        (r) => (r as DateTime).isUtc);

  // Duration
  rt.registerGetter('Duration.inDays',         (r) => (r as Duration).inDays);
  rt.registerGetter('Duration.inHours',        (r) => (r as Duration).inHours);
  rt.registerGetter('Duration.inMinutes',      (r) => (r as Duration).inMinutes);
  rt.registerGetter('Duration.inSeconds',      (r) => (r as Duration).inSeconds);
  rt.registerGetter('Duration.inMilliseconds', (r) => (r as Duration).inMilliseconds);
}
