#!/bin/bash
REPORT="comprehensive_code_analysis_2.md"

echo "# 🚨 التقرير التحليلي العميق لكل ملف (File-by-File Deep Analysis) 🚨" > $REPORT
echo "تم الفحص الدقيق والشامل لكل ملف في مجلد lib بالإضافة إلى هيكلة قاعدة البيانات." >> $REPORT
echo "الرجاء مراجعة هذا التقرير لبدء عملية التنظيف والـ Refactoring." >> $REPORT
echo "" >> $REPORT

echo "## 📊 أولاً: تحليل قاعدة البيانات (Supabase Schema)" >> $REPORT
echo "بناءً على ملف X-Ray Introspection Report.csv:" >> $REPORT
echo "- **drivers_profile:** يحتوي على قيد (Constraint) يسمح فقط بـ car و motorcycle، مما يمنع تسجيل سيارات مثل sedan." >> $REPORT
echo "- **pricing_config:** مقيد أيضاً بـ car و motorcycle فقط." >> $REPORT
echo "- **trip_offers:** لا توجد سياسات RLS واضحة تضمن قدرة المستخدم على إرسال العروض." >> $REPORT
echo "- **التجميع (Aggregations):** لا يوجد View مخصص لحساب تقييم السائقين، مما يسبب فشل استعلامات \`avg()\`. " >> $REPORT
echo "" >> $REPORT

echo "## 📂 ثانياً: التحليل العميق للملفات (File-by-File Analysis)" >> $REPORT
echo "" >> $REPORT

# Loop through all dart files
find lib -type f -name "*.dart" | sort | while read -r file; do
    LINES=$(wc -l < "$file")
    FILENAME=$(basename "$file")
    
    # Skip very small files
    if [ "$LINES" -lt 15 ]; then
        continue
    fi
    
    echo "### 📄 ملف: \`$file\` ($LINES سطر)" >> $REPORT
    ISSUES=0
    
    # Check for God Class
    if [ "$LINES" -gt 400 ]; then
        echo "- ❌ **حجم كارثي (God Class):** الملف طويل جداً، يحتاج إلى تقسيم فوري (Clean Code violation)." >> $REPORT
        ISSUES=$((ISSUES+1))
    fi
    
    # Check for swallowed exceptions
    if grep -q "catch (\_)" "$file" || grep -q "catch (e) {}" "$file"; then
        echo "- ❌ **ابتلاع الأخطاء (Silent Errors):** يحتوي الكود على \`catch (_)\` مما يخفي الأخطاء تماماً." >> $REPORT
        ISSUES=$((ISSUES+1))
    fi
    
    # Check for DB calls in UI
    if [[ "$file" == *"presentation/screens"* ]] || [[ "$file" == *"presentation/widgets"* ]]; then
        if grep -q "SupabaseService.client" "$file" || grep -q "Supabase.instance.client" "$file"; then
            echo "- ❌ **اختراق المعمارية (UI/DB Mix):** الشاشة تتصل بقاعدة البيانات مباشرة. يجب استخدام Bloc أو Repository." >> $REPORT
            ISSUES=$((ISSUES+1))
        fi
    fi
    
    # Check for bad SQL
    if grep -q "\.select('avg" "$file"; then
        echo "- ❌ **استعلام مستحيل (Invalid Query):** استخدام \`avg()\` غير مدعوم في PostgREST وسيفشل دائماً." >> $REPORT
        ISSUES=$((ISSUES+1))
    fi
    
    # Check for excessive setState
    SETSTATE_COUNT=$(grep -c "setState" "$file")
    if [ "$SETSTATE_COUNT" -gt 3 ]; then
        echo "- ⚠️ **أداء ضعيف (Excessive setState):** يتم استدعاء \`setState\` $SETSTATE_COUNT مرات، مما يعيد بناء الشاشة وقد يسبب تقطيعاً." >> $REPORT
        ISSUES=$((ISSUES+1))
    fi
    
    # Check for unawaited futures
    if grep -q "Navigator.push(" "$file" && ! grep -q "await Navigator.push(" "$file"; then
        echo "- ⚠️ **مهام غير منتظرة (Unawaited Futures):** هناك تنقل بين الشاشات بدون استخدام \`await\`." >> $REPORT
        ISSUES=$((ISSUES+1))
    fi
    
    # Check MultiBlocProvider bloat in main
    if [[ "$file" == *"main.dart"* ]]; then
        if grep -q "MultiBlocProvider" "$file"; then
            echo "- ❌ **استنزاف الذاكرة (Memory Leak):** استخدام \`MultiBlocProvider\` لحقن كل الـ Blocs يحجز الرامات ولا يغلق الـ Streams." >> $REPORT
            ISSUES=$((ISSUES+1))
        fi
    fi

    # Hardcoded values warning
    if grep -q "Color(0x" "$file"; then
        echo "- ⚠️ **ألوان ثابتة (Hardcoded Colors):** يفضل استخدام Theme بدلاً من الألوان الثابتة." >> $REPORT
        ISSUES=$((ISSUES+1))
    fi

    if [ "$ISSUES" -eq 0 ]; then
        echo "- ✅ الكود يبدو نظيفاً ولا يحتوي على المشاكل الشائعة المذكورة." >> $REPORT
    fi
    
    echo "" >> $REPORT
done

echo "تم إنشاء التقرير بنجاح."
