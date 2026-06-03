import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/api/api_client.dart';

/// Patient messaging — view clinician messages, respond with pre-configured options only.
class MessagingScreen extends ConsumerStatefulWidget {
  const MessagingScreen({super.key});
  @override
  ConsumerState<MessagingScreen> createState() => _MessagingState();
}

final _messagesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  try {
    final data = await pApi.get('/patient-app/messages/inbox');
    final list = data is List
        ? data
        : ((data as Map)['messages'] ?? data['data'] ?? []) as List;
    return list.map((j) => Map<String, dynamic>.from(j as Map)).toList();
  } catch (_) {
    return [];
  }
});

class _MessagingState extends ConsumerState<MessagingScreen> {
  void _showComposeSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ComposeSheet(onSent: () => ref.invalidate(_messagesProvider)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(_messagesProvider);

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: () => ref.invalidate(_messagesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        icon: const Icon(Icons.send, color: Colors.white, size: 18),
        label: const Text(
          'New Message',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        onPressed: () => _showComposeSheet(context, ref),
      ),
      body: messagesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (error, stackTrace) =>
            const Center(child: Text('Failed to load messages')),
        data: (messages) {
          if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.message_outlined,
                    size: 48,
                    color: kTextLight.withAlpha(100),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No messages',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kText,
                    ),
                  ),
                  Text(
                    'Messages from your care team will appear here',
                    style: TextStyle(fontSize: 12, color: kTextLight),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: kPrimary,
            onRefresh: () async => ref.invalidate(_messagesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: messages.length,
              itemBuilder: (_, i) => _MessageCard(
                message: messages[i],
                onRespond: () => ref.invalidate(_messagesProvider),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Pre-configured response options — no free text
const _quickReplies = [
  _Reply('I will attend appointment', Icons.check_circle_outline, kSuccess),
  _Reply('I cannot attend appointment', Icons.cancel_outlined, kError),
  _Reply('I need to change appointment', Icons.event_repeat, kWarning),
  _Reply('I need new prescriptions', Icons.medication_outlined, kMeds),
];

class _Reply {
  final String text;
  final IconData icon;
  final Color color;
  const _Reply(this.text, this.icon, this.color);
}

class _MessageCard extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onRespond;
  const _MessageCard({required this.message, required this.onRespond});

  @override
  Widget build(BuildContext context) {
    final subject = message['subject'] ?? '';
    final body = (message['body'] ?? '').toString();
    final sender = message['senderName'] ?? 'Care Team';
    final isRead = message['isRead'] == true;
    final isUrgent = message['isUrgent'] == true;
    final dt = DateTime.tryParse((message['createdAt'] ?? '').toString());
    final timeStr = dt != null
        ? '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isUrgent ? kError.withAlpha(60) : kDivider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: kPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: kError.withAlpha(20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'URGENT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: kError,
                      ),
                    ),
                  ),
                Icon(Icons.local_hospital, size: 14, color: kInfo),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    sender.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isRead ? FontWeight.w400 : FontWeight.w700,
                      color: kText,
                    ),
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 10, color: kTextLight),
                ),
              ],
            ),

            // Subject + body
            if (subject.toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  subject.toString(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                    color: kText,
                  ),
                ),
              ),
            if (body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    color: kText.withAlpha(180),
                    height: 1.4,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Pre-configured reply options
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reply:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kTextLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ..._quickReplies.map(
                    (r) => _ReplyButton(
                      reply: r,
                      messageId: message['id'],
                      threadId: message['threadId'],
                      onSent: onRespond,
                    ),
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

class _ReplyButton extends StatefulWidget {
  final _Reply reply;
  final dynamic messageId;
  final dynamic threadId;
  final VoidCallback onSent;
  const _ReplyButton({
    required this.reply,
    required this.messageId,
    required this.threadId,
    required this.onSent,
  });

  @override
  State<_ReplyButton> createState() => _ReplyButtonState();
}

class _ReplyButtonState extends State<_ReplyButton> {
  bool _sending = false;
  bool _sent = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final threadId = widget.threadId?.toString();
      if (threadId != null && threadId.isNotEmpty) {
        await pApi.post(
          '/patient-app/messages/threads/$threadId/messages',
          data: {'body': widget.reply.text},
        );
      } else {
        await pApi.post(
          '/patient-app/messages',
          data: {'body': widget.reply.text, 'subject': 'Patient Reply'},
        );
      }
      if (widget.messageId != null) {
        try {
          await pApi.patch(
            '/patient-app/messages/${widget.messageId}/read',
            data: {},
          );
        } catch (_) {}
      }
      setState(() {
        _sending = false;
        _sent = true;
      });
      widget.onSent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent: "${widget.reply.text}"'),
            backgroundColor: kSuccess,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send'), backgroundColor: kError),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: _sent ? widget.reply.color.withAlpha(10) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: (_sending || _sent) ? null : _send,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _sent ? widget.reply.color.withAlpha(40) : kDivider,
              ),
            ),
            child: Row(
              children: [
                if (_sending)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: widget.reply.color,
                      strokeWidth: 2,
                    ),
                  )
                else if (_sent)
                  Icon(Icons.check_circle, size: 16, color: widget.reply.color)
                else
                  Icon(widget.reply.icon, size: 16, color: widget.reply.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.reply.text,
                    style: TextStyle(
                      fontSize: 12,
                      color: _sent ? widget.reply.color : kText,
                      fontWeight: _sent ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (_sent)
                  Text(
                    'Sent',
                    style: TextStyle(fontSize: 10, color: widget.reply.color),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Compose Sheet — pre-configured messages only ──

class _ComposeSheet extends StatefulWidget {
  final VoidCallback onSent;
  const _ComposeSheet({required this.onSent});
  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  bool _sending = false;
  String? _sentMessage;

  static const _messages = [
    _Reply('I will attend appointment', Icons.check_circle_outline, kSuccess),
    _Reply('I cannot attend appointment', Icons.cancel_outlined, kError),
    _Reply('I need to change appointment', Icons.event_repeat, kWarning),
    _Reply('I need new prescriptions', Icons.medication_outlined, kMeds),
  ];

  Future<void> _send(String text) async {
    setState(() => _sending = true);
    try {
      await pApi.post(
        '/patient-app/messages',
        data: {'body': text, 'subject': 'Patient Message'},
      );
      setState(() {
        _sending = false;
        _sentMessage = text;
      });
      widget.onSent();
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send'),
            backgroundColor: kError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Send Message',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: kText,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            if (_sentMessage != null) ...[
              const SizedBox(height: 16),
              Icon(Icons.check_circle, color: kSuccess, size: 48),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Message sent!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kSuccess,
                  ),
                ),
              ),
              Center(
                child: Text(
                  '"$_sentMessage"',
                  style: TextStyle(fontSize: 12, color: kTextLight),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ] else ...[
              const Text(
                'Select a message to send to your care team:',
                style: TextStyle(fontSize: 12, color: kTextLight),
              ),
              const SizedBox(height: 12),
              ..._messages.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _sending ? null : () => _send(m.text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: m.color.withAlpha(40)),
                        ),
                        child: Row(
                          children: [
                            Icon(m.icon, color: m.color, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                m.text,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: kText,
                                ),
                              ),
                            ),
                            Icon(Icons.send, size: 16, color: m.color),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
