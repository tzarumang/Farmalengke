import type { ReactNode } from 'react';

import styles from './Notice.module.css';

export interface NoticeProps {
  tone: 'error' | 'success' | 'info';
  title?: string;
  children: ReactNode;
}

/**
 * Feedback that never relies on colour alone to carry its meaning — each tone also
 * carries a text label, per WCAG and the PRD's accessibility target.
 */
export function Notice({ tone, title, children }: NoticeProps) {
  const label = tone === 'error' ? 'Error' : tone === 'success' ? 'Done' : 'Note';

  return (
    <div
      className={[styles.notice, styles[tone]].join(' ')}
      role={tone === 'error' ? 'alert' : 'status'}
    >
      <p className={styles.label}>{title ?? label}</p>
      <div>{children}</div>
    </div>
  );
}
