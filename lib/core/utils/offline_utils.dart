import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Muestra un SnackBar con un mensaje adaptado a la conectividad.
///
/// Si [isOnline] es false, muestra un mensaje sugiriendo que el dato
/// se guardará cuando vuelva la conexión. Si es true, muestra el
/// error original.
void showOfflineAwareError(
  BuildContext context, {
  required bool isOnline,
  required String onlineMessage,
  String? offlineMessage,
}) {
  final message = isOnline
      ? onlineMessage
      : (offlineMessage ?? 'Sin conexión — se sincronizará cuando vuelva internet');

  final backgroundColor = isOnline ? AppColors.error : AppColors.alertYellow;
  final textColor = isOnline ? Colors.white : AppColors.textPrimary;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isOnline ? Icons.error_outline : Icons.wifi_off_rounded,
            color: textColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Muestra un SnackBar de éxito de guardado offline.
void showOfflineSaveSuccess(BuildContext context, {required bool isOnline}) {
  final message = isOnline
      ? 'Guardado correctamente'
      : 'Guardado localmente — se sincronizará cuando vuelva internet';

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isOnline ? Icons.check_circle_outline : Icons.cloud_upload_outlined,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.alertGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ),
  );
}
