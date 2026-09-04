import type { ButtonHTMLAttributes, ReactNode } from 'react';

import styles from './Button.module.css';

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary';
  /** Renders a busy state and blocks repeat submissions. */
  pending?: boolean;
  children: ReactNode;
}

/**
 * Extends the native button rather than replacing it, so `type`, `form`, `onClick`
 * and everything else keep working — a variant should be a drop-in for the base.
 */
export function Button({
  variant = 'primary',
  pending = false,
  disabled,
  children,
  className,
  ...rest
}: ButtonProps) {
  return (
    <button
      {...rest}
      className={[styles.button, styles[variant], className].filter(Boolean).join(' ')}
      disabled={disabled ?? pending}
      aria-busy={pending || undefined}
    >
      {pending ? 'Working…' : children}
    </button>
  );
}
