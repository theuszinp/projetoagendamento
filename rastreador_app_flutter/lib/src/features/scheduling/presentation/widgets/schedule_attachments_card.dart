import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../domain/schedule_attachment.dart';

class ScheduleAttachmentsCard extends StatelessWidget {
  const ScheduleAttachmentsCard({
    super.key,
    required this.attachments,
    this.onUploadFromCamera,
    this.onUploadFromGallery,
    this.isUploading = false,
    this.showUploadActions = false,
    this.uploadEnabled = false,
  });

  final List<ScheduleAttachment> attachments;
  final Future<void> Function()? onUploadFromCamera;
  final Future<void> Function()? onUploadFromGallery;
  final bool isUploading;
  final bool showUploadActions;
  final bool uploadEnabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Fotos da instalacao',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (showUploadActions)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${attachments.length} anexos',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.brandDark,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              showUploadActions
                  ? 'Anexe evidencias visuais para o admin e o vendedor acompanharem a execucao.'
                  : 'Evidencias visuais registradas durante a instalacao.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
            if (showUploadActions) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        isUploading || !uploadEnabled || onUploadFromCamera == null
                            ? null
                            : onUploadFromCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Abrir camera'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        isUploading || !uploadEnabled || onUploadFromGallery == null
                            ? null
                            : onUploadFromGallery,
                    icon:
                        isUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.photo_library_outlined),
                    label: Text(
                      isUploading ? 'Enviando...' : 'Escolher da galeria',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (attachments.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.brandLight.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  showUploadActions
                      ? uploadEnabled
                          ? 'Nenhuma foto anexada ainda. Use a camera do celular ou escolha uma imagem da galeria.'
                          : 'Inicie o atendimento para habilitar a camera do celular e a galeria neste servico.'
                      : 'Ainda nao ha fotos registradas para este servico.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children:
                    attachments
                        .map(
                          (attachment) => _AttachmentTile(attachment: attachment),
                        )
                        .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment});

  final ScheduleAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showPreview(context),
      child: SizedBox(
        width: 146,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 110,
                width: 146,
                color: AppColors.surface,
                child: Image.network(
                  attachment.url,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        color: AppColors.surface,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textMuted,
                        ),
                      ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              attachment.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              DateTimeFormatter.shortDateTime(attachment.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
            if ((attachment.uploadedByName ?? '').isNotEmpty)
              Text(
                attachment.uploadedByName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPreview(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder:
          (context) => Dialog(
                insetPadding: const EdgeInsets.all(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              attachment.fileName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: InteractiveViewer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              attachment.url,
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (context, error, stackTrace) => Container(
                                    height: 240,
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    color: AppColors.surface,
                                    child: const Text(
                                      'Nao foi possivel carregar a imagem.',
                                    ),
                                  ),
                            ),
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
