// ownerQuoteForm — susun penawaran biaya (PRD v1.3 Bagian 4.1 & 4.2).
// 1–10 butir (nama, jenis jasa/sparepart, harga), total, catatan,
// foto bukti (maks 3, ≤ 2 MB). Server menghitung ulang total & batas.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/media_guard.dart';
import '../../../design/components/app_button.dart';
import '../../quote/data/quote_models.dart';
import '../../quote/data/quote_repository.dart';
import '../data/owner_sos_repository.dart';
import '../domain/owner_sos_logic.dart';
import 'owner_sos_controller.dart';

class OwnerQuoteFormScreen extends ConsumerStatefulWidget {
  const OwnerQuoteFormScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<OwnerQuoteFormScreen> createState() =>
      _OwnerQuoteFormScreenState();
}

class _Row {
  _Row()
      : item = QuoteDraftItem(),
        name = TextEditingController(),
        price = TextEditingController();
  final QuoteDraftItem item;
  final TextEditingController name;
  final TextEditingController price;
  final key = UniqueKey();

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class _Photo {
  _Photo(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
}

class _OwnerQuoteFormScreenState extends ConsumerState<OwnerQuoteFormScreen> {
  final List<_Row> _rows = [_Row()];
  final _note = TextEditingController();
  final List<_Photo> _photos = [];
  QuoteLimits _limits = const QuoteLimits();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(ownerSosRepositoryProvider).getQuoteLimits().then((l) {
      if (mounted) setState(() => _limits = l);
    });
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  List<QuoteDraftItem> get _items => _rows.map((r) => r.item).toList();

  void _addRow() {
    if (_rows.length >= _limits.maxItems) return;
    setState(() => _rows.add(_Row()));
  }

  void _removeRow(_Row r) {
    setState(() {
      _rows.remove(r);
      r.dispose();
      if (_rows.isEmpty) _rows.add(_Row());
    });
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= _limits.maxPhotos) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final x = await ImagePicker()
          .pickImage(source: source, imageQuality: 80, maxWidth: 1600);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      MediaGuard.ensureBytesUnderLimit(bytes);
      final mime =
          x.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      setState(() => _photos.add(_Photo(bytes, mime)));
    } on MediaTooLargeException catch (e) {
      _snack(e.message, bad: true);
    } catch (e) {
      _snack('gagal memilih foto: $e', bad: true);
    }
  }

  void _snack(String msg, {bool bad = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bad ? context.colors.bad : null,
      ),
    );
  }

  Future<void> _submit() async {
    final err =
        validateQuoteDraft(_items, limits: _limits, photoCount: _photos.length);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(ownerSosRepositoryProvider);
      final urls = <String>[];
      for (final p in _photos) {
        urls.add(
          await repo.uploadQuotePhoto(
            requestId: widget.requestId,
            bytes: p.bytes,
            contentType: p.mime,
          ),
        );
      }
      await QuoteRepository().createQuote(
        QuoteCreateRequest(
          sosRequestId: widget.requestId,
          items: _items.map((i) => i.toItem()).toList(),
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          photos: urls,
        ),
      );
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
      _snack('penawaran terkirim. menunggu persetujuan pengendara.');
      unawaited(
        ref.read(ownerSosControllerProvider.notifier).refreshOffersAndJob(),
      );
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/owner/sos/${widget.requestId}/route');
      }
    } on MediaTooLargeException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(
        () => _error = OwnerSosRepository.friendlyError(e)
            .replaceFirst('Gagal membuat penawaran: ', ''),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = quoteDraftTotal(_items);
    final over = total > _limits.maxTotal;

    return Scaffold(
      backgroundColor: c.stage,
      appBar: AppBar(
        title: const Text('Penawaran biaya'),
        backgroundColor: c.panel,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'pengendara harus menyetujui dan membayar sebelum kamu mengerjakan perbaikan. '
                    'berlaku 10 menit.',
                    style: AppTypography.body.copyWith(color: c.ink2),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _rows.length; i++)
                    _ItemRow(
                      key: _rows[i].key,
                      index: i,
                      row: _rows[i],
                      canRemove: _rows.length > 1,
                      onChanged: () => setState(() => _error = null),
                      onRemove: () => _removeRow(_rows[i]),
                    ),
                  if (_rows.length < _limits.maxItems)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addRow,
                        icon: const Icon(Icons.add),
                        label: Text(
                          'Tambah butir (${_rows.length}/${_limits.maxItems})',
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _note,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: 'Catatan (opsional)',
                      hintText: 'mis. ban dalam sobek 3 cm, perlu diganti',
                      filled: true,
                      fillColor: c.panel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Foto bukti (${_photos.length}/${_limits.maxPhotos})',
                    style: AppTypography.label.copyWith(color: c.ink2),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _photos.length; i++)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _photos[i].bytes,
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Semantics(
                                button: true,
                                label: 'hapus foto ${i + 1}',
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _photos.removeAt(i)),
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.black54,
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (_photos.length < _limits.maxPhotos)
                        Semantics(
                          button: true,
                          label: 'tambah foto bukti',
                          child: InkWell(
                            onTap: _pickPhoto,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: c.panel,
                                border: Border.all(color: c.line),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.add_a_photo_outlined,
                                color: c.ink2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: c.panel,
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Total',
                        style: AppTypography.bodyStrong.copyWith(color: c.ink),
                      ),
                      const Spacer(),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: total.toDouble()),
                        duration: Motion.respect(
                          context,
                          const Duration(milliseconds: 300),
                        ),
                        builder: (_, v, __) => Text(
                          Formatters.rupiah(v.round()),
                          style: AppTypography.h1
                              .copyWith(color: over ? c.badText : c.ink),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      style: AppTypography.caption.copyWith(color: c.badText),
                    ),
                  ],
                  const SizedBox(height: 10),
                  AppButton(
                    label: 'Kirim penawaran',
                    icon: Icons.send_outlined,
                    loading: _submitting,
                    onPressed: _submitting ? null : _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.index,
    required this.row,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _Row row;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    InputDecoration deco(String label, {String? prefix}) => InputDecoration(
          labelText: label,
          prefixText: prefix,
          isDense: true,
          filled: true,
          fillColor: c.panel2,
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.panel,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Butir ${index + 1}',
                style: AppTypography.label.copyWith(color: c.ink2),
              ),
              const Spacer(),
              SegmentedButton<QuoteItemType>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: QuoteItemType.jasa, label: Text('Jasa')),
                  ButtonSegment(
                    value: QuoteItemType.sparepart,
                    label: Text('Sparepart'),
                  ),
                ],
                selected: {row.item.type},
                onSelectionChanged: (s) {
                  row.item.type = s.first;
                  onChanged();
                },
              ),
              if (canRemove)
                IconButton(
                  tooltip: 'Hapus butir',
                  icon: Icon(Icons.delete_outline, color: c.bad),
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.name,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 80,
            decoration: deco('Nama pekerjaan / sparepart'),
            onChanged: (v) {
              row.item.name = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.price,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: deco('Harga', prefix: 'Rp '),
            onChanged: (v) {
              row.item.price = parseRupiahInput(v);
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}
