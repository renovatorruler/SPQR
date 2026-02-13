import { defineConfig } from "vitest/config";
import path from "path";

export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "src"),
    },
  },
  test: {
    include: ["src/__tests__/**/*.test.{mjs,ts,tsx}", "src/__tests__/**/*_test.res.mjs"],
    // Using "node" for pure logic tests; switch to "jsdom" when component tests are added
    environment: "node",
  },
});
