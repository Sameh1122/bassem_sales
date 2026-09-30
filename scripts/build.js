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
