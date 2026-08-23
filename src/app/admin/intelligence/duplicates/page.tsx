import { createClient } from '@/lib/supabase/server'
import { requirePortalAccess } from '@/lib/supabase/access'

export default async function DuplicateReviewPage() {
  const access = await requirePortalAccess('admin')
  if (!access?.organisation_id) return <div className="notice danger">No organisation context is available.</div>
  const supabase = await createClient()
  const { data, error } = await supabase.from('intelligence_duplicate_candidates').select('id,import_row_id,candidate_counterparty_id,candidate_contact_id,candidate_mine_id,candidate_laboratory_id,match_score,matched_fields,decision,created_at').eq('organisation_id', access.organisation_id).eq('decision', 'pending').order('match_score', { ascending: false }).limit(200)
  if (error) throw error
  const rows = data ?? []
  return <><h1 className="page-title">Duplicate Review</h1><p className="muted">Pending deterministic duplicate candidates requiring an authorised merge/separate decision.</p><div className="table-wrap"><table className="table"><thead><tr><th>Score</th><th>Import row</th><th>Candidate target</th><th>Matched fields</th><th>Decision</th></tr></thead><tbody>{rows.map((r:any)=><tr key={r.id}><td><strong>{Number(r.match_score).toFixed(0)}%</strong></td><td>{r.import_row_id}</td><td>{r.candidate_counterparty_id||r.candidate_contact_id||r.candidate_mine_id||r.candidate_laboratory_id}</td><td><pre style={{whiteSpace:'pre-wrap',margin:0}}>{JSON.stringify(r.matched_fields,null,2)}</pre></td><td><span className="badge">{r.decision}</span></td></tr>)}</tbody></table>{!rows.length&&<div className="empty">No pending duplicate candidates.</div>}</div></>
}
