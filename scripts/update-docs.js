import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const docsDir = path.join(rootDir, 'docs');

function getGitInfo() {
  try {
    const commitSha = execSync('git rev-parse --short HEAD', { cwd: rootDir, encoding: 'utf8' }).trim();
    const branch = execSync('git rev-parse --abbrev-ref HEAD', { cwd: rootDir, encoding: 'utf8' }).trim();
    const lastAuthor = execSync('git log -1 --format="%an"', { cwd: rootDir, encoding: 'utf8' }).trim();
    const lastMessage = execSync('git log -1 --format="%s"', { cwd: rootDir, encoding: 'utf8' }).trim();
    const commitDate = execSync('git log -1 --format="%cd" --date=format:"%Y-%m-%d %H:%M:%S UTC"', { cwd: rootDir, encoding: 'utf8' }).trim();
    return { commitSha, branch, lastAuthor, lastMessage, commitDate };
  } catch (err) {
    return {
      commitSha: 'HEAD',
      branch: 'main',
      lastAuthor: 'Automated CI/CD',
      lastMessage: 'Live Documentation Sync',
      commitDate: new Date().toISOString()
    };
  }
}

function updateDocument(filePath, gitInfo, docTitle) {
  if (!fs.existsSync(filePath)) {
    console.warn(`⚠️ ${filePath} not found, skipping.`);
    return;
  }

  let content = fs.readFileSync(filePath, 'utf8');
  const now = new Date();
  const formattedDate = now.toISOString().replace('T', ' ').substring(0, 19) + ' UTC';

  const metadataBlock = `<!-- LIVING_DOC_METADATA_START -->
> [!NOTE]
> **Live Document Status**: Synchronized with GitHub Repository  
> **Repository**: [Sameh1122/bassem_sales](https://github.com/Sameh1122/bassem_sales)  
> **Last Synchronized**: ${formattedDate}  
> **Active Branch**: \`${gitInfo.branch}\`  
> **Latest Commit**: [\`${gitInfo.commitSha}\`](https://github.com/Sameh1122/bassem_sales/commit/${gitInfo.commitSha}) — *"${gitInfo.lastMessage}"*  
> **Author**: ${gitInfo.lastAuthor}  
> **Status**: Production Ready & Actively Maintained  
<!-- LIVING_DOC_METADATA_END -->`;

  const regex = /<!-- LIVING_DOC_METADATA_START -->[\s\S]*?<!-- LIVING_DOC_METADATA_END -->/;
  if (regex.test(content)) {
    content = content.replace(regex, metadataBlock);
  } else {
    // If tag not present, inject after first H2 header
    const h2Index = content.indexOf('## ');
    if (h2Index !== -1) {
      const nextLine = content.indexOf('\n', h2Index);
      content = content.slice(0, nextLine + 1) + '\n' + metadataBlock + '\n' + content.slice(nextLine + 1);
    } else {
      content = metadataBlock + '\n\n' + content;
    }
  }

  fs.writeFileSync(filePath, content, 'utf8');
  console.log(`✅ Updated live sync banner in ${path.basename(filePath)}`);
}

function run() {
  console.log('====================================================');
  console.log('🔄 Running Bassem Sales Living Docs Synchronizer');
  console.log('====================================================');

  const gitInfo = getGitInfo();
  console.log(`📌 Git Context: ${gitInfo.branch}@${gitInfo.commitSha} (${gitInfo.lastMessage})`);

  updateDocument(path.join(docsDir, 'BRD.md'), gitInfo, 'Business Requirements Document');
  updateDocument(path.join(docsDir, 'SAD.md'), gitInfo, 'Solution Architecture Document');

  console.log('✨ All live documents synchronized with repository state.\n');
}

run();
