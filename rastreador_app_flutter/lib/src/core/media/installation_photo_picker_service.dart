import 'dart:convert';

import 'package:image_picker/image_picker.dart';

class InstallationPhotoPayload {
  const InstallationPhotoPayload({
    required this.fileName,
    required this.contentType,
    required this.base64Content,
  });

  final String fileName;
  final String contentType;
  final String base64Content;
}

class InstallationPhotoPickerService {
  InstallationPhotoPickerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<InstallationPhotoPayload?> pick(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1800,
    );

    if (image == null) {
      return null;
    }

    final bytes = await image.readAsBytes();
    final fileName = image.name.isEmpty ? 'foto-instalacao.jpg' : image.name;

    return InstallationPhotoPayload(
      fileName: fileName,
      contentType: _resolveContentType(fileName),
      base64Content: base64Encode(bytes),
    );
  }

  String _resolveContentType(String fileName) {
    final lowerName = fileName.toLowerCase();

    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }

    if (lowerName.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lowerName.endsWith('.heic') || lowerName.endsWith('.heif')) {
      return 'image/heic';
    }

    return 'image/jpeg';
  }
}
