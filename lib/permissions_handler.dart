import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class AppUtils {
  /// Requests photo library permissions.
  static Future<bool> requestPermission() async {
    if (kIsWeb) return true; // Permissions not needed on web

    Map<Permission, PermissionStatus> statuses = await [
      Permission.photos,
      Permission.storage, // For older Android versions
    ].request();

    if (statuses[Permission.photos] == PermissionStatus.granted ||
        statuses[Permission.storage] == PermissionStatus.granted) {
      return true;
    }

    print("Permission not granted.");
    return false;
  }

  /// Picks an image from the gallery.
  static Future<File?> pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  /// Saves an image (as bytes) to the gallery under /Pictures/PhotoEditor/.
  static Future<bool> saveImageToGallery(Uint8List imageBytes) async {
    try {
      // Get external storage directory
      final directory = await getExternalStorageDirectory();
      final picturesDir = Directory(
          "${directory!.parent.parent.parent.parent.path}/Pictures/PhotoEditor");

      // Ensure folder exists
      if (!await picturesDir.exists()) {
        await picturesDir.create(recursive: true);
      }

      // Create a unique filename
      final filePath =
          '${picturesDir.path}/edited_image_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = await File(filePath).writeAsBytes(imageBytes);

      // Save the file to gallery
      final result = await GallerySaver.saveImage(file.path);

      // Trigger Android's media scanner to refresh gallery
      if (Platform.isAndroid) {
        final path = file.path;
        await Process.run('am', [
          'broadcast',
          '-a',
          'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
          '-d',
          'file://$path'
        ]);
      }

      print("✅ Image saved successfully to: $filePath");
      return result == true;
    } catch (e) {
      print("❌ Error saving image: $e");
      return false;
    }
  }
}
