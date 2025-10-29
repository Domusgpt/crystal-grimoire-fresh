# Crystal Grimoire Operations Runbook

This runbook captures the day-two workflows introduced for production hardening. Keep it alongside `DEPLOYMENT_GUIDE.md` and `docs/RELEASE_PLAN.md` when responding to incidents or planning SRE automation.

## 1. Monitoring & Alerting
- **Client telemetry**: `MonitoringService` initialises when Firebase is available and records `app_boot`, callable timings, and uncaught Flutter errors to Firebase Analytics. Confirm the property is linked to BigQuery so you can construct dashboards for engagement and crash rates.【F:lib/services/monitoring_service.dart†L1-L152】【F:lib/main.dart†L1-L70】
- **Server telemetry**: All critical Cloud Functions are wrapped with `withMonitoring`, emitting start/success/error logs (including durations) to Cloud Logging. Create log-based metrics on the `callable_invocation` event for latency/error alerts and route Stripe webhook failures to PagerDuty.【F:functions/src/monitoring.js†L1-L63】【F:functions/index.js†L116-L205】【F:functions/index.js†L325-L339】
- **Health checks**: `healthCheck` callable remains public; wire it into uptime monitors and alert if status != `healthy`.【F:functions/index.js†L170-L189】

## 2. Backup & Recovery
- **Ad-hoc exports**: Use `npm run export:firestore -- --project <id> --serviceAccount path/to/key.json` to generate JSON dumps under `backups/<project>-<timestamp>/`. This captures `users`, `crystal_library`, `marketplace`, `plans`, and `feature_flags` by default; pass `--collections` to target others.【F:scripts/export_firestore.js†L1-L147】
- **Scheduling**: Add the command to a nightly GitHub Actions workflow or Cloud Scheduler job with Workload Identity. Store artefacts in Cloud Storage with Object Versioning so you can roll back corrupted data quickly.
- **Restoration**: To restore a collection, iterate over the JSON and use `firebase firestore:delete` followed by a scripted import (extend `scripts/seed_database.js` or write a dedicated restore helper). Document any manual steps taken during incidents.

## 3. Incident Workflow
1. **Triage**
   - Check Cloud Logging for `❌` entries from monitored functions. Inspect the structured payload (`durationMs`, `uid`, `message`).
   - Review Firebase Analytics dashboards for spikes in `client_exception` events or drop-offs in `callable_invocation` success counts.
2. **Mitigation**
   - For callable failures, temporarily disable the affected feature via `EnvironmentConfig` flags (`ENABLE_ECONOMY_FUNCTIONS`, `ENABLE_STRIPE_CHECKOUT`) while investigating.【F:lib/services/environment_config.dart†L1-L200】
   - If Stripe webhooks back up, use the logged event IDs to replay via `stripe events resend <id>` after fixing configuration.
3. **Post-Incident**
   - Export a data snapshot for records using the backup script.
   - File a retro entry in `DEVELOPER_HANDOFF.me` summarising the issue and follow-up tasks.

## 4. Support & Ticketing
- **Intake**: `createSupportTicket` callable stores the original request with an auto-generated comment. Customers can reply through the app, while support/ops users (custom claims `role=admin` or `roles/support`) can add public or internal comments via the admin tooling or CLI.【F:functions/index.js†L1900-L2047】
- **Triage**: Use the support CLI for quick filters and assignments:
  ```bash
  FIREBASE_PROJECT_ID=<project> GOOGLE_APPLICATION_CREDENTIALS=./admin.json \
    node scripts/support_ticket_cli.js list --status=pending_support
  node scripts/support_ticket_cli.js assign <ticketId> <uid>
  node scripts/support_ticket_cli.js close <ticketId>
  ```
  This script relies on the same helper library as the Functions, so priority/status validation stays consistent.【F:scripts/support_ticket_cli.js†L1-L196】【F:functions/src/support.js†L1-L108】
- **Audit trails**: `addSupportTicketComment` enforces status transitions (`pending_support` vs `pending_user`) automatically; admins can override via `updateSupportTicketStatus` if a ticket requires manual escalation. Review the `comments` subcollection for the conversation history during postmortems.【F:functions/index.js†L2049-L2148】
- **Permissions**: Firestore rules restrict ticket visibility to the submitter and admins while blocking direct comment writes from clients; use the callable endpoints exclusively to maintain validation and telemetry.【F:firestore.rules†L200-L260】【F:functions/test/security.rules.test.js†L120-L210】

## 5. Pre-Release Checklist Additions
- Verify monitoring dashboards show traffic for `identifyCrystal`, `analyzeDream`, and Stripe flows after staging load tests.
- Confirm the backup workflow produces artefacts and that they pass a manual restore dry-run.
- Update onboarding docs with alert runbooks and ensure support staff can interpret the analytics dashboards.

_Maintain this runbook as instrumentation evolves; link to any future PagerDuty/Statuspage integrations here._
