const esbuild = require("esbuild");
const fs = require("fs");

const prod = process.argv.includes("--prod");

const shared = {
    bundle: true,
    minify: prod,
    pure: [],
    sourcemap: prod ? false : "inline",
    logLevel: "info",
    platform: "browser",
};

async function build() {
    // 1. Extension background (ESM service worker)
    await esbuild.build({
        ...shared,
        entryPoints: ["src/extension/background.js"],
        outfile: "dist/extension/background.js",
        format: "esm",
    });

    // 2. Extension content scripts (IIFE - no module support in content scripts)
    await esbuild.build({
        ...shared,
        entryPoints: [
            "src/extension/content.js",
            "src/extension/content-early.js",
        ],
        outdir: "dist/extension",
        format: "iife",
    });

    // 3. VivaldiMod (single ESM bundle)
    await esbuild.build({
        ...shared,
        entryPoints: ["src/vivaldi/main.js"],
        outfile: "dist/vivaldi/main.js",
        format: "esm",
    });

    // 4. Copy extension files
    fs.mkdirSync("dist/extension", { recursive: true });
    fs.copyFileSync(
        "src/extension/manifest.json",
        "dist/extension/manifest.json"
    );
    fs.copyFileSync(
        "src/extension/popup.html",
        "dist/extension/popup.html"
    );
    fs.copyFileSync(
        "src/extension/popup.js",
        "dist/extension/popup.js"
    );

    // 5. Copy images
    fs.mkdirSync("dist/extension/images", { recursive: true });
    if (fs.existsSync("src/extension/images")) {
        fs.readdirSync("src/extension/images").forEach((file) => {
            fs.copyFileSync(
                `src/extension/images/${file}`,
                `dist/extension/images/${file}`
            );
        });
    }

    console.log(prod ? "Production build complete." : "Dev build complete.");
}

build().catch((e) => {
    console.error(e);
    process.exit(1);
});
