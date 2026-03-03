#!/usr/bin/env node
// Prisma auto-generate hook
// Runs `pnpm exec prisma generate` after schema.prisma is edited/written

import { execSync } from 'child_process';

let input = '';
process.stdin.on('data', chunk => { input += chunk; });
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const toolInput = data.tool_input || data.toolInput || {};
    const filePath = toolInput.file_path || toolInput.filePath || '';

    if (!filePath.endsWith('schema.prisma')) {
      console.log(JSON.stringify({ continue: true, suppressOutput: true }));
      return;
    }

    const cwd = data.cwd || data.directory || process.cwd();
    try {
      execSync('pnpm exec prisma generate 2>&1 | tail -1', {
        cwd,
        timeout: 15000,
        stdio: ['pipe', 'pipe', 'pipe']
      });
      console.log(JSON.stringify({
        continue: true,
        message: 'Prisma client auto-generated after schema.prisma edit.'
      }));
    } catch {
      console.log(JSON.stringify({
        continue: true,
        message: 'Prisma generate failed — run manually if needed.'
      }));
    }
  } catch {
    console.log(JSON.stringify({ continue: true, suppressOutput: true }));
  }
});
