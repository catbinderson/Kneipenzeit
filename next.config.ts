import type { NextConfig } from "next";

const onGitHubPages = process.env.GITHUB_ACTIONS === "true";

const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,
  images: { unoptimized: true },
  basePath: onGitHubPages ? "/Kneipenzeit" : "",
  assetPrefix: onGitHubPages ? "/Kneipenzeit/" : "",
};

export default nextConfig;
