/// يكمل حقل البريد الإلكتروني تلقائيًا إذا كتب المستخدم الجزء الأول فقط
/// (بدون @)، بإضافة "@gmail.com" افتراضيًا.
///
/// لو الإدخال يحتوي بالفعل على @ (بريد إلكتروني كامل من أي مزوّد)، يُرجَع
/// كما هو تمامًا بدون أي تعديل.
///
/// أمثلة:
///   normalizeEmailInput('alas')            -> 'alas@gmail.com'
///   normalizeEmailInput('alas@gmail.com')  -> 'alas@gmail.com'
///   normalizeEmailInput('alas@yahoo.com')  -> 'alas@yahoo.com'
String normalizeEmailInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.contains('@')) {
    return trimmed;
  }
  return '$trimmed@gmail.com';
}
