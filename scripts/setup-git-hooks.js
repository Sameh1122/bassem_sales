import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const hooksDir = path.join(rootDir, '.git', 'hooks');

if (!fs.existsSync(hooksDir)) {
  console.log('ℹ️ No .git/hooks directory found. Creating it...');
  fs.mkdirSync(hooksDir, { recursive: true });
}

const prePushScript = `#!/bin/sh
# Auto-update live documentation before pushing to GitHub
echo "🔄 [Git Hook] Synchronizing living documentation (BRD & SAD)..."
node scripts/update-docs.js

# Stage updated documentation
git add docs/BRD.md docs/SAD.md 2>/dev/null || true
echo "✅ [Git Hook] Living documentation synchronized!"
exit 0
`;

const hookPath = path.join(hooksDir, 'pre-push');
fs.writeFileSync(hookPath, prePushScript, { mode: 0o755 });
console.log('✅ Successfully installed .git/hooks/pre-push hook!');
console.log('👉 Any future "git push" will automatically refresh the live document headers.');
