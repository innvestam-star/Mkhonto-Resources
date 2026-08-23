import { createClient } from '@/lib/supabase/server'
import { requirePortalAccess } from '@/lib/supabase/access'

export default async function IntelligenceOverviewPage() {
  const access = await requirePortalAccess('admin')
  const organisationId = access?.organisation_id
  if (!organisationId) return <div className="notice danger">No organisation context is available.</div>

  const supabase = await createClient()
  const tables = ['counterparties','mines','laboratories','intelligence_import_batches','intelligence_duplicate_candidates','verification_records'] as const
  const counts = await Promise.all(tables.map(async (table) => {
    const { count } = await supabase.from(table).select('*', { count: 'exact', head: true }).eq('organisation_id', organisationId)
    return [table, count ?? 0] as const
  }))
  const map = Object.fromEntries(counts)

  return (
    <>
      <h1 className="page-title">Commodity Intelligence</h1>
      <p className="muted">DISCOVER → VERIFY → QUALIFY → MATCH → PROTECT → ENGAGE</p>
      <div className="grid">
        <div className="card"><div className="muted">Counterparties</div><div className="metric">{map.counterparties}</div></div>
        <div className="card"><div className="muted">Mines</div><div className="metric">{map.mines}</div></div>
        <div className="card"><div className="muted">Laboratories</div><div className="metric">{map.laboratories}</div></div>
        <div className="card"><div className="muted">Import batches</div><div className="metric">{map.intelligence_import_batches}</div></div>
        <div className="card"><div className="muted">Duplicate candidates</div><div className="metric">{map.intelligence_duplicate_candidates}</div></div>
        <div className="card"><div className="muted">Verification records</div><div className="metric">{map.verification_records}</div></div>
      </div>
      <div className="notice">Sensitive mine coordinates and protected commercial notes are intentionally excluded from this overview and remain governed by their dedicated RLS policies.</div>
    </>
  )
}
