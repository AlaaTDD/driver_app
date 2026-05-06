// @ts-nocheck
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

serve(async (req) => {
  try {
    const { model, messages, max_tokens, temperature } = await req.json()

    const apiKey = Deno.env.get('OPENROUTER_API_KEY') || Deno.env.get('OPENAI_API_KEY')
    const apiUrl = Deno.env.get('AI_API_URL') || 'https://openrouter.ai/api/v1/chat/completions'

    if (!apiKey) {
      return new Response(JSON.stringify({ error: 'AI API key not configured' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: model || 'gpt-3.5-turbo',
        messages,
        max_tokens: max_tokens ?? 512,
        temperature: temperature ?? 0.7,
      }),
    })

    const data = await response.json()

    return new Response(JSON.stringify(data), {
      status: response.status,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
