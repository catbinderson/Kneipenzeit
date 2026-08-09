import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Kneipenzeit",
  description: "Automatische Anwesenheitszeiten für die Gaststätte Heuchelberg",
  manifest: "/Kneipenzeit/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    title: "Kneipenzeit",
    statusBarStyle: "black-translucent",
  },
  icons: {
    icon: "/Kneipenzeit/favicon.svg",
    apple: "/Kneipenzeit/favicon.svg",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="de"><body>{children}</body></html>;
}
