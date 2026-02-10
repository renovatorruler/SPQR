"use client"

// Thin wrapper — Next.js App Router entry point
// ReScript components live in src/ and compile to .res.mjs
// This "use client" boundary is needed because ReScript uses React hooks
import { make as App } from "../App.res.mjs"

export default function Page() {
  return <App />
}
