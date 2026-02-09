class TranslationService {
  static const Map<String, Map<String, String>> localizedValues = {
    'en': {
      'app_title': 'DNS Master Pro 📱',
      'server_list_title': 'DNS Server List',
      'download': 'Download',
      'upload': 'Upload',
      'status_title': 'Current Status:',
      'status_connected': 'Connected',
      'status_disconnected': 'Not Connected',
      'status_processing': 'Processing...',
      'btn_disconnect': 'Disconnect',
    },
    'fa': {
      'app_title': 'دی‌ان‌اس مستر پرو 📱',
      'server_list_title': 'لیست سرورهای دی‌ان‌اس',
      'download': 'دانلود',
      'upload': 'آپلود',
      'status_title': 'وضعیت فعلی:',
      'status_connected': 'متصل شد',
      'status_disconnected': 'متصل نیست',
      'status_processing': 'در حال پردازش...',
      'btn_disconnect': 'قطع اتصال',
    },
  };

  static String t(String lang, String key) {
    return localizedValues[lang]?[key] ?? key;
  }
}