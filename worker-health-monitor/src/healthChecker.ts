/**
 * Core health checking logic for workers
 */

import { WorkerConfig, HealthCheckResult, WorkerHealthState, Env } from './types';
import { getWorkerState, saveWorkerState, updateWorkerMetrics, hasRecentIssue, recordIssueCreated } from './kvStore';
import { createHealthAlertIssue, HealthAlert } from './linearClient';
import { trackHealthMetric, trackAlertCreated } from './amplitudeClient';

/**
 * Perform health check on a single worker
 */
export async function checkWorkerHealth(
  config: WorkerConfig
): Promise<HealthCheckResult> {
  const startTime = Date.now();
  const timestamp = new Date().toISOString();

  try {
    const endpoint = config.healthEndpoint || config.url;
    const response = await fetch(endpoint, {
      method: 'GET',
      headers: {
        'User-Agent': 'QuillStack-Health-Monitor/1.0'
      }
    });

    const responseTimeMs = Date.now() - startTime;

    return {
      workerName: config.name,
      success: response.ok,
      responseTimeMs,
      statusCode: response.status,
      timestamp
    };
  } catch (error) {
    const responseTimeMs = Date.now() - startTime;
    return {
      workerName: config.name,
      success: false,
      responseTimeMs,
      error: error instanceof Error ? error.message : 'Unknown error',
      timestamp
    };
  }
}

/**
 * Process health check result and update state
 */
export async function processHealthCheckResult(
  result: HealthCheckResult,
  env: Env
): Promise<void> {
  // Get current state from KV
  let state = await getWorkerState(env.HEALTH_METRICS, result.workerName);

  if (!state) {
    // Initialize new state
    state = {
      workerName: result.workerName,
      consecutiveFailures: 0,
      lastCheckTime: result.timestamp
    };
  }

  // Update state based on result
  state.lastCheckTime = result.timestamp;

  if (result.success) {
    state.consecutiveFailures = 0;
    state.lastSuccessTime = result.timestamp;
    state.slowResponseStartTime = undefined;
  } else {
    state.consecutiveFailures += 1;
  }

  // Check for slow response times
  if (result.success && result.responseTimeMs > env.RESPONSE_TIME_THRESHOLD_MS) {
    if (!state.slowResponseStartTime) {
      state.slowResponseStartTime = result.timestamp;
    }
  } else if (result.responseTimeMs <= env.RESPONSE_TIME_THRESHOLD_MS) {
    state.slowResponseStartTime = undefined;
  }

  // Save updated state
  await saveWorkerState(env.HEALTH_METRICS, state);

  // Update metrics
  await updateWorkerMetrics(
    env.HEALTH_METRICS,
    result.workerName,
    result.success,
    result.responseTimeMs
  );

  // Track in Amplitude
  try {
    await trackHealthMetric(
      {
        workerName: result.workerName,
        success: result.success,
        responseTimeMs: result.responseTimeMs,
        consecutiveFailures: state.consecutiveFailures,
        statusCode: result.statusCode,
        timestamp: result.timestamp
      },
      env.AMPLITUDE_API_KEY
    );
  } catch (error) {
    console.warn(`Failed to track health metric in Amplitude:`, error);
  }

  // Check if we need to create alerts
  await checkAndCreateAlerts(result, state, env);
}

/**
 * Check if alerts need to be created based on thresholds
 */
async function checkAndCreateAlerts(
  result: HealthCheckResult,
  state: WorkerHealthState,
  env: Env
): Promise<void> {
  // Check for consecutive failures
  if (state.consecutiveFailures >= env.MAX_CONSECUTIVE_FAILURES) {
    // Avoid duplicate issues
    const hasRecent = await hasRecentIssue(env.HEALTH_METRICS, result.workerName, 60);
    if (!hasRecent) {
      await createConsecutiveFailureAlert(result, state, env);
    }
    return;
  }

  // Check for sustained slow response times
  if (state.slowResponseStartTime) {
    const slowDurationMs = new Date(result.timestamp).getTime() -
                          new Date(state.slowResponseStartTime).getTime();
    const slowDurationMin = slowDurationMs / (1000 * 60);

    if (slowDurationMin >= env.SUSTAINED_SLOW_DURATION_MIN) {
      const hasRecent = await hasRecentIssue(env.HEALTH_METRICS, result.workerName, 60);
      if (!hasRecent) {
        await createSlowResponseAlert(result, state, slowDurationMin, env);
      }
    }
  }
}

/**
 * Create Linear issue for consecutive failures
 */
async function createConsecutiveFailureAlert(
  result: HealthCheckResult,
  state: WorkerHealthState,
  env: Env
): Promise<void> {
  const alert: HealthAlert = {
    workerName: result.workerName,
    alertType: 'consecutive_failures',
    details: {
      consecutiveFailures: state.consecutiveFailures,
      lastError: result.error
    },
    timestamp: result.timestamp
  };

  try {
    // Get team ID from Linear (you'll need to configure this)
    // For now, using a placeholder - will need to be configured in wrangler.toml
    const teamId = 'e2da77ea-ff59-46e5-b777-9bf4dd7c855d'; // QuillStack team ID

    const issue = await createHealthAlertIssue(
      alert,
      env.LINEAR_API_KEY,
      teamId
    );

    console.log(`Created Linear issue ${issue.identifier} for consecutive failures on ${result.workerName}`);

    // Record that we created an issue
    await recordIssueCreated(env.HEALTH_METRICS, result.workerName, issue.identifier);

    // Track in Amplitude
    await trackAlertCreated(
      result.workerName,
      'consecutive_failures',
      issue.identifier,
      env.AMPLITUDE_API_KEY
    );
  } catch (error) {
    console.error(`Failed to create Linear issue:`, error);
  }
}

/**
 * Create Linear issue for sustained slow response times
 */
async function createSlowResponseAlert(
  result: HealthCheckResult,
  state: WorkerHealthState,
  durationMin: number,
  env: Env
): Promise<void> {
  const alert: HealthAlert = {
    workerName: result.workerName,
    alertType: 'sustained_slow_response',
    details: {
      responseTimeMs: result.responseTimeMs,
      duration: Math.round(durationMin)
    },
    timestamp: result.timestamp
  };

  try {
    const teamId = 'e2da77ea-ff59-46e5-b777-9bf4dd7c855d'; // QuillStack team ID

    const issue = await createHealthAlertIssue(
      alert,
      env.LINEAR_API_KEY,
      teamId
    );

    console.log(`Created Linear issue ${issue.identifier} for slow response on ${result.workerName}`);

    await recordIssueCreated(env.HEALTH_METRICS, result.workerName, issue.identifier);

    await trackAlertCreated(
      result.workerName,
      'sustained_slow_response',
      issue.identifier,
      env.AMPLITUDE_API_KEY
    );
  } catch (error) {
    console.error(`Failed to create Linear issue:`, error);
  }
}
