#!/usr/bin/env node
/**
 * Firestore export utility for Crystal Grimoire.
 * Dumps critical collections to JSON so they can be backed up or inspected
 * during production incidents. Designed to run with `GOOGLE_APPLICATION_CREDENTIALS`
 * or an explicit service account file.
 */

const { existsSync, mkdirSync, readFileSync, writeFileSync } = require('node:fs');
const { join, resolve } = require('node:path');
const { initializeApp, applicationDefault, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    const [key, value] = argv[i].split('=');
    switch (key) {
      case '--project':
        args.project = value || argv[++i];
        break;
      case '--collections':
        args.collections = (value || argv[++i] || '')
          .split(',')
          .map((entry) => entry.trim())
          .filter(Boolean);
        break;
      case '--output':
        args.output = value || argv[++i];
        break;
      case '--serviceAccount':
        args.serviceAccount = value || argv[++i];
        break;
      case '--help':
      case '-h':
        args.help = true;
        break;
      default:
        break;
    }
  }
  return args;
}

function printHelp() {
  console.log(`Usage: node scripts/export_firestore.js --project <project-id> [options]\n\nOptions:\n  --collections <list>   Comma separated collection ids (default: users,crystal_library,marketplace,plans,feature_flags)\n  --output <path>        Destination directory (default: backups/<project-id>-<timestamp>)\n  --serviceAccount <path> Service account JSON file (defaults to application default credentials)\n`);
}

function serialiseValue(value) {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value === 'object') {
    if (value.toDate instanceof Function) {
      return value.toDate().toISOString();
    }
    if (value instanceof Date) {
      return value.toISOString();
    }
    if (Array.isArray(value)) {
      return value.map(serialiseValue);
    }
    const result = {};
    Object.keys(value).forEach((key) => {
      result[key] = serialiseValue(value[key]);
    });
    return result;
  }
  return value;
}

async function exportCollection(db, collectionId, destination) {
  const snapshot = await db.collection(collectionId).get();
  const serialised = snapshot.docs.map((doc) => ({
    id: doc.id,
    data: serialiseValue(doc.data()),
  }));
  writeFileSync(destination, JSON.stringify(serialised, null, 2));
  console.log(`✓ Exported ${serialised.length} documents from ${collectionId} → ${destination}`);
}

async function main() {
  const args = parseArgs(process.argv);

  if (args.help || !args.project) {
    printHelp();
    process.exit(args.help ? 0 : 1);
  }

  const collections = args.collections && args.collections.length > 0
    ? args.collections
    : ['users', 'crystal_library', 'marketplace', 'plans', 'feature_flags'];

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const outputDir = resolve(args.output || join('backups', `${args.project}-${timestamp}`));
  if (!existsSync(outputDir)) {
    mkdirSync(outputDir, { recursive: true });
  }

  const appOptions = {
    projectId: args.project,
    credential: applicationDefault(),
  };

  if (args.serviceAccount) {
    const serviceAccountPath = resolve(args.serviceAccount);
    const raw = readFileSync(serviceAccountPath, 'utf8');
    appOptions.credential = cert(JSON.parse(raw));
  }

  initializeApp(appOptions);
  const db = getFirestore();

  for (const collectionId of collections) {
    try {
      const destination = join(outputDir, `${collectionId}.json`);
      // eslint-disable-next-line no-await-in-loop
      await exportCollection(db, collectionId, destination);
    } catch (error) {
      console.error(`Failed to export collection ${collectionId}:`, error.message);
    }
  }

  console.log('Firestore export completed.');
}

main().catch((error) => {
  console.error('Unexpected failure during Firestore export:', error);
  process.exit(1);
});
