import type { Metadata } from "next";
import { Geist } from "next/font/google";
import "./globals.css";
const geist=Geist({variable:"--font-geist",subsets:["latin"]});
export const metadata:Metadata={title:"Kneipenzeit",description:"Automatische Anwesenheitszeiten für deine Stammkneipe",other:{"codex-preview":"development"}};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="de"><body className={geist.variable}>{children}</body></html>}
