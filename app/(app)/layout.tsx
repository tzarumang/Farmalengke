import Link from 'next/link';

import styles from './app-shell.module.css';

/**
 * The signed-in shell. Kept to three destinations: a farmer on a small screen
 * should be able to reach anything in one tap without a menu.
 */
export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <nav className={styles.nav} aria-label="Main">
        <Link href="/farms">Farms</Link>
        <Link href="/listings">Produce</Link>
        <Link href="/profile">Profile</Link>
      </nav>
      {children}
    </>
  );
}
