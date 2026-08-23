import { createClient } from '@/lib/supabase/server'
import { requirePortalAccess } from '@/lib/supabase/access'
import { listLaboratoriesForIntelligence } from '@/lib/mrcip/intelligence'

export default async function LaboratoriesPage() {
  const access = await requirePortalAccess('admin')
  if (!access?.organisation_id) return <div className="notice danger">No organisation context is available.</div>
  const supabase = await createClient()
  const rows = await listLaboratoriesForIntelligence(supabase, access.organisation_id, { limit: 200 })
  return <><h1 className="page-title">Laboratories</h1><p className="muted">Inspection, sampling and testing laboratories with accreditation and verification status.</p><div className="table-wrap"><table className="table"><thead><tr><th>Laboratory</th><th>Location</th><th>Accreditation</th><th>Expiry</th><th>Preferred</th><th>Turnaround</th><th>Verification</th></tr></thead><tbody>{rows.map((r:any)=><tr key={r.id}><td><strong>{r.laboratory_name}</strong></td><td>{[r.city,r.province_state,r.country].filter(Boolean).join(', ')}</td><td>{[r.accreditation_body,r.accreditation_number].filter(Boolean).join(' · ')||'—'}</td><td>{r.accreditation_expiry||'—'}</td><td>{r.preferred_status||'—'}</td><td>{r.typical_turnaround||'—'}</td><td><span className="badge">{r.verification_status}</span></td></tr>)}</tbody></table>{!rows.length&&<div className="empty">No laboratories available.</div>}</div></>
}
