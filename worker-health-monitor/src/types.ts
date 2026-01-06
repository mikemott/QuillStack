/**
 * Type definitions for the health monitoring worker
 */

export interface Env {
  // KV namespace for storing metrics
  HEALTH_METRICS: KVNamespace;

  // Worker URLs to monitor
  TESTFLIGHT_WORKER_URL: string;
  API_PROXY_WORKER_URL: string;

  // Thresholds
  MAX_CONSECUTIVE_FAILURES: number;
  RESPONSE_TIME_THRESHOLD_MS: number;
  SUSTAINED_SLOW_DURATION_MIN: number;

  // API Keys (secrets)
  LINEAR_API_KEY: string;
  AMPLITUDE_API_KEY: string;
}

export interface WorkerConfig {
  name: string;
  url: string;
  healthEndpoint?: string; // Optional specific health endpoint, defaults to root
}

export interface HealthCheckResult {
  workerName: string;
  success: boolean;
  responseTimeMs: number;
  statusCode?: number;
  error?: string;
  timestamp: string;
}

export interface WorkerHealthState {
  workerName: string;
  consecutiveFailures: number;
  lastCheckTime: string;
  lastSuccessTime?: string;
  slowResponseStartTime?: string; // When sustained slow responses started
  recentIssueId?: string; // Most recent Linear issue created for this worker
  recentIssueCreatedAt?: string; // When the most recent issue was created
}

export interface HealthMetrics {
  workerName: string;
  uptimePercentage: number;
  averageResponseTimeMs: number;
  totalChecks: number;
  failedChecks: number;
  lastUpdated: string;
}
