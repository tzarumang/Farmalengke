import Link from 'next/link';

export default function NotFound() {
  return (
    <>
      <h1>Page not found</h1>
      <p>
        That page does not exist. <Link href="/profile">Go to your profile</Link>.
      </p>
    </>
  );
}
