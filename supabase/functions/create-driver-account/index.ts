// @ts-nocheck
// Deno/Supabase Edge Function — not compiled by the local TS language server.
//
// الهدف: خلي إنشاء حساب السائق عملية واحدة ذريّة (atomic):
//   1) إنشاء حساب auth.users (Admin API)
//   2) حفظ بيانات السائق في drivers_profile (RPC)
// لو الخطوة (2) فشلت، بيتم حذف حساب الـ auth اللي تعمل في الخطوة (1)
// فورًا (auth.admin.deleteUser)، فيبقى الإيميل/الرقم متاحين فورًا للمحاولة التانية.
// هذا هو الـ rollback الحقيقي اللي ما كانش موجودة قبل كده.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ success: false, error: 'method_not_allowed' }, 405);
  }

  let payload: any;
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ success: false, error: 'invalid_json_body' }, 400);
  }

  const {
    name,
    email,
    phone,
    password,
    national_id,
    license_number,
    vehicle_category,
    vehicle_brand,
    vehicle_model,
    vehicle_year,
    vehicle_color,
    vehicle_plate,
    vehicle_seats,
    national_id_image_url,
    license_image_url,
    criminal_record_image_url,
    vehicle_image_url,
  } = payload ?? {};

  // ─── تحقق أساسي من المدخلات (طبقة دفاع قبل الوصول لـ admin.createUser) ───
  const requiredFields: Record<string, unknown> = {
    name, email, phone, password,
    national_id, license_number, vehicle_category,
    vehicle_brand, vehicle_model, vehicle_year, vehicle_color, vehicle_plate,
    national_id_image_url, license_image_url, criminal_record_image_url, vehicle_image_url,
  };
  const missing = Object.entries(requiredFields)
    .filter(([, v]) => v === null || v === undefined || v === '')
    .map(([k]) => k);

  if (missing.length > 0) {
    return jsonResponse({ success: false, error: `missing_fields:${missing.join(',')}` }, 400);
  }

  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // ─── الخطوة 1: إنشاء حساب auth.users ───
  const { data: createData, error: createError } = await supabaseAdmin.auth.admin.createUser({
    email,
    password,
    phone,
    email_confirm: true,
    user_metadata: { name, phone, role: 'driver' },
  });

  if (createError || !createData?.user) {
    return jsonResponse(
      { success: false, error: createError?.message ?? 'auth_create_user_failed' },
      400,
    );
  }

  const newUserId = createData.user.id;

  // ─── الخطوة 2: حفظ بيانات السائق عبر RPC ───
  const { data: rpcData, error: rpcError } = await supabaseAdmin.rpc('create_driver_account', {
    p_user_id: newUserId,
    p_name: name,
    p_email: email,
    p_phone: phone,
    p_national_id: national_id,
    p_license_number: license_number,
    p_vehicle_category: vehicle_category,
    p_vehicle_brand: vehicle_brand,
    p_vehicle_model: vehicle_model,
    p_vehicle_year: vehicle_year,
    p_vehicle_color: vehicle_color,
    p_vehicle_plate: vehicle_plate,
    p_national_id_image: national_id_image_url,
    p_license_image: license_image_url,
    p_criminal_record_image: criminal_record_image_url,
    p_vehicle_image: vehicle_image_url,
    p_vehicle_seats: vehicle_seats ?? null,
  });

  const rpcFailed = !!rpcError || rpcData?.success !== true;

  if (rpcFailed) {
    // ─── ROLLBACK حقيقي: حذف حساب الـ auth اللي عملناه لسة ───
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(newUserId);

    if (deleteError) {
      // حالة نادرة جدًا: الحذف نفسه فشل. نسجّل الخطأ بوضوح عشان الاكتشاف اليدوي.
      console.error(
        `CRITICAL: orphaned auth user ${newUserId} — rpc failed AND rollback delete failed: ${deleteError.message}`,
      );
    }

    const errorMessage =
      rpcError?.message ?? rpcData?.error ?? 'driver_profile_creation_failed';

    return jsonResponse({ success: false, error: errorMessage }, 400);
  }

  // ─── نجاح كامل: إرجاع بيانات المستخدم المحفوظة فعلاً في public.users ───
  const { data: userData, error: userFetchError } = await supabaseAdmin
    .from('users')
    .select(
      'id,name,phone,email,avatar_url,role,rating,total_trips,language,is_active,is_admin,is_blocked,blocked_reason,blocked_at,created_at,updated_at',
    )
    .eq('id', newUserId)
    .single();

  if (userFetchError || !userData) {
    // الحساب اتخلق صحيح فعليًا، مشكلة قراءة بس — ما يستحقش rollback.
    return jsonResponse({ success: false, error: 'account_created_but_fetch_failed' }, 500);
  }

  return jsonResponse({ success: true, user: userData }, 200);
});
