import { createClient } from '@/lib/supabase/server'
import { requirePortalAccess } from '@/lib/supabase/access'
import { listMinesForIntelligence } from '@/lib/mrcip/intelligence'

export default async function MinesPage() {
  const access = await requirePortalAccess('admin')
  if (!access?.organisation_id) return <div className="notice danger">No organisation context is available.</div>
  const supabase = await createClient()
  const rows = await listMinesForIntelligence(supabase, access.organisation_id, { limit: 200 })
  return <><h1 className="page-title">Mines</h1><p className="muted">Mine intelligence with public operational data. Protected coordinates and sensitive commercial notes remain excluded.</p><div className="table-wrap"><table className="table"><thead><tr><th>Mine</th><th>Location</th><th>Type</th><th>Status</th><th>Available MT</th><th>Capacity MT/month</th><th>Verification</th><th>Confidence</th></tr></thead><tbody>{rows.map((r:any)=><tr key={r.id}><td><strong>{r.name}</strong></td><td>{[r.nearest_town,r.province_state,r.country].filter(Boolean).join(', ')}</td><td>{r.mine_type||'—'}</td><td>{r.mine_status}</td><td>{r.estimated_available_tonnage_mt??'—'}</td><td>{r.estimated_production_capacity_mt_month??'—'}</td><td><span className="badge">{r.verification_status}</span></td><td>{Number(r.confidence_score||0).toFixed(0)}%</td></tr>)}</tbody></table>{!rows.length&&<div className="empty">No mine intelligence records available.</div>}</div></>
}
