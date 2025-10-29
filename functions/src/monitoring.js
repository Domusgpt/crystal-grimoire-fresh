const { logger } = require('firebase-functions');

function formatContext(request) {
  if (!request) {
    return {};
  }
  return {
    uid: request.auth?.uid || null,
    app: request.rawRequest?.headers?.['x-app-version'] || null,
    region: request.rawRequest?.headers?.['x-app-region'] || null,
  };
}

function logFunctionStart(functionName, request, extra = {}) {
  logger.info(`▶️  ${functionName} invoked`, {
    functionName,
    stage: 'start',
    ...formatContext(request),
    ...extra,
  });
}

function logFunctionSuccess(functionName, request, extra = {}) {
  logger.info(`✅ ${functionName} succeeded`, {
    functionName,
    stage: 'success',
    ...formatContext(request),
    ...extra,
  });
}

function logFunctionError(functionName, error, request, extra = {}) {
  logger.error(`❌ ${functionName} failed`, {
    functionName,
    stage: 'error',
    message: error?.message || String(error),
    stack: error?.stack,
    ...formatContext(request),
    ...extra,
  });
}

function withMonitoring(functionName, handler) {
  return async (request, ...rest) => {
    logFunctionStart(functionName, request);
    const start = process.hrtime.bigint();
    try {
      const response = await handler(request, ...rest);
      const end = process.hrtime.bigint();
      const durationMs = Number(end - start) / 1_000_000;
      logFunctionSuccess(functionName, request, {
        durationMs: Number.isFinite(durationMs) ? Number(durationMs.toFixed(2)) : null,
      });
      return response;
    } catch (error) {
      const end = process.hrtime.bigint();
      const durationMs = Number(end - start) / 1_000_000;
      logFunctionError(functionName, error, request, {
        durationMs: Number.isFinite(durationMs) ? Number(durationMs.toFixed(2)) : null,
      });
      throw error;
    }
  };
}

module.exports = {
  logFunctionStart,
  logFunctionSuccess,
  logFunctionError,
  withMonitoring,
};
