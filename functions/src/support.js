'use strict';

const ALLOWED_PRIORITIES = new Set(['low', 'medium', 'high']);
const ALLOWED_STATUSES = new Set([
  'open',
  'pending_support',
  'pending_user',
  'resolved',
  'closed',
]);

const SUPPORT_TRANSITIONS = {
  open: ['pending_support', 'pending_user', 'resolved', 'closed'],
  pending_support: ['pending_user', 'resolved', 'closed'],
  pending_user: ['pending_support', 'resolved', 'closed'],
  resolved: ['pending_support', 'pending_user', 'closed'],
  closed: ['pending_support'],
};

const CUSTOMER_TRANSITIONS = {
  open: ['pending_support', 'closed'],
  pending_support: ['closed'],
  pending_user: ['pending_support', 'closed'],
  resolved: ['pending_support', 'closed'],
  closed: [],
};

function normalizePriority(priority) {
  if (!priority) {
    return 'medium';
  }
  const normalized = String(priority).trim().toLowerCase();
  if (ALLOWED_PRIORITIES.has(normalized)) {
    return normalized;
  }
  return 'medium';
}

function assertValidSupportStatus(status) {
  if (!status && status !== '') {
    throw new Error('status is required');
  }
  const normalized = String(status).trim().toLowerCase();
  if (!ALLOWED_STATUSES.has(normalized)) {
    throw new Error(`Unsupported status: ${status}`);
  }
  return normalized;
}

function isSupportAgent(claims = {}) {
  const roles = Array.isArray(claims.roles) ? claims.roles : [];
  const groups = Array.isArray(claims.groups) ? claims.groups : [];
  return Boolean(
    claims.role === 'admin' ||
    claims.admin === true ||
    claims.support === true ||
    roles.includes('admin') ||
    roles.includes('support') ||
    roles.includes('operations') ||
    groups.includes('admin') ||
    groups.includes('support') ||
    groups.includes('operations')
  );
}

function canTransitionStatus(currentStatus, nextStatus, bySupportAgent) {
  const from = assertValidSupportStatus(currentStatus || 'open');
  const to = assertValidSupportStatus(nextStatus);
  if (from === to) {
    return true;
  }
  const transitions = bySupportAgent ? SUPPORT_TRANSITIONS : CUSTOMER_TRANSITIONS;
  const allowed = transitions[from] || [];
  return allowed.includes(to);
}

function computeNextStatusOnComment(currentStatus, authorRole) {
  const normalizedStatus = assertValidSupportStatus(currentStatus || 'open');
  const normalizedRole = authorRole === 'support' ? 'support' : 'customer';

  if (normalizedRole === 'support') {
    if (normalizedStatus === 'resolved' || normalizedStatus === 'closed') {
      return normalizedStatus;
    }
    return 'pending_user';
  }

  if (normalizedStatus === 'resolved') {
    return 'open';
  }
  if (normalizedStatus === 'pending_user') {
    return 'pending_support';
  }
  if (normalizedStatus === 'closed') {
    return 'closed';
  }
  return 'pending_support';
}

module.exports = {
  normalizePriority,
  assertValidSupportStatus,
  isSupportAgent,
  canTransitionStatus,
  computeNextStatusOnComment,
  ALLOWED_PRIORITIES,
  ALLOWED_STATUSES,
};
