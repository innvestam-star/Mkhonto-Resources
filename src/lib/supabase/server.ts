import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

/** Create a request-scoped Supabase client for Server Components and actions. */
export async function createClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY

  if (!url || !publishableKey) {
    throw new Error('Missing public Supabase environment variables')
  }

  const cookieStore = await cookies()

  return createServerClient(url, publishableKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll()
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookieStore.set(name, value, options)
          })
        } catch {
          // Server Components cannot write cookies. The root proxy refreshes
          // and persists the session before protected content is rendered.
        }
      },
    },
  })
}
