import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { requirePortalAccess } from '@/lib/supabase/access'
import { listImportBatches } from '@/lib/mrcip/intelligence'

export default async function ImportsPage() {
  const access = await requirePortalAccess('admin')
  if (!access?.organisation_id) return <div className="notice danger">No organisation context is available.</div>
  const supabase = await createClient()
  const batches = await listImportBatches(supabase, access.organisation_id, undefined, { limit: 100 })

  return (
    <>
      <h1 className="page-title">Import Centre</h1>
      <p className="muted">Review XLSX/CSV intelligence batches, validation outcomes and duplicate flags.</p>
      <div className="table-wrap">
        <table className="table"><thead><tr><th>File</th><th>Status</th><th>Rows</th><th>Valid</th><th>Warnings</th><th>Errors</th><th>Duplicates</th><th>Imported</th></tr></thead>
          <tbody>{batches.map((b) => <tr key={b.id}><td><Link href={`/admin/intelligence/imports/${b.id}`}>{b.source_file_name}</Link><div className="muted">{b.source_file_type.toUpperCase()}</div></td><td><span className="badge">{b.status}</span></td><td>{b.total_rows}</td><td>{b.valid_rows}</td><td>{b.warning_rows}</td><td>{b.error_rows}</td><td>{b.duplicate_rows}</td><td>{b.imported_rows}</td></tr>)}</tbody>
        </table>
        {!batches.length && <div className="empty">No intelligence import batches are available yet.</div>}
      </div>
    </>
  )
}
