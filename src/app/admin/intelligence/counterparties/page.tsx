import { createClient } from '@/lib/supabase/server'
import { requirePortalAccess } from '@/lib/supabase/access'
import { listCounterpartiesForIntelligence } from '@/lib/mrcip/intelligence'

export default async function CounterpartiesPage() {
  const access = await requirePortalAccess('admin')
  if (!access?.organisation_id) return <div className="notice danger">No organisation context is available.</div>
  const supabase = await createClient()
  const rows = await listCounterpartiesForIntelligence(supabase, access.organisation_id, undefined, { limit: 200 })
  return <><h1 className="page-title">Counterparties</h1><p className="muted">Buyer, seller, producer, transporter, laboratory, partner and supporting-entity master records.</p><div className="table-wrap"><table className="table"><thead><tr><th>Company</th><th>Registration</th><th>Domain</th><th>Contact</th><th>Status</th><th>Verification</th><th>Confidence</th></tr></thead><tbody>{rows.map((r:any)=><tr key={r.id}><td><strong>{r.legal_name}</strong><div className="muted">{r.trading_name}</div></td><td>{r.registration_number||'—'}</td><td>{r.website_domain||'—'}</td><td>{r.general_email||r.main_telephone||'—'}</td><td>{r.company_status}</td><td><span className="badge">{r.verification_status}</span></td><td>{Number(r.confidence_score||0).toFixed(0)}%</td></tr>)}</tbody></table>{!rows.length&&<div className="empty">No counterparties available.</div>}</div></>
}
