import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://labs.hybridsolutions.cloud"),
  title: "Hybrid Solutions Cloud Labs",
  description:
    "Cloud tools, AI infrastructure, security software, and useful experiments built in the open by Hybrid Solutions Cloud.",
  applicationName: "Hybrid Solutions Cloud Labs",
  authors: [{ name: "Kristopher Turner", url: "https://hybridsolutions.cloud" }],
  keywords: [
    "Hybrid Solutions Cloud",
    "Azure",
    "cloud tools",
    "Azure AI Foundry",
    "open source",
  ],
  openGraph: {
    type: "website",
    url: "https://labs.hybridsolutions.cloud",
    siteName: "Hybrid Solutions Cloud Labs",
    title: "Useful things, built out loud.",
    description:
      "A working catalog of cloud tools, AI infrastructure, security software, and side quests.",
    images: [
      {
        url: "/og.png",
        width: 1732,
        height: 910,
        alt: "Hybrid Solutions Cloud Labs — Useful things, built out loud.",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Hybrid Solutions Cloud Labs",
    description: "Useful things, built out loud.",
    images: ["/og.png"],
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#07110f",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
