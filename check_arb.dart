import 'dart:convert';
import 'dart:io';

void main() {
  var arFile = File('lib/core/localization/l10n/app_ar.arb').readAsStringSync();
  var enFile = File('lib/core/localization/l10n/app_en.arb').readAsStringSync();
  
  var arJson = jsonDecode(arFile) as Map<String, dynamic>;
  var enJson = jsonDecode(enFile) as Map<String, dynamic>;
  
  var arKeys = arJson.keys.where((k) => !k.startsWith('@')).toSet();
  var enKeys = enJson.keys.where((k) => !k.startsWith('@')).toSet();
  
  var missingInEn = arKeys.difference(enKeys);
  var missingInAr = enKeys.difference(arKeys);
  
  print('Missing in English: ${missingInEn.length}');
  for (var k in missingInEn) print(' - $k');
  
  print('\nMissing in Arabic: ${missingInAr.length}');
  for (var k in missingInAr) print(' - $k');
}
