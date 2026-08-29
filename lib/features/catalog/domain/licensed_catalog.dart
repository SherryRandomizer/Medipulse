import 'dart:convert';
import 'dart:io';

import 'package:medipulse/core/config/app_config.dart';

class LicensedCatalogEntry {
  const LicensedCatalogEntry({
    required this.providerRecordId,
    required this.label,
    this.formLabel,
  });

  final String providerRecordId;
  final String label;
  final String? formLabel;
}

enum InteractionLookupStatus { notConfigured, providerEmpty, providerReturned }

class LicensedInteractionLookup {
  const LicensedInteractionLookup({
    required this.status,
    this.providerNotes = const [],
  });

  factory LicensedInteractionLookup.notConfigured() {
    return const LicensedInteractionLookup(status: InteractionLookupStatus.notConfigured);
  }

  final InteractionLookupStatus status;
  final List<String> providerNotes;
}

abstract class LicensedMedicationCatalog {
  bool get isConfigured;
  Future<List<LicensedCatalogEntry>> search(String query);
  Future<LicensedInteractionLookup> lookupInteractions(List<String> providerRecordIds);
}

class UnconfiguredLicensedCatalog implements LicensedMedicationCatalog {
  const UnconfiguredLicensedCatalog();

  @override
  bool get isConfigured => false;

  @override
  Future<List<LicensedCatalogEntry>> search(String query) async => const [];

  @override
  Future<LicensedInteractionLookup> lookupInteractions(List<String> providerRecordIds) async {
    return LicensedInteractionLookup.notConfigured();
  }
}

class HttpLicensedMedicationCatalog implements LicensedMedicationCatalog {
  HttpLicensedMedicationCatalog({required AppConfig config, HttpClient? client})
    : _config = config,
      _client = client ?? HttpClient();

  final AppConfig _config;
  final HttpClient _client;

  @override
  bool get isConfigured => _config.medicalCatalogConfigured;

  @override
  Future<List<LicensedCatalogEntry>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty || !isConfigured) return const [];
    try {
      final uri = Uri.parse(_config.apiBaseUrl).replace(
        path: '/v1/medications',
        queryParameters: {'q': q},
      );
      final request = await _client.getUrl(uri);
      request.headers.set('Authorization', 'Bearer ${_config.medicalDataApiKey}');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) return const [];
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['items'] is! List) return const [];
      final items = <LicensedCatalogEntry>[];
      for (final raw in decoded['items'] as List) {
        if (raw is! Map) continue;
        final id = raw['id']?.toString();
        final label = raw['label']?.toString();
        if (id == null || id.isEmpty || label == null || label.isEmpty) continue;
        items.add(
          LicensedCatalogEntry(
            providerRecordId: id,
            label: label,
            formLabel: raw['form']?.toString(),
          ),
        );
      }
      return items;
    } on Object {
      return const [];
    }
  }

  @override
  Future<LicensedInteractionLookup> lookupInteractions(List<String> providerRecordIds) async {
    if (!isConfigured) return LicensedInteractionLookup.notConfigured();
    final ids = providerRecordIds.where((id) => id.trim().isNotEmpty).toList();
    if (ids.isEmpty) {
      return const LicensedInteractionLookup(status: InteractionLookupStatus.providerEmpty);
    }
    try {
      final uri = Uri.parse(_config.apiBaseUrl).replace(
        path: '/v1/interactions',
        queryParameters: {'ids': ids.join(',')},
      );
      final request = await _client.getUrl(uri);
      request.headers.set('Authorization', 'Bearer ${_config.medicalDataApiKey}');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const LicensedInteractionLookup(status: InteractionLookupStatus.providerEmpty);
      }
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['notes'] is! List) {
        return const LicensedInteractionLookup(status: InteractionLookupStatus.providerEmpty);
      }
      final notes = [
        for (final n in decoded['notes'] as List)
          if (n != null && n.toString().trim().isNotEmpty) n.toString(),
      ];
      if (notes.isEmpty) {
        return const LicensedInteractionLookup(status: InteractionLookupStatus.providerEmpty);
      }
      return LicensedInteractionLookup(
        status: InteractionLookupStatus.providerReturned,
        providerNotes: notes,
      );
    } on Object {
      return const LicensedInteractionLookup(status: InteractionLookupStatus.providerEmpty);
    }
  }
}
