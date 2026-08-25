/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  async redirects() {
    return [
      {
        source: "/app",
        destination: "/",
        permanent: true,
      },
      {
        source: "/auth/callback",
        destination: "/",
        permanent: false,
      },
    ];
  },
};

export default nextConfig;
