import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Mkhonto Resources | Commodity Intelligence',
  description: 'Mkhonto Resources Commodity Intelligence Platform admin workspace',
}

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
