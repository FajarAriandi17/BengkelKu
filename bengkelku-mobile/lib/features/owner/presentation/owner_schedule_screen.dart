// ownerSchedule — pemilik mengatur sendiri jadwal buka/tutup bengkel (0026):
// status buka sekarang + tutup sementara, jam mingguan per hari, durasi slot &
// kapasitas, serta libur khusus per tanggal. Perubahan jam baru disimpan saat
// tombol "Simpan jadwal" ditekan; tutup sementara & libur langsung berlaku.

import "dart:async";

import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../core/motion/motion.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/state_views.dart";
import "../data/owner_schedule.dart";

class OwnerScheduleScreen extends StatefulWidget {
  const OwnerScheduleScreen({super.key, this.repository});

  final OwnerScheduleRepository? repository;

  @override
  State<OwnerScheduleScreen> createState() => _OwnerScheduleScreenState();
}

class _OwnerScheduleScreenState extends State<OwnerScheduleScreen> {
  late final OwnerScheduleRepository _repo =
      widget.repository ?? OwnerScheduleRepository();

  OwnerSchedule? _s;
  List<DayHours> _hours = [];
  int _slot = 60;
  int _capacity = 1;
  bool _dirty = false;
  bool _loading = true;
  bool _saving = false;
  bool _busyStatus = false;
  String? _error;

  static const _slotOptions = [30, 45, 60, 90, 120];
  // Urutan tampil Senin..Minggu (lebih lazim di Indonesia).
  static const _displayOrder = [1, 2, 3, 4, 5, 6, 0];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = _s == null;
      _error = null;
    });
    try {
      final s = await _repo.get();
      if (!mounted) return;
      _apply(s);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = scheduleErrorMessage(e);
        _loading = false;
      });
    }
  }

  void _apply(OwnerSchedule s, {bool keepDraft = false}) {
    setState(() {
      _s = s;
      if (!keepDraft) {
        _hours = List.of(s.hours);
        _slot = _slotOptions.contains(s.slotMinutes) ? s.slotMinutes : 60;
        _capacity = s.capacity.clamp(1, 20);
        _dirty = false;
      }
      _loading = false;
    });
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: error ? context.colors.bad : null,
        ),
      );
  }

  void _update(int weekday, DayHours Function(DayHours) f) {
    setState(() {
      _hours = [
        for (final h in _hours) h.weekday == weekday ? f(h) : h,
      ];
      _dirty = true;
    });
  }

  void _preset(String key) {
    setState(() {
      _hours = [
        for (final h in _hours)
          switch (key) {
            "weekdays" => h.copyWith(
                open: "08:00",
                close: "17:00",
                isClosed: h.weekday == 0,
              ),
            "everyday" =>
              h.copyWith(open: "08:00", close: "21:00", isClosed: false),
            _ => h,
          },
      ];
      _dirty = true;
    });
  }

  void _copyMondayToAll() {
    final mon = _hours.firstWhere((h) => h.weekday == 1);
    setState(() {
      _hours = [
        for (final h in _hours)
          h.weekday == 0
              ? h
              : h.copyWith(
                  open: mon.open,
                  close: mon.close,
                  isClosed: mon.isClosed,
                ),
      ];
      _dirty = true;
    });
    _snack("jam Senin disalin ke Selasa–Sabtu");
  }

  Future<void> _pickTime(DayHours d, {required bool open}) async {
    final cur = open ? d.open : d.close;
    final m = DayHours.minutes(cur);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      helpText: "${open ? "Jam buka" : "Jam tutup"} · ${d.dayName}",
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null) return;
    final v =
        "${t.hour.toString().padLeft(2, "0")}:${t.minute.toString().padLeft(2, "0")}";
    _update(
        d.weekday, (h) => open ? h.copyWith(open: v) : h.copyWith(close: v));
  }

  Future<void> _save() async {
    final invalid = _hours.where((h) => !h.isValid).toList();
    if (invalid.isNotEmpty) {
      _snack(
        "jam tutup ${invalid.first.dayName} harus setelah jam buka",
        error: true,
      );
      return;
    }
    if (_hours.every((h) => h.isClosed)) {
      _snack(
        "minimal satu hari buka. untuk libur panjang pakai Tutup sementara.",
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final s = await _repo.saveHours(
        _hours,
        slotMinutes: _slot,
        capacity: _capacity,
      );
      if (!mounted) return;
      _apply(s);
      _snack("jadwal tersimpan. pelanggan melihat jam terbaru.");
    } catch (e) {
      if (mounted) _snack(scheduleErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _tempClose() async {
    final r = await showModalBottomSheet<TempCloseResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TempCloseSheet(hours: _hours),
    );
    if (r == null) return;
    setState(() => _busyStatus = true);
    try {
      final s = await _repo.setTempClosed(r.until, reason: r.reason);
      if (!mounted) return;
      _apply(s, keepDraft: _dirty);
      _snack(
        "bengkel ditutup sampai ${DateFormat("EEE d MMM, HH:mm", "id_ID").format(r.until)}",
      );
    } catch (e) {
      if (mounted) _snack(scheduleErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busyStatus = false);
    }
  }

  Future<void> _reopen() async {
    setState(() => _busyStatus = true);
    try {
      final s = await _repo.setTempClosed(null);
      if (!mounted) return;
      _apply(s, keepDraft: _dirty);
      _snack("bengkel dibuka kembali sesuai jadwal");
    } catch (e) {
      if (mounted) _snack(scheduleErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busyStatus = false);
    }
  }

  Future<void> _addClosure() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: "Pilih tanggal libur",
    );
    if (date == null || !mounted) return;
    final reason = await _askReason(date);
    if (reason == null) return;
    try {
      final affected =
          await _repo.addClosure(date, reason.isEmpty ? null : reason);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      _snack(
        affected > 0
            ? "libur ditambahkan. ada $affected booking aktif di tanggal ini — hubungi pelanggan atau tolak dari dasbor."
            : "libur ditambahkan. slot di tanggal itu ditutup.",
      );
    } catch (e) {
      if (mounted) _snack(scheduleErrorMessage(e), error: true);
    }
  }

  Future<String?> _askReason(DateTime date) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(DateFormat("EEEE, d MMMM yyyy", "id_ID").format(date)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: "Alasan (opsional)",
            hintText: "mis. Hari raya, cuti bersama",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text("Tambahkan"),
          ),
        ],
      ),
    );
  }

  Future<void> _removeClosure(Closure c) async {
    try {
      await _repo.removeClosure(c.date);
      await _load();
      if (mounted) _snack("libur dihapus. slot dibuka kembali.");
    } catch (e) {
      if (mounted) _snack(scheduleErrorMessage(e), error: true);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Buang perubahan?"),
        content: const Text("jam yang kamu ubah belum disimpan."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Lanjut edit"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Buang"),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget body;
    if (_loading) {
      body = const Padding(padding: EdgeInsets.all(16), child: SkeletonList());
    } else if (_error != null && _s == null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else {
      final s = _s!;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _StatusCard(
              schedule: s,
              busy: _busyStatus,
              onTempClose: _tempClose,
              onReopen: _reopen,
            ),
            if (!s.hasHours) ...[
              const SizedBox(height: 12),
              _Hint(
                icon: Icons.info_outline,
                text:
                    "kamu belum menyimpan jam buka. sementara pelanggan melihat jam bawaan 08:00–17:00 setiap hari.",
              ),
            ],
            const SizedBox(height: 24),
            _SectionTitle(
              title: "Jam buka mingguan",
              trailing: PopupMenuButton<String>(
                tooltip: "Pola cepat",
                icon: Icon(Icons.auto_awesome_outlined, color: c.blue),
                onSelected: (v) =>
                    v == "copy" ? _copyMondayToAll() : _preset(v),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: "weekdays",
                    child: Text("Senin–Sabtu 08:00–17:00"),
                  ),
                  PopupMenuItem(
                    value: "everyday",
                    child: Text("Setiap hari 08:00–21:00"),
                  ),
                  PopupMenuItem(
                    value: "copy",
                    child: Text("Salin jam Senin ke Selasa–Sabtu"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _Panel(
              child: Column(
                children: [
                  for (final (i, wd) in _displayOrder.indexed) ...[
                    if (i > 0) Divider(height: 1, color: c.line),
                    _DayRow(
                      day: _hours.firstWhere((h) => h.weekday == wd),
                      slotsPerDay: OwnerSchedule.slotsPerDay(
                        _hours.firstWhere((h) => h.weekday == wd),
                        _slot,
                      ),
                      onToggle: (open) =>
                          _update(wd, (h) => h.copyWith(isClosed: !open)),
                      onOpenTap: (d) => _pickTime(d, open: true),
                      onCloseTap: (d) => _pickTime(d, open: false),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle(title: "Slot booking"),
            const SizedBox(height: 8),
            _Panel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Durasi per slot",
                    style: AppTypography.label.copyWith(color: c.ink),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in _slotOptions)
                        ChoiceChip(
                          label: Text("$m mnt"),
                          selected: _slot == m,
                          onSelected: (_) => setState(() {
                            _slot = m;
                            _dirty = true;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Motor per slot",
                              style: AppTypography.label.copyWith(color: c.ink),
                            ),
                            Text(
                              "sesuaikan jumlah mekanik/lift",
                              style:
                                  AppTypography.caption.copyWith(color: c.ink2),
                            ),
                          ],
                        ),
                      ),
                      _Stepper(
                        value: _capacity,
                        min: 1,
                        max: 20,
                        onChanged: (v) => setState(() {
                          _capacity = v;
                          _dirty = true;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Hint(
                    icon: Icons.event_available_outlined,
                    text:
                        "kapasitas per minggu: ${_hours.fold<int>(0, (a, h) => a + OwnerSchedule.slotsPerDay(h, _slot)) * _capacity} booking",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: "Libur khusus",
              trailing: TextButton.icon(
                onPressed: _addClosure,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Tambah"),
              ),
            ),
            const SizedBox(height: 8),
            if (s.closures.isEmpty)
              _Panel(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.beach_access_outlined, color: c.ink2),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "belum ada libur. tambahkan hari raya atau cuti agar pelanggan tidak bisa booking di tanggal itu.",
                        style: AppTypography.caption.copyWith(color: c.ink2),
                      ),
                    ),
                  ],
                ),
              )
            else
              _Panel(
                child: Column(
                  children: [
                    for (final (i, cl) in s.closures.indexed) ...[
                      if (i > 0) Divider(height: 1, color: c.line),
                      _ClosureTile(
                        closure: cl,
                        onRemove: () => _removeClosure(cl),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) nav.pop();
      },
      child: Scaffold(
        backgroundColor: c.panel2,
        appBar: AppBar(title: const Text("Jadwal Buka"), elevation: 0),
        body: SafeArea(child: body),
        bottomNavigationBar: AnimatedSwitcher(
          duration: Motion.respect(context, Motion.dStd),
          switchInCurve: Motion.easeOut,
          transitionBuilder: (child, a) => SizeTransition(
            sizeFactor: a,
            axisAlignment: -1,
            child: FadeTransition(opacity: a, child: child),
          ),
          child: _dirty
              ? SafeArea(
                  key: const ValueKey("save"),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: c.panel,
                      border: Border(top: BorderSide(color: c.line)),
                    ),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: _saving ? null : () => _apply(_s!),
                          child: const Text("Batalkan"),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: "Simpan jadwal",
                            icon: Icons.check,
                            loading: _saving,
                            onPressed: _saving ? null : _save,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey("none")),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.schedule,
    required this.busy,
    required this.onTempClose,
    required this.onReopen,
  });

  final OwnerSchedule schedule;
  final bool busy;
  final VoidCallback onTempClose;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final temp = schedule.isTempClosed;
    final open = schedule.isOpen && !temp;
    final fg = open ? c.ok : (temp ? c.warn : c.bad);
    final bg = open ? c.okSoft : (temp ? c.warnSoft : c.badSoft);
    final title = open
        ? "Buka sekarang"
        : temp
            ? "Tutup sementara"
            : "Tutup sekarang";
    final subtitle = temp
        ? "buka lagi ${DateFormat("EEE d MMM, HH:mm", "id_ID").format(schedule.tempClosedUntil!)}"
            "${schedule.tempClosedReason != null ? " · ${schedule.tempClosedReason}" : ""}"
        : open
            ? "pelanggan bisa booking & melihat bengkel buka"
            : "di luar jam buka atau sedang libur";

    return AnimatedContainer(
      duration: Motion.respect(context, Motion.dStd),
      curve: Motion.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PulseDot(color: fg, animate: open),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.h2.copyWith(color: fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTypography.caption.copyWith(color: c.ink)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: temp
                ? AppButton(
                    label: "Buka kembali sekarang",
                    icon: Icons.lock_open_outlined,
                    loading: busy,
                    onPressed: busy ? null : onReopen,
                  )
                : AppButton(
                    label: "Tutup sementara",
                    icon: Icons.pause_circle_outline,
                    variant: AppButtonVariant.secondary,
                    loading: busy,
                    onPressed: busy ? null : onTempClose,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.animate});
  final Color color;
  final bool animate;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _PulseDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.animate && !reduce) {
      if (!_c.isAnimating) unawaited(_c.repeat());
    } else {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 10 + 8 * _c.value,
              height: 10 + 8 * _c.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.35 * (1 - _c.value)),
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.slotsPerDay,
    required this.onToggle,
    required this.onOpenTap,
    required this.onCloseTap,
  });

  final DayHours day;
  final int slotsPerDay;
  final ValueChanged<bool> onToggle;
  final ValueChanged<DayHours> onOpenTap;
  final ValueChanged<DayHours> onCloseTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final invalid = !day.isValid;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  day.dayName,
                  style: AppTypography.label.copyWith(
                    color: day.isClosed ? c.ink2 : c.ink,
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.respect(context, Motion.micro),
                  child: day.isClosed
                      ? Align(
                          key: const ValueKey("closed"),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Tutup",
                            style: AppTypography.body.copyWith(color: c.ink2),
                          ),
                        )
                      : Row(
                          key: const ValueKey("open"),
                          children: [
                            _TimeChip(
                              label: day.open,
                              error: invalid,
                              semantic: "Jam buka ${day.dayName}",
                              onTap: () => onOpenTap(day),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                "–",
                                style:
                                    AppTypography.body.copyWith(color: c.ink2),
                              ),
                            ),
                            _TimeChip(
                              label: day.close,
                              error: invalid,
                              semantic: "Jam tutup ${day.dayName}",
                              onTap: () => onCloseTap(day),
                            ),
                          ],
                        ),
                ),
              ),
              Semantics(
                label: "${day.dayName} ${day.isClosed ? "tutup" : "buka"}",
                child: Switch(
                  value: !day.isClosed,
                  onChanged: onToggle,
                ),
              ),
            ],
          ),
          if (!day.isClosed)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 72, top: 2),
                child: Text(
                  invalid
                      ? "jam tutup harus setelah jam buka"
                      : "$slotsPerDay slot",
                  style: AppTypography.caption.copyWith(
                    color: invalid ? c.bad : c.ink2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.onTap,
    required this.semantic,
    this.error = false,
  });

  final String label;
  final VoidCallback onTap;
  final String semantic;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: "$semantic $label",
      child: Material(
        color: error ? c.badSoft : c.blueSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(
                    color: error ? c.bad : c.blueText,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.panel2,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: "Kurangi",
            icon: const Icon(Icons.remove),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 28,
            child: Text(
              "$value",
              textAlign: TextAlign.center,
              style: AppTypography.h2.copyWith(color: c.ink),
            ),
          ),
          IconButton(
            tooltip: "Tambah",
            icon: const Icon(Icons.add),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _ClosureTile extends StatelessWidget {
  const _ClosureTile({required this.closure, required this.onRemove});
  final Closure closure;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = closure.date;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: c.badSoft,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${d.day}",
              style: AppTypography.h2.copyWith(color: c.bad, height: 1),
            ),
            Text(
              DateFormat("MMM", "id_ID").format(d),
              style: AppTypography.caption.copyWith(color: c.bad, height: 1.1),
            ),
          ],
        ),
      ),
      title: Text(
        DateFormat("EEEE, d MMMM yyyy", "id_ID").format(d),
        style: AppTypography.label.copyWith(color: c.ink),
      ),
      subtitle: Text(
        [
          closure.reason ?? "Libur",
          if (closure.activeBookings > 0)
            "${closure.activeBookings} booking aktif perlu ditangani",
        ].join(" · "),
        style: AppTypography.caption.copyWith(
          color: closure.activeBookings > 0 ? c.warn : c.ink2,
        ),
      ),
      trailing: IconButton(
        tooltip: "Hapus libur",
        icon: Icon(Icons.delete_outline, color: c.ink2),
        onPressed: onRemove,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.colors.line),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.h2.copyWith(color: context.colors.ink),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.blueSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.blueText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.caption.copyWith(color: c.ink),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheet tutup sementara

/// Buka sheet tutup sementara lalu simpan. Mengembalikan jadwal terbaru
/// (null bila dibatalkan). Dipakai layar jadwal & sakelar di dasbor.
Future<OwnerSchedule?> showTempCloseFlow(
  BuildContext context, {
  required OwnerScheduleRepository repo,
  required List<DayHours> hours,
}) async {
  final r = await showModalBottomSheet<TempCloseResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => TempCloseSheet(hours: hours),
  );
  if (r == null) return null;
  return repo.setTempClosed(r.until, reason: r.reason);
}

class TempCloseResult {
  const TempCloseResult(this.until, this.reason);
  final DateTime until;
  final String? reason;
}

/// Waktu buka berikutnya menurut jadwal mingguan (untuk opsi "sampai buka besok").
DateTime nextOpening(List<DayHours> hours, DateTime from) {
  for (var i = 1; i <= 7; i++) {
    final day = DateTime(from.year, from.month, from.day + i);
    final wd = day.weekday % 7; // DateTime: Senin=1..Minggu=7 → 0=Minggu
    final h = hours.where((e) => e.weekday == wd).firstOrNull;
    if (h != null && !h.isClosed && h.isValid) {
      final m = DayHours.minutes(h.open);
      return day.add(Duration(minutes: m));
    }
  }
  return DateTime(from.year, from.month, from.day + 1, 8);
}

class TempCloseSheet extends StatefulWidget {
  const TempCloseSheet({super.key, required this.hours});
  final List<DayHours> hours;

  @override
  State<TempCloseSheet> createState() => TempCloseSheetState();
}

class TempCloseSheetState extends State<TempCloseSheet> {
  final _reason = TextEditingController();
  int _option = 1;
  DateTime? _custom;

  static const _reasons = [
    "Hujan deras",
    "Mekanik sakit",
    "Istirahat",
    "Stok habis"
  ];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  DateTime? get _until {
    final now = DateTime.now();
    return switch (_option) {
      0 => now.add(const Duration(hours: 1)),
      1 => now.add(const Duration(hours: 3)),
      2 => nextOpening(widget.hours, now),
      _ => _custom,
    };
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
      helpText: "Buka kembali tanggal",
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: "Buka kembali jam",
    );
    if (t == null) return;
    final v = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    setState(() {
      _custom = v.isAfter(now) ? v : null;
      _option = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fmt = DateFormat("EEE d MMM, HH:mm", "id_ID");
    final options = [
      ("1 jam", fmt.format(DateTime.now().add(const Duration(hours: 1)))),
      ("3 jam", fmt.format(DateTime.now().add(const Duration(hours: 3)))),
      (
        "Sampai jam buka berikutnya",
        fmt.format(nextOpening(widget.hours, DateTime.now()))
      ),
      (
        "Pilih tanggal & jam",
        _custom == null ? "maks. 30 hari" : fmt.format(_custom!)
      ),
    ];
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text("Tutup sementara",
                  style: AppTypography.h1.copyWith(color: c.ink)),
              const SizedBox(height: 4),
              Text(
                "slot booking ditutup & bengkel tampil \"Tutup\" sampai waktu yang dipilih. booking yang sudah ada tetap berlaku.",
                style: AppTypography.caption.copyWith(color: c.ink2),
              ),
              const SizedBox(height: 16),
              for (final (i, o) in options.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: _option == i ? c.blueSoft : c.panel2,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: i == 3
                          ? _pickCustom
                          : () => setState(() => _option = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              _option == i
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: _option == i ? c.blue : c.ink2,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(o.$1,
                                      style: AppTypography.label
                                          .copyWith(color: c.ink)),
                                  Text(
                                    "buka lagi ${o.$2}",
                                    style: AppTypography.caption
                                        .copyWith(color: c.ink2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in _reasons)
                    ActionChip(
                      label: Text(r),
                      onPressed: () => setState(() => _reason.text = r),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reason,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: "Alasan (tampil ke pelanggan)",
                ),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: "Tutup bengkel",
                icon: Icons.pause_circle_outline,
                onPressed: _until == null
                    ? null
                    : () => Navigator.pop(
                          context,
                          TempCloseResult(
                            _until!,
                            _reason.text.trim().isEmpty
                                ? null
                                : _reason.text.trim(),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
