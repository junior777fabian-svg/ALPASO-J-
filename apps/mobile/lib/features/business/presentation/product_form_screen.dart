import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/core/format/money.dart';
import 'package:alpaso/features/auth/presentation/auth_form_widgets.dart';
import 'package:alpaso/features/business/data/business_providers.dart';
import 'package:alpaso/features/business/domain/offer.dart';
import 'package:alpaso/features/business/presentation/business_messages.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// N3. Crear o editar un extra de la carta.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({required this.lodgingId, this.productId, super.key});

  final String lodgingId;
  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  ProductCategory? _category;
  bool _isAvailable = true;
  bool _loaded = false;
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.productId == null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  void _fill(Product product) {
    if (_loaded) return;
    _loaded = true;
    _name.text = product.draft.name;
    _description.text = product.draft.description;
    _price.text = centsToInput(product.draft.priceCents);
    _category = product.draft.category;
    _isAvailable = product.draft.isAvailable;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(productsProvider(widget.lodgingId));
      if (mounted) context.pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(
        () => _error = businessFailureMessage(
          AppLocalizations.of(context),
          error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    if (_busy || !_formKey.currentState!.validate()) return;
    _run(
      () => ref
          .read(businessRepositoryProvider)!
          .saveProduct(
            widget.lodgingId,
            ProductDraft(
              name: _name.text,
              description: _description.text,
              category: _category!,
              priceCents: parseSolesToCents(_price.text)!,
              isAvailable: _isAvailable,
            ),
            productId: widget.productId,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _isNew ? l10n.productNewTitle : l10n.productEditTitle;
    final alcohol =
        ref.watch(platformRulesProvider).value?.alcoholEnabled ?? false;

    if (!_isNew) {
      final product = ref
          .watch(productsProvider(widget.lodgingId))
          .value
          ?.where((p) => p.id == widget.productId)
          .firstOrNull;
      if (product == null) {
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      _fill(product);
    }

    final categories = [
      for (final c in ProductCategory.values)
        if (c != ProductCategory.alcohol || alcohol || _category == c) c,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: l10n.deleteAction,
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => ref
                          .read(businessRepositoryProvider)!
                          .deleteProduct(widget.productId!),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('product-name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 60,
                  decoration: InputDecoration(
                    labelText: l10n.productNameLabel,
                    counterText: '',
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    return t.length < 2 || t.length > 60
                        ? l10n.lodgingErrorLength(2, 60)
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<ProductCategory>(
                  key: const Key('product-category'),
                  initialValue: _category,
                  decoration: InputDecoration(
                    labelText: l10n.productCategoryLabel,
                  ),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(
                        value: c,
                        child: Text(productCategoryLabel(l10n, c)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                  validator: (v) =>
                      v == null ? l10n.productErrorCategory : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('product-price'),
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.productPriceLabel,
                    prefixText: 'S/ ',
                  ),
                  validator: (v) {
                    final cents = parseSolesToCents(v ?? '');
                    return cents == null || cents < 50 || cents > 100000
                        ? l10n.productErrorPrice
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _description,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: l10n.lodgingDescriptionLabel,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.productAvailableLabel),
                  value: _isAvailable,
                  onChanged: (v) => setState(() => _isAvailable = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_error != null) ...[
                  FormErrorBox(message: _error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                SubmitButton(
                  label: l10n.profileSaveAction,
                  busy: _busy,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
