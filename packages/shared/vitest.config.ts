import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["src/__tests__/**/*.test.mjs", "src/__tests__/**/*_test.res.mjs"],
    environment: "node",
  },
});
