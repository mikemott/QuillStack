/**
 * KV Store helper functions for health metrics persistence
 */

import { WorkerHealthState, HealthMetrics } from './types';

const KV_PREFIX = {
  STATE: 'state:',
  METRICS: 'metrics:',
  RECENT_ISSUE: 'recent_issue:'
};

/**
 * Get health state for a worker from KV
 */
export async function getWorkerState(
  kv: KVNamespace,
  workerName: string
): Promise<WorkerHealthState | null> {
  const key = `${KV_PREFIX.STATE}${workerName}`;
  const value = await kv.get(key, 'json');
  return value as WorkerHealthState | null;
}

/**
 * Save health state for a worker to KV
 */
export async function saveWorkerState(
  kv: KVNamespace,
  state: WorkerHealthState
): Promise<void> {
  const key = `${KV_PREFIX.STATE}${state.workerName}`;
  await kv.put(key, JSON.stringify(state));
}

/**
 * Get health metrics for a worker from KV
 */
export async function getWorkerMetrics(
  kv: KVNamespace,
  workerName: string
): Promise<HealthMetrics | null> {
  const key = `${KV_PREFIX.METRICS}${workerName}`;
  const value = await kv.get(key, 'json');
  return value as HealthMetrics | null;
}

/**
 * Update health metrics for a worker in KV
 */
export async function updateWorkerMetrics(
  kv: KVNamespace,
  workerName: string,
  success: boolean,
  responseTimeMs: number
): Promise<void> {
  const key = `${KV_PREFIX.METRICS}${workerName}`;

  // Get existing metrics or create new
  const existing = await getWorkerMetrics(kv, workerName);

  const totalChecks = (existing?.totalChecks || 0) + 1;
  const failedChecks = (existing?.failedChecks || 0) + (success ? 0 : 1);
  const successfulChecks = totalChecks - failedChecks;

  // Calculate rolling average response time (only for successful checks)
  let averageResponseTimeMs = existing?.averageResponseTimeMs || 0;
  if (success && successfulChecks > 0) {
    const previousTotal = (existing?.averageResponseTimeMs || 0) * (successfulChecks - 1);
    averageResponseTimeMs = (previousTotal + responseTimeMs) / successfulChecks;
  }

  const metrics: HealthMetrics = {
    workerName,
    uptimePercentage: (successfulChecks / totalChecks) * 100,
    averageResponseTimeMs,
    totalChecks,
    failedChecks,
    lastUpdated: new Date().toISOString()
  };

  await kv.put(key, JSON.stringify(metrics));
}

/**
 * Check if we recently created an issue for this worker (within last hour)
 * This prevents duplicate issue creation for the same ongoing problem
 */
export async function hasRecentIssue(
  kv: KVNamespace,
  workerName: string,
  withinMinutes: number = 60
): Promise<boolean> {
  const state = await getWorkerState(kv, workerName);

  if (!state?.recentIssueCreatedAt) {
    return false;
  }

  const issueCreatedAt = new Date(state.recentIssueCreatedAt);
  const now = new Date();
  const minutesSinceIssue = (now.getTime() - issueCreatedAt.getTime()) / (1000 * 60);

  return minutesSinceIssue < withinMinutes;
}

/**
 * Record that an issue was created for a worker
 */
export async function recordIssueCreated(
  kv: KVNamespace,
  workerName: string,
  issueId: string
): Promise<void> {
  const state = await getWorkerState(kv, workerName);

  if (state) {
    state.recentIssueId = issueId;
    state.recentIssueCreatedAt = new Date().toISOString();
    await saveWorkerState(kv, state);
  }
}
