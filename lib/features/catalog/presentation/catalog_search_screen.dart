import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/features/catalog/domain/licensed_catalog.dart';
import 'package:medipulse/l10n/app_localizations.dart';
import 'package:medipulse/shared/widgets/app_components.dart';

class CatalogSearchScreen extends ConsumerStatefulWidget {
  const CatalogSearchScreen({super.key});

  @override
  ConsumerState<CatalogSearchScreen> createState() => _CatalogSearchScreenState();
}

class _CatalogSearchScreenState extends ConsumerState<CatalogSearchScreen> {
  final _query = TextEditingController();
  List<LicensedCatalogEntry> _results = [];
  LicensedInteractionLookup? _interactions;
  bool _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    final catalog = ref.read(licensedCatalogProvider);
    final results = await catalog.search(_query.text);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
      _interactions = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(licensedCatalogProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.catalogTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!catalog.isConfigured) Text(l10n.catalogUnconfigured),
          const SizedBox(height: 12),
          AppTextField(label: l10n.catalogSearchHint, controller: _query),
          const SizedBox(height: 12),
          AppButton(
            label: l10n.catalogSearchHint,
            onPressed: catalog.isConfigured && !_searching ? _search : null,
          ),
          if (_searching) const Padding(padding: EdgeInsets.all(16), child: LoadingState()),
          if (!_searching && catalog.isConfigured && _results.isEmpty && _query.text.trim().isNotEmpty)
            Text(l10n.catalogEmpty),
          for (final item in _results)
            ListTile(
              title: Text(item.label),
              subtitle: Text(item.formLabel ?? item.providerRecordId),
              onTap: () => context.pop(item.label),
            ),
          const SizedBox(height: 16),
          AppButton(
            label: l10n.checkInteractions,
            onPressed: !catalog.isConfigured
                ? null
                : () async {
                    final lookup = await catalog.lookupInteractions(
                      _results.map((e) => e.providerRecordId).toList(),
                    );
                    if (mounted) setState(() => _interactions = lookup);
                  },
          ),
          if (_interactions != null) ...[
            const SizedBox(height: 12),
            if (_interactions!.status == InteractionLookupStatus.notConfigured)
              Text(l10n.interactionsUnconfigured)
            else if (_interactions!.status == InteractionLookupStatus.providerEmpty)
              Text(l10n.catalogEmpty)
            else
              for (final note in _interactions!.providerNotes) Text(note),
          ],
        ],
      ),
    );
  }
}
