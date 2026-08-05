import { createBrowserClient } from '@supabase/ssr'

/**
 * Browser Supabase client.
 *
 * The publishable key is intentionally available to browser code. Database
 * access remains protected by Supabase Auth and Row Level Security.
 */
export function createClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY

  if (!url || !publishableKey) {
    throw new Error('Missing public Supabase environment variables')
  }

  return createBrowserClient(url, publishableKey)
}
