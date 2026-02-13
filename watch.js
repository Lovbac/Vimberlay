const esbuild = require("esbuild");
const fs = require("fs");

const shared = {
    bundle: true,
    sourcemap: "inline",
    logLevel: "info",
    platform: "browser",
};

async function watch() {
    const ctx1 = await esbuild.context({
        ...shared,
        entryPoints: ["src/extension/background.js"],
        outfile: "dist/extension/background.js",
        format: "esm",
    });

    const ctx2 = await esbuild.context({
        ...shared,
        entryPoints: [
            "src/extension/content.js",
            "src/extension/content-early.js",
        ],
        outdir: "dist/extension",
        format: "iife",
    });

    const ctx3 = await esbuild.context({
        ...shared,
        entryPoints: ["src/vivaldi/main.js"],
        outfile: "dist/vivaldi/main.js",
        format: "esm",
    });

    // Copy manifest once
    fs.mkdirSync("dist/extension", { recursive: true });
    fs.copyFileSync(
        "src/extension/manifest.json",
        "dist/extension/manifest.json"
    );

    await Promise.all([ctx1.watch(), ctx2.watch(), ctx3.watch()]);
    console.log("Watching for changes...");
}

watch().catch((e) => {
    console.error(e);
    process.exit(1);
});
