// @ts-nocheck
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

function env(...keys: string[]) {
  for (const key of keys) {
    const value = Deno.env.get(key)?.trim()
    if (value) return value
  }
  return ''
}

function normalizeProviderUrl(baseOrUrl: string, format: string) {
  const clean = baseOrUrl.replace(/\/+$/, '')
  if (format === 'anthropic') {
    if (clean.endsWith('/messages')) return clean
    if (clean.endsWith('/v1')) return `${clean}/messages`
    return `${clean}/v1/messages`
  }
  if (clean.endsWith('/chat/completions')) return clean
  if (clean.endsWith('/v1')) return `${clean}/chat/completions`
  return `${clean}/v1/chat/completions`
}

function normalizeMessages(messages: unknown[]) {
  return messages
    .filter((message) => message && typeof message === 'object')
    .map((message) => ({
      role: String(message.role || 'user'),
      content: String(message.content || ''),
    }))
    .filter((message) => message.content.trim().length > 0)
}

function anthropicBody(
  messages: Array<{ role: string; content: string }>,
  model: string,
  maxTokens: number,
  temperature: number,
) {
  const system = messages
    .filter((message) => message.role === 'system')
    .map((message) => message.content)
    .join('\n\n')
  const chatMessages = messages
    .filter((message) => message.role !== 'system')
    .map((message) => ({
      role: message.role === 'assistant' ? 'assistant' : 'user',
      content: message.content,
    }))

  return {
    model,
    system: system || undefined,
    messages: chatMessages,
    max_tokens: maxTokens,
    temperature,
  }
}

function extractAssistantContent(data: any) {
  const choiceContent = data?.choices?.[0]?.message?.content
  if (typeof choiceContent === 'string' && choiceContent.trim()) {
    return choiceContent.trim()
  }

  if (typeof data?.reply === 'string' && data.reply.trim()) {
    return data.reply.trim()
  }
  if (typeof data?.content === 'string' && data.content.trim()) {
    return data.content.trim()
  }
  if (Array.isArray(data?.content)) {
    const content = data.content
      .map((part: any) => part?.text || part?.content || '')
      .join('')
      .trim()
    if (content) return content
  }
  if (typeof data?.output_text === 'string' && data.output_text.trim()) {
    return data.output_text.trim()
  }
  return ''
}

serve(async (req) => {
  // ─── Auth verification ───
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return jsonResponse({ error: 'Missing Authorization header' }, 401)
  }

  const supabaseAuth = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
  )

  const { data: { user }, error: authError } = await supabaseAuth.auth.getUser(
    authHeader.replace('Bearer ', ''),
  )

  if (authError || !user) {
    return jsonResponse({ error: 'Unauthorized' }, 401)
  }

  try {
    const { model, messages, max_tokens, temperature } = await req.json()
    const normalizedMessages = normalizeMessages(Array.isArray(messages) ? messages : [])
    if (normalizedMessages.length === 0) {
      return jsonResponse({ error: 'messages are required' }, 400)
    }

    const format = env('AI_API_FORMAT', 'ANTHROPIC_API_FORMAT').toLowerCase() || 'openai'
    const apiKey = env(
      'AI_AUTH_TOKEN',
      'AI_API_KEY',
      'ANTHROPIC_AUTH_TOKEN',
      'ANTHROPIC_API_KEY',
      'OPENROUTER_API_KEY',
      'OPENAI_API_KEY',
    )
    const providerUrl = normalizeProviderUrl(
      env(
        'AI_CHAT_COMPLETIONS_URL',
        'AI_API_URL',
        'AI_BASE_URL',
        'ANTHROPIC_BASE_URL',
        'OPENROUTER_BASE_URL',
        'OPENAI_BASE_URL',
      ) || 'https://openrouter.ai/api',
      format,
    )
    const selectedModel = model ||
      env('AI_MODEL', 'ANTHROPIC_MODEL', 'OPENROUTER_MODEL', 'OPENAI_MODEL') ||
      'inclusionai/ring-2.6-1t:free'
    const maxTokens = Number(max_tokens ?? env('AI_MAX_TOKENS')) || 512
    const temp = Number(temperature ?? env('AI_TEMPERATURE')) || 0.7

    if (!apiKey) {
      return jsonResponse({ error: 'AI API key not configured' }, 500)
    }

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    }
    if (format === 'anthropic') {
      headers['x-api-key'] = apiKey
      headers['anthropic-version'] = env('ANTHROPIC_VERSION') || '2023-06-01'
    } else {
      headers['Authorization'] = apiKey.startsWith('Bearer ')
        ? apiKey
        : `Bearer ${apiKey}`
      headers['HTTP-Referer'] = env('OPENROUTER_HTTP_REFERER', 'AI_HTTP_REFERER') || 'https://snapix.app'
      headers['X-Title'] = env('OPENROUTER_APP_TITLE', 'AI_APP_TITLE') || 'Snapix'
    }

    const extraHeaders = env('AI_EXTRA_HEADERS')
    if (extraHeaders) {
      try {
        Object.assign(headers, JSON.parse(extraHeaders))
      } catch (_) {
        // Ignore malformed optional headers.
      }
    }

    const requestBody = format === 'anthropic'
      ? anthropicBody(normalizedMessages, selectedModel, maxTokens, temp)
      : {
          model: selectedModel,
          messages: normalizedMessages,
          max_tokens: maxTokens,
          temperature: temp,
        }

    const response = await fetch(providerUrl, {
      method: 'POST',
      headers,
      body: JSON.stringify(requestBody),
    })

    const data = await response.json()
    const content = extractAssistantContent(data)

    if (!response.ok) {
      return jsonResponse({
        error: data?.error?.message || data?.error || 'AI provider request failed',
        provider_status: response.status,
        provider: format,
      }, response.status)
    }

    return jsonResponse({
      choices: [{
        message: {
          role: 'assistant',
          content,
        },
      }],
      provider: format,
      model: selectedModel,
      raw: data,
    })
  } catch (error) {
    return jsonResponse({ error: error.message }, 500)
  }
})
