import { createClient } from '@/lib/supabase/server'
import { requirePortalAccess } from '@/lib/supabase/access'

export default async function VerificationPage() {
  const access = await requirePortalAccess('admin')
  if (!access?.organisation_id) return <div className="notice danger">No organisation context is available.</div>
  const supabase = await createClient()
  const { data, error } = await supabase.from('verification_records').select('id,counterparty_id,contact_id,mine_id,laboratory_id,verification_type,status,verified_at,valid_until,confidence_score,notes,created_at').eq('organisation_id', access.organisation_id).order('created_at', { ascending: false }).limit(200)
  if (error) throw error
  const rows = data ?? []
  return <><h1 className="page-title">Verification</h1><p className="muted">Evidence-backed verification history across counterparties, contacts, mines and laboratories.</p><div className="table-wrap"><table className="table"><thead><tr><th>Target</th><th>Type</th><th>Status</th><th>Confidence</th><th>Verified</th><th>Valid until</th><th>Notes</th></tr></thead><tbody>{rows.map((r:any)=><tr key={r.id}><td>{r.counterparty_id||r.contact_id||r.mine_id||r.laboratory_id}</td><td>{r.verification_type}</td><td><span className="badge">{r.status}</span></td><td>{Number(r.confidence_score||0).toFixed(0)}%</td><td>{r.verified_at?new Date(r.verified_at).toLocaleDateString():'—'}</td><td>{r.valid_until||'—'}</td><td>{r.notes||'—'}</td></tr>)}</tbody></table>{!rows.length&&<div className="empty">No verification records available.</div>}</div></>
}
