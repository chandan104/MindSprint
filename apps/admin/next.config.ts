import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Tree-shake the lucide-react barrel so only the icons actually referenced
  // land in the client bundle instead of the whole icon set.
  experimental: {
    optimizePackageImports: ["lucide-react"],
  },
};

export default nextConfig;
