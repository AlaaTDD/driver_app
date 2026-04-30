// lib/features/user/presentation/location_selection/bloc/location_bloc.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../../services/location_service.dart';
import 'location_event.dart';
import 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  // FIX L05: Use shared singleton instead of creating a new instance per bloc
  final LocationService _locationService = LocationService.instance;

  LocationBloc() : super(LocationInitial()) {
    on<SelectOrigin>(_onSelectOrigin);
    on<SelectDestination>(_onSelectDestination);
    on<SelectCurrentLocation>(_onSelectCurrentLocation);
    on<SearchLocation>(_onSearchLocation);
  }

  Future<void> _onSelectOrigin(
    SelectOrigin event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationSelected(
      lat: event.lat,
      lng: event.lng,
      address: event.address,
    ));
  }

  Future<void> _onSelectDestination(
    SelectDestination event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationSelected(
      lat: event.lat,
      lng: event.lng,
      address: event.address,
    ));
  }

  Future<void> _onSelectCurrentLocation(
    SelectCurrentLocation event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationSelectionLoading());
    try {
      final hasPermission = await _locationService.hasPermission();
      if (!hasPermission) await _locationService.requestPermission();
      final position = await _locationService.getCurrentLocation();
      String address = 'currentLocation';
      try {
        final placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          address = '${p.street ?? ''}, ${p.locality ?? ''}'.trim();
          if (address == ',') address = 'currentLocation';
        }
      } catch (e) {
        debugPrint('LocationBloc: geocoding failed — $e');
      }
      emit(LocationSelected(
        lat: position.latitude,
        lng: position.longitude,
        address: address,
      ));
    } catch (e, stackTrace) {
      debugPrint('❌ LocationBloc: SelectCurrentLocation failed: $e');
      debugPrint(stackTrace.toString());
      emit(const LocationSelectionError('errorGetLocation'));
    }
  }

  Future<void> _onSearchLocation(
    SearchLocation event,
    Emitter<LocationState> emit,
  ) async {
    if (event.query.trim().isEmpty) return;
    emit(LocationSelectionLoading());
    try {
      final locations = await locationFromAddress(event.query.trim());
      if (locations.isEmpty) {
        emit(const LocationSelectionError('errorLocationNotFound'));
        return;
      }
      final loc = locations.first;
      String address = event.query;
      try {
        final placemarks =
            await placemarkFromCoordinates(loc.latitude, loc.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          address = '${p.street ?? ''}, ${p.locality ?? ''}'.trim();
          if (address == ',') address = event.query;
        }
      } catch (e) {
        debugPrint('LocationBloc: geocoding failed — $e');
      }
      emit(LocationSelected(
        lat: loc.latitude,
        lng: loc.longitude,
        address: address,
      ));
    } catch (e, stackTrace) {
      debugPrint('❌ LocationBloc: SearchLocation failed: $e');
      debugPrint(stackTrace.toString());
      emit(const LocationSelectionError('errorSearchLocation'));
    }
  }
}
