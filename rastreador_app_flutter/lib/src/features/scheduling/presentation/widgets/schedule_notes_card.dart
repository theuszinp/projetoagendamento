import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_formatter.dart';
import '../../domain/schedule_note.dart';

class ScheduleNotesCard extends StatefulWidget {
  const ScheduleNotesCard({
    super.key,
    required this.notes,
    this.onSubmit,
    this.title = 'Observações',
    this.inputLabel = 'Adicionar observação',
    this.submitLabel = 'Salvar observação',
  });

  final List<ScheduleNote> notes;
  final Future<void> Function(String content)? onSubmit;
  final String title;
  final String inputLabel;
  final String submitLabel;

  @override
  State<ScheduleNotesCard> createState() => _ScheduleNotesCardState();
}

class _ScheduleNotesCardState extends State<ScheduleNotesCard> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final onSubmit = widget.onSubmit;
    if (onSubmit == null) {
      return;
    }

    final content = _controller.text.trim();
    if (content.length < 3) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await onSubmit(content);
      _controller.clear();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (widget.notes.isEmpty)
              const Text('Nenhuma observação registrada até o momento.')
            else
              ...widget.notes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                note.typeLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                note.authorName?.isNotEmpty == true
                                    ? note.authorName!
                                    : 'Sistema',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(DateTimeFormatter.shortDateTime(note.createdAt)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(note.content),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.onSubmit != null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLines: 3,
                decoration: InputDecoration(labelText: widget.inputLabel),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(widget.submitLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
