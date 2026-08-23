import { createClient } from '@/lib/supabase/server'
import { requirePortalAccess } from '@/lib/supabase/access'

export default async function SourcesPage() {
  const access = await requirePortalAccess('admin')
  if (!access?.organisation_id) return <div className="notice danger">No organisation context is available.</div>
  const supabase = await createClient()
  const { data, error } = await supabase.from('intelligence_sources').select('id,counterparty_id,contact_id,mine_id,laboratory_id,source_name,source_url,source_type,discovered_at,last_checked_at,confidence_score,verification_status,source_sheet,source_row,notes,created_at').eq('organisation_id', access.organisation_id).order('created_at', { ascending: false }).limit(200)
  if (error) throw error
  const rows = data ?? []
  return <><h1 className="page-title">Sources & Provenance</h1><p className="muted">Every intelligence record should retain where it came from, when it was checked, confidence and verification state.</p><div className="table-wrap"><table className="table"><thead><tr><th>Source</th><th>Target</th><th>Type</th><th>Confidence</th><th>Verification</th><th>Last checked</th><th>Import reference</th></tr></thead><tbody>{rows.map((r:any)=><tr key={r.id}><td><strong>{r.source_name}</strong><div className="muted">{r.source_url||'No URL'}</div></td><td>{r.counterparty_id||r.contact_id||r.mine_id||r.laboratory_id||'General'}</td><td>{r.source_type}</td><td>{Number(r.confidence_score||0).toFixed(0)}%</td><td><span className="badge">{r.verification_status}</span></td><td>{r.last_checked_at?new Date(r.last_checked_at).toLocaleDateString():'—'}</td><td>{[r.source_sheet,r.source_row].filter(Boolean).join(' / ')||'—'}</td></tr>)}</tbody></table>{!rows.length&&<div className="empty">No provenance records available.</div>}</div></>
}
