// Detail tiket bantuan + percakapan dengan tim (PRD v1.3 Bagian 7).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/state_views.dart';
import '../data/support_models.dart';
import '../data/support_repository.dart';
import 'help_center_screen.dart';
import 'support_tickets_screen.dart';

class SupportTicketDetailScreen extends ConsumerStatefulWidget {
  const SupportTicketDetailScreen({super.key, required this.ticketId});
  final String ticketId;

  @override
  ConsumerState<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState
    extends ConsumerState<SupportTicketDetailScreen> {
  SupportTicket? _ticket;
  List<SupportMessage> _messages = const [];
  List<String> _photoUrls = const [];
  bool _loading = true;
  String? _error;
  bool _sending = false;
  final _reply = TextEditingController();
  RealtimeChannel? _channel;
  late final SupportRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(supportRepositoryProvider);
    unawaited(_load());
    try {
      _channel = _repo.subscribeToTicket(
        widget.ticketId,
        onChange: () => unawaited(_load()),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_channel != null) unawaited(_repo.unsubscribe(_channel!));
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await _repo.getTicket(widget.ticketId);
      final m = await _repo.getMessages(widget.ticketId);
      final urls = <String>[];
      for (final p in t.photos) {
        try {
          urls.add(p.startsWith('http') ? p : await _repo.signedPhotoUrl(p));
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _ticket = t;
        _messages = m;
        _photoUrls = urls;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = SupportRepository.friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _repo.reply(widget.ticketId, body);
      _reply.clear();
      await _load();
      ref.invalidate(myTicketsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SupportRepository.friendlyError(e)),
            backgroundColor: context.colors.bad,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = _ticket;

    Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonList(itemCount: 3),
      );
    } else if (t == null) {
      body = ErrorState(
        message: _error ?? 'laporan tidak ditemukan',
        onRetry: () {
          setState(() => _loading = true);
          unawaited(_load());
        },
      );
    } else {
      final me = SupabaseService.currentUser?.id;
      body = Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TicketHeader(ticket: t, photoUrls: _photoUrls),
                if (t.state == SupportState.SELESAI &&
                    (t.decision ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DecisionCard(ticket: t),
                ],
                if (t.state == SupportState.MENUNGGU_INFO) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.warnSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'tim kami butuh info tambahan. balas di bawah ini.',
                      style: AppTypography.body.copyWith(color: c.warnText),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_messages.isEmpty)
                  Text(
                    'belum ada balasan. tim kami membalas paling lambat 1×24 jam kerja.',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(color: c.ink2),
                  ),
                for (final m in _messages)
                  _Bubble(message: m, mine: !m.fromAdmin && m.senderId == me),
              ],
            ),
          ),
          if (t.state.canReply)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: c.panel,
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reply,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: SupportLimits.maxDescription,
                      decoration: const InputDecoration(
                        hintText: 'tulis balasan',
                        counterText: '',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kirim',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.send, color: c.blue),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: c.stage,
      appBar: AppBar(
        title: Text(t?.code ?? 'Laporan'),
        backgroundColor: c.panel,
        elevation: 0,
      ),
      body: SafeArea(child: body),
    );
  }
}

class _TicketHeader extends StatelessWidget {
  const _TicketHeader({required this.ticket, required this.photoUrls});
  final SupportTicket ticket;
  final List<String> photoUrls;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = ticket;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.panel,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.category.label,
                  style: AppTypography.h2.copyWith(color: c.ink),
                ),
              ),
              SupportStateBadge(state: t.state),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              t.code,
              if (t.relatedLabel != null) t.relatedLabel!,
              Formatters.dateTimeLocal(t.createdAt),
            ].join(' · '),
            style: AppTypography.caption.copyWith(color: c.ink2),
          ),
          const SizedBox(height: 10),
          Text(t.description, style: AppTypography.body.copyWith(color: c.ink)),
          if (photoUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final u in photoUrls)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      u,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 72,
                        height: 72,
                        color: c.panel2,
                        child: Icon(Icons.broken_image_outlined, color: c.ink2),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.ticket});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.okSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keputusan: ${ticket.decision}',
            style: AppTypography.bodyStrong.copyWith(color: c.okText),
          ),
          if ((ticket.decisionReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              ticket.decisionReason!,
              style: AppTypography.body.copyWith(color: c.ink),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final SupportMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: mine ? c.blue : c.panel,
          border: mine ? null : Border.all(color: c.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.fromAdmin)
              Text(
                'Tim BengkelKu',
                style: AppTypography.caption.copyWith(color: c.blueText),
              ),
            Text(
              message.body,
              style: AppTypography.body
                  .copyWith(color: mine ? Colors.white : c.ink),
            ),
            const SizedBox(height: 2),
            Text(
              Formatters.timeOnly(message.createdAt),
              style: AppTypography.caption.copyWith(
                color: mine ? Colors.white70 : c.ink2,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
