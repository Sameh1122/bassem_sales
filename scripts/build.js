import fs from 'fs';
import path from 'path';

console.log('🚀 Running Vercel build script...');

const srcDir = path.resolve('frontend/build/web');
const destDir = path.resolve('public');

if (fs.existsSync(srcDir)) {
  fs.mkdirSync(destDir, { recursive: true });
  fs.cpSync(srcDir, destDir, { recursive: true });
  console.log('✅ Successfully copied frontend/build/web to public/');
} else {
  console.error('❌ frontend/build/web directory not found!');
}

// Ensure manifest.json exists in public/
const manifestPath = path.join(destDir, 'manifest.json');
if (!fs.existsSync(manifestPath)) {
  const srcManifest = path.resolve('frontend/web/manifest.json');
  if (fs.existsSync(srcManifest)) {
    fs.copyFileSync(srcManifest, manifestPath);
    console.log('✅ Copied manifest.json from frontend/web to public/');
  } else {
    fs.writeFileSync(manifestPath, JSON.stringify({
      name: "Excel Map Analytics Platform",
      short_name: "Chiller Analytics",
      start_url: ".",
      display: "standalone",
      background_color: "#0F172A",
      theme_color: "#06B6D4",
      description: "Excel Map Analytics & Delta Platform",
      orientation: "portrait-primary",
      prefer_related_applications: false,
      icons: []
    }, null, 2));
    console.log('✅ Created default manifest.json in public/');
  }
}

// Ensure assets directory and fallback JSON manifests exist in public/
const assetsDir = path.join(destDir, 'assets');
if (!fs.existsSync(assetsDir)) fs.mkdirSync(assetsDir, { recursive: true });

const assetManifestJson = path.join(assetsDir, 'AssetManifest.json');
if (!fs.existsSync(assetManifestJson)) fs.writeFileSync(assetManifestJson, '{}');

const fontManifestJson = path.join(assetsDir, 'FontManifest.json');
if (!fs.existsSync(fontManifestJson)) fs.writeFileSync(fontManifestJson, '[]');

const versionJson = path.join(destDir, 'version.json');
if (!fs.existsSync(versionJson)) {
  fs.writeFileSync(versionJson, JSON.stringify({ app_name: "frontend", version: "1.0.0", build_number: "1" }));
}

console.log('🎉 Build script completed successfully.');

