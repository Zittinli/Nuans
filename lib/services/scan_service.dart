import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';

class ScanService {
  final _picker = ImagePicker();

  Future<List<String>> scanPages() async {
    try {
      final scanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormats: const {DocumentFormat.jpeg},
          mode: ScannerMode.full,
          isGalleryImport: true,
          pageLimit: 8,
        ),
      );
      final result = await scanner.scanDocument();
      await scanner.close();
      final images = result.images ?? const <String>[];
      if (images.isNotEmpty) return images;
    } catch (_) {}

    final fromCamera = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
    );
    if (fromCamera != null) return [fromCamera.path];

    final fromGallery = await _picker.pickMultiImage(imageQuality: 88);
    return fromGallery.map((file) => file.path).toList();
  }
}
