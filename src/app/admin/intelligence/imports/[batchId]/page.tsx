import { createClient } from '@/lib/supabase/server'
import { requirePortalAccess } from '@/lib/supabase/access'
import { listImportRows, refreshImportBatchStats } from '@/lib/mrcip/intelligence'

export default async function ImportBatchPage({ params }: { params: Promise<{ batchId: string }> }) {
  await requirePortalAccess('admin')
  const { batchId } = await params
  const supabase = await createClient()
  const [rows, stats] = await Promise.all([
    listImportRows(supabase, batchId, {}, { limit: 200 }),
    refreshImportBatchStats(supabase, batchId),
  ])

  return (
    <>
      <h1 className="page-title">Import Batch Review</h1>
      <p className="muted">Batch {batchId}</p>
      {stats && <div className="grid"><div className="card"><div className="muted">Total</div><div className="metric">{stats.total_rows}</div></div><div className="card"><div className="muted">Valid</div><div className="metric">{stats.valid_rows}</div></div><div className="card"><div className="muted">Warnings</div><div className="metric">{stats.warning_rows}</div></div><div className="card"><div className="muted">Errors</div><div className="metric">{stats.error_rows}</div></div><div className="card"><div className="muted">Duplicates</div><div className="metric">{stats.duplicate_rows}</div></div></div>}
      <div className="table-wrap"><table className="table"><thead><tr><th>Row</th><th>Entity</th><th>Status</th><th>Normalized data</th><th>Validation</th></tr></thead><tbody>{rows.map((r) => <tr key={r.id}><td>{r.source_sheet || 'Sheet'} #{r.source_row_number}</td><td>{r.entity_type}</td><td><span className="badge">{r.validation_status}</span></td><td><pre style={{whiteSpace:'pre-wrap',margin:0,maxWidth:520}}>{JSON.stringify(r.normalized_data,null,2)}</pre></td><td><pre style={{whiteSpace:'pre-wrap',margin:0}}>{JSON.stringify(r.validation_messages,null,2)}</pre></td></tr>)}</tbody></table>{!rows.length && <div className="empty">No rows found for this batch.</div>}</div>
    </>
  )
}
