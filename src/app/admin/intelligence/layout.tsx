import Link from 'next/link'
import { requirePortalAccess } from '@/lib/supabase/access'

const links = [
  ['Overview', '/admin/intelligence'],
  ['Imports', '/admin/intelligence/imports'],
  ['Duplicate Review', '/admin/intelligence/duplicates'],
  ['Counterparties', '/admin/intelligence/counterparties'],
  ['Mines', '/admin/intelligence/mines'],
  ['Laboratories', '/admin/intelligence/laboratories'],
  ['Verification', '/admin/intelligence/verification'],
  ['Sources', '/admin/intelligence/sources'],
]

export default async function IntelligenceLayout({ children }: { children: React.ReactNode }) {
  const access = await requirePortalAccess('admin')
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">MKHONTO RESOURCES</div>
        <div className="muted" style={{ marginBottom: 18 }}>Commodity Intelligence</div>
        <nav className="nav">
          {links.map(([label, href]) => <Link key={href} href={href}>{label}</Link>)}
        </nav>
        <div className="muted" style={{ marginTop: 30, fontSize: 12 }}>
          {access?.organisation_name || 'Mkhonto Resources'}<br />{access?.membership_role || 'Authorised user'}
        </div>
      </aside>
      <main className="content">{children}</main>
    </div>
  )
}
