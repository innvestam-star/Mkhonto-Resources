import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

type ProtectedPortal = 'admin' | 'finance' | 'freight' | 'driver' | 'portal'

function portalForPath(pathname: string): ProtectedPortal | null {
  if (pathname.startsWith('/admin/finance')) return 'finance'
  if (pathname.startsWith('/admin/freight')) return 'freight'
  if (pathname.startsWith('/admin')) return 'admin'
  if (pathname.startsWith('/driver')) return 'driver'
  if (pathname.startsWith('/portal')) return 'portal'
  return null
}

function redirectWithSession(
  request: NextRequest,
  sourceResponse: NextResponse,
  pathname: string,
  searchParams?: Record<string, string>,
) {
  const url = request.nextUrl.clone()
  url.pathname = pathname
  url.search = ''

  Object.entries(searchParams ?? {}).forEach(([key, value]) => {
    url.searchParams.set(key, value)
  })

  const response = NextResponse.redirect(url)

  sourceResponse.cookies.getAll().forEach((cookie) => {
    response.cookies.set(cookie)
  })

  for (const header of ['cache-control', 'expires', 'pragma']) {
    const value = sourceResponse.headers.get(header)
    if (value) response.headers.set(header, value)
  }

  return response
}

/** Refresh the Auth session and enforce role-aware protected routes. */
export async function updateSession(request: NextRequest) {
  const protectedPortal = portalForPath(request.nextUrl.pathname)

  let supabaseResponse = NextResponse.next({ request })

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY

  if (!url || !publishableKey) {
    throw new Error('Missing public Supabase environment variables')
  }

  const supabase = createServerClient(url, publishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll()
      },
      setAll(cookiesToSet, cacheHeaders) {
        cookiesToSet.forEach(({ name, value }) => {
          request.cookies.set(name, value)
        })

        supabaseResponse = NextResponse.next({ request })

        cookiesToSet.forEach(({ name, value, options }) => {
          supabaseResponse.cookies.set(name, value, options)
        })

        Object.entries(cacheHeaders).forEach(([key, value]) => {
          supabaseResponse.headers.set(key, value)
        })
      },
    },
  })

  // getClaims validates the access token. Do not authorize server routes from
  // getSession(), because cookie session data alone is not a trust boundary.
  const { data: claimsData } = await supabase.auth.getClaims()
  const claims = claimsData?.claims

  if (!protectedPortal) return supabaseResponse

  if (!claims) {
    return redirectWithSession(request, supabaseResponse, '/login', {
      next: `${request.nextUrl.pathname}${request.nextUrl.search}`,
    })
  }

  const { data: allowed, error: accessError } = await supabase.rpc(
    'can_access_portal',
    {
      p_portal: protectedPortal,
      p_organisation_id: null,
    },
  )

  if (!accessError && allowed === true) return supabaseResponse

  const { data: accessRows } = await supabase.rpc('get_my_access')
  const defaultRoute =
    Array.isArray(accessRows) && accessRows.length > 0
      ? String(accessRows[0].default_route || '/portal')
      : '/onboarding'

  return redirectWithSession(request, supabaseResponse, defaultRoute, {
    reason: 'unauthorised',
  })
}
