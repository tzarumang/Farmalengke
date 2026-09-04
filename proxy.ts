import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

/**
 * Refreshes the Supabase session cookie and redirects signed-out visitors away from
 * the app shell.
 *
 * This is a user-experience optimisation, NOT a security boundary. Every page and
 * action re-verifies identity itself — see the checks in the route handlers and the
 * data-access layer. Treating this file as the authorization gate is the classic
 * Next.js middleware mistake.
 */
export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          for (const { name, value } of cookiesToSet) {
            request.cookies.set(name, value);
          }
          response = NextResponse.next({ request });
          for (const { name, value, options } of cookiesToSet) {
            response.cookies.set(name, value, options);
          }
        },
      },
    },
  );

  // getClaims() verifies the JWT signature locally. Never authorize off getSession().
  const { data } = await supabase.auth.getClaims();

  const isSignedIn = Boolean(data?.claims);
  const { pathname } = request.nextUrl;
  const isAuthRoute = pathname.startsWith('/login');

  if (!isSignedIn && !isAuthRoute) {
    const url = request.nextUrl.clone();
    url.pathname = '/login';
    return NextResponse.redirect(url);
  }

  if (isSignedIn && isAuthRoute) {
    const url = request.nextUrl.clone();
    url.pathname = '/profile';
    return NextResponse.redirect(url);
  }

  return response;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
};
