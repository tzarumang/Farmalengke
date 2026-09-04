import Link from 'next/link';

import { getVerifiedRoles } from '@/features/profile/data';

import styles from './app-shell.module.css';

/**
 * The signed-in shell.
 *
 * Navigation is filtered by role so a farmer is not offered a market they cannot
 * buy in, and a buyer is not offered farm records they do not have. This is
 * courtesy, not security — every page verifies for itself, and the database
 * refuses regardless.
 */
export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const roles = await getVerifiedRoles();
  const isFarmer = roles.includes('farmer') || roles.includes('coop_officer');
  const canBuy =
    roles.includes('buyer') || roles.includes('trading_desk') || roles.includes('admin');
  const isTradingDesk = roles.includes('trading_desk') || roles.includes('admin');
  const isCompliance = roles.includes('compliance') || roles.includes('admin');

  return (
    <>
      <nav className={styles.nav} aria-label="Main">
        {isFarmer ? (
          <>
            <Link href="/farms">Farms</Link>
            <Link href="/listings">Produce</Link>
            <Link href="/prices">Prices</Link>
          </>
        ) : null}
        {canBuy ? <Link href="/market">Market</Link> : null}
        <Link href="/orders">Orders</Link>
        {isTradingDesk ? <Link href="/trading/prices">Publish prices</Link> : null}
        {isCompliance ? <Link href="/compliance/kyc">Verification queue</Link> : null}
        <Link href="/verify">Verification</Link>
        <Link href="/profile">Profile</Link>
      </nav>
      {children}
    </>
  );
}
