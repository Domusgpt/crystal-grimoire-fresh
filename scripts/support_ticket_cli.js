#!/usr/bin/env node

/**
 * Support Ticket CLI
 *
 * Simple operations utility for Crystal Grimoire support staff.
 * Requires FIREBASE_PROJECT_ID and optional GOOGLE_APPLICATION_CREDENTIALS.
 */

const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { initializeApp, applicationDefault, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const {
  normalizePriority,
  assertValidSupportStatus,
  canTransitionStatus,
} = require('../functions/src/support');

function logUsage() {
  console.log(`\nUsage:\n  node scripts/support_ticket_cli.js list [--status=<status>] [--priority=<priority>]\n  node scripts/support_ticket_cli.js close <ticketId>\n  node scripts/support_ticket_cli.js assign <ticketId> <assigneeId>\n`);
}

function bootstrap() {
  const projectId = process.env.FIREBASE_PROJECT_ID || process.env.GCLOUD_PROJECT;
  if (!projectId) {
    console.error('FIREBASE_PROJECT_ID env var is required.');
    process.exit(1);
  }

  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const options = { projectId };

  if (serviceAccountPath) {
    try {
      const credentials = JSON.parse(readFileSync(resolve(serviceAccountPath), 'utf8'));
      options.credential = cert(credentials);
    } catch (error) {
      console.warn('⚠️ Failed to load service account JSON, falling back to application default.', error.message);
      options.credential = applicationDefault();
    }
  } else {
    options.credential = applicationDefault();
  }

  initializeApp(options);
  return getFirestore();
}

async function listTickets(db, filters) {
  let query = db.collection('support_tickets').orderBy('lastActivityAt', 'desc').limit(25);

  if (filters.status) {
    query = query.where('status', '==', assertValidSupportStatus(filters.status));
  }

  if (filters.priority) {
    query = query.where('priority', '==', normalizePriority(filters.priority));
  }

  const snapshot = await query.get();
  if (snapshot.empty) {
    console.log('No tickets found for the specified filters.');
    return;
  }

  console.log(`\nFound ${snapshot.size} ticket(s):\n`);
  snapshot.docs.forEach((doc) => {
    const data = doc.data();
    const updatedAt = data.lastActivityAt instanceof Timestamp ? data.lastActivityAt.toDate().toISOString() : 'unknown';
    console.log(`- ${doc.id} | ${data.status} | ${data.priority} | user: ${data.userId} | updated: ${updatedAt}`);
    console.log(`  subject: ${data.subject}`);
    if (data.assigneeId) {
      console.log(`  assignee: ${data.assigneeId}`);
    }
    if (Array.isArray(data.tags) && data.tags.length > 0) {
      console.log(`  tags: ${data.tags.join(', ')}`);
    }
    console.log('');
  });
}

async function closeTicket(db, ticketId) {
  const ref = db.collection('support_tickets').doc(ticketId);
  const snapshot = await ref.get();
  if (!snapshot.exists) {
    throw new Error(`Ticket ${ticketId} not found.`);
  }

  const data = snapshot.data() || {};
  if (!canTransitionStatus(data.status || 'open', 'closed', true)) {
    throw new Error(`Ticket ${ticketId} cannot transition from ${data.status} to closed.`);
  }

  await ref.update({
    status: 'closed',
    updatedAt: Timestamp.now(),
    lastActivityAt: Timestamp.now(),
  });

  console.log(`✅ Ticket ${ticketId} closed.`);
}

async function assignTicket(db, ticketId, assigneeId) {
  if (!assigneeId) {
    throw new Error('assigneeId is required for assign command.');
  }

  const ref = db.collection('support_tickets').doc(ticketId);
  const snapshot = await ref.get();
  if (!snapshot.exists) {
    throw new Error(`Ticket ${ticketId} not found.`);
  }

  await ref.update({
    assigneeId,
    updatedAt: Timestamp.now(),
    lastActivityAt: Timestamp.now(),
  });

  console.log(`✅ Ticket ${ticketId} assigned to ${assigneeId}.`);
}

async function run() {
  const [, , command, ...args] = process.argv;
  if (!command) {
    logUsage();
    process.exit(1);
  }

  const db = bootstrap();

  try {
    if (command === 'list') {
      const filters = {};
      args.forEach((arg) => {
        const [key, value] = arg.split('=');
        if (key === '--status') {
          filters.status = value;
        } else if (key === '--priority') {
          filters.priority = value;
        }
      });
      await listTickets(db, filters);
    } else if (command === 'close') {
      const [ticketId] = args;
      if (!ticketId) {
        throw new Error('Ticket ID is required for close command.');
      }
      await closeTicket(db, ticketId);
    } else if (command === 'assign') {
      const [ticketId, assigneeId] = args;
      if (!ticketId || !assigneeId) {
        throw new Error('Ticket ID and assigneeId are required for assign command.');
      }
      await assignTicket(db, ticketId, assigneeId);
    } else {
      throw new Error(`Unknown command: ${command}`);
    }
  } catch (error) {
    console.error(`❌ ${error.message}`);
    process.exitCode = 1;
  }
}

run();
