import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { S3Client, PutObjectCommand, DeleteObjectCommand } from "npm:@aws-sdk/client-s3@3.370.0"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const formData = await req.formData();
    const action = formData.get('action') as string;

    const s3Client = new S3Client({
      region: "auto",
      endpoint: `https://${Deno.env.get("R2_ACCOUNT_ID")}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: Deno.env.get("R2_ACCESS_KEY_ID") ?? "",
        secretAccessKey: Deno.env.get("R2_SECRET_KEY") ?? "",
      },
    });

    const bucketName = Deno.env.get("R2_BUCKET_NAME") ?? "";
    const publicUrl = Deno.env.get("R2_PUBLIC_URL") ?? "";

    if (action === 'delete') {
      const url = formData.get('url') as string;
      const publicUrlPrefix = `${publicUrl}/`;
      if (url && url.startsWith(publicUrlPrefix)) {
        const objectName = url.substring(publicUrlPrefix.length);
        await s3Client.send(new DeleteObjectCommand({
          Bucket: bucketName,
          Key: objectName,
        }));
      }
      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const file = formData.get('file') as File;
    const path = formData.get('path') as string;

    if (!file || !path) {
      throw new Error("Missing file or path");
    }

    const timestamp = Date.now();
    const originalName = file.name || 'file';
    const fileName = `${timestamp}_${originalName.split('/').pop()}`;
    const fullPath = `${path}/${fileName}`;

    const arrayBuffer = await file.arrayBuffer();
    const uint8Array = new Uint8Array(arrayBuffer);

    await s3Client.send(new PutObjectCommand({
      Bucket: bucketName,
      Key: fullPath,
      Body: uint8Array,
      ContentType: file.type || 'application/octet-stream',
    }));

    const fileUrl = `${publicUrl}/${fullPath}`;

    return new Response(JSON.stringify({ url: fileUrl }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
