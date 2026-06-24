import 'package:equatable/equatable.dart';

class AppConfigModel extends Equatable {
  final Map<String, Object?> values;

  const AppConfigModel(this.values);

  const AppConfigModel.empty() : values = const {};

  T getValue<T>(String key, T defaultValue) {
    final value = values[key];
    if (value is T) return value;
    return defaultValue;
  }

  Object? getRaw(String key) => values[key];

  Iterable<String> get keys => values.keys;

  bool get isEmpty => values.isEmpty;

  Map<String, Object?> toJson() => Map<String, Object?>.from(values);

  @override
  List<Object?> get props => [values];
}
