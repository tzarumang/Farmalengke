import type { Metadata, Viewport } from 'next';

import '@/styles/globals.css';

export const metadata: Metadata = {
  title: 'Farmalengke',
  description:
    'Sell your harvest at a fair price. Farmalengke connects farmers and buyers through the bagsakan.',
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  // Never block zoom: the PRD requires the interface to stay usable at 200%.
  maximumScale: 5,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <a href="#main" className="sr-only">
          Skip to main content
        </a>
        <main id="main" className="page">
          {children}
        </main>
      </body>
    </html>
  );
}
