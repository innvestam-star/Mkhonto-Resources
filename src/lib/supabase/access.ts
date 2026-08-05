import { redirect } from 'next/navigation'

import { createClient } from './server'

export type PortalName = 'admin' | 'finance' | 'freight' | 'driver' | 'portal'

type AccessRow = {
  default_route: string
  organisation_id: string
  organisation_name: string
  membership_role: string
  can_manage_organisation: boolean
  can_access_finance: boolean
  can_access_freight: boolean
  can_access_driver_portal: boolean
}

/**
 * Server-side guard for protected layouts, pages, actions, and route handlers.
 * The proxy handles navigation; this helper provides defence in depth close to
 * the protected server component.
 */
export async function requirePortalAccess(portal: PortalName) {
  const supabase = await createClient()
  const { data: claimsData } = await supabase.auth.getClaims()

  if (!claimsData?.claims) redirect('/login')

  const { data: allowed, error } = await supabase.rpc('can_access_portal', {
    p_portal: portal,
    p_organisation_id: null,
  })

  if (!error && allowed === true) {
    const { data: rows } = await supabase.rpc('get_my_access')
    return (Array.isArray(rows) ? rows[0] : null) as AccessRow | null
  }

  const { data: rows } = await supabase.rpc('get_my_access')
  const access = (Array.isArray(rows) ? rows[0] : null) as AccessRow | null

  redirect(access?.default_route || '/onboarding')
}
