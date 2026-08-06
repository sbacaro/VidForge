import { defineConfig } from "vite";

export default defineConfig({
  base: "/VidForge/",
  build: {
    outDir: "../docs",
    emptyOutDir: true,
  },
});
