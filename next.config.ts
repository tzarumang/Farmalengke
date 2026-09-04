import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,

  // PRD section 8 targets a 3G connection on a 2 GB Android device, with a payload
  // budget under 300 KB compressed. Typed routes and strict builds are cheap ways to
  // keep regressions out; the payload itself is watched in CI.
  typedRoutes: true,

  // Next 16 no longer runs ESLint during `next build`, so lint is a separate step
  // in CI rather than something the build would catch.
  typescript: {
    ignoreBuildErrors: false,
  },

  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          { key: 'X-Frame-Options', value: 'DENY' },
          {
            key: 'Permissions-Policy',
            // Location is requested per-farm with explicit consent (M2), never
            // ambiently by the page.
            value: 'camera=(), microphone=(), geolocation=()',
          },
        ],
      },
    ];
  },
};

export default nextConfig;
