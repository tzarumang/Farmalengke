/**
 * Loading state. Mirrors the real layout so the page does not shift when it arrives —
 * layout shift on a slow connection is what makes an app feel broken.
 */
export default function ProfileLoading() {
  return (
    <div aria-busy="true" aria-live="polite">
      <h1>Your profile</h1>
      <p>Loading your details…</p>
    </div>
  );
}
