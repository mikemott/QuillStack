/**
 * Worker Health Monitor
 * Cloudflare Worker with cron trigger to monitor health of other workers
 */

import { Env, WorkerConfig } from './types';
import { checkWorkerHealth, processHealthCheckResult } from './healthChecker';

/**
 * Main worker export with scheduled event handler
 */
export default {
  /**
   * Scheduled event handler - runs on cron trigger (every 5 minutes)
   */
  async scheduled(
    event: ScheduledEvent,
    env: Env,
    ctx: ExecutionContext
  ): Promise<void> {
    console.log(`Health check triggered at ${new Date().toISOString()}`);

    // Define workers to monitor
    const workersToMonitor: WorkerConfig[] = [
      {
        name: 'testflight-welcome-worker',
        url: env.TESTFLIGHT_WORKER_URL
      },
      {
        name: 'api-proxy-worker',
        url: env.API_PROXY_WORKER_URL
      }
    ];

    // Check all workers in parallel
    const healthCheckPromises = workersToMonitor.map(async (config) => {
      try {
        const result = await checkWorkerHealth(config);
        await processHealthCheckResult(result, env);

        console.log(`✓ ${config.name}: ${result.success ? 'OK' : 'FAILED'} (${result.responseTimeMs}ms)`);
      } catch (error) {
        console.error(`Error checking ${config.name}:`, error);
      }
    });

    // Wait for all checks to complete
    await Promise.all(healthCheckPromises);

    console.log('Health check completed');
  },

  /**
   * HTTP request handler for manual testing and status queries
   */
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext
  ): Promise<Response> {
    const url = new URL(request.url);

    // Health endpoint for the monitor itself
    if (url.pathname === '/health' || url.pathname === '/') {
      return new Response(
        JSON.stringify({
          status: 'ok',
          service: 'worker-health-monitor',
          timestamp: new Date().toISOString()
        }),
        {
          headers: { 'Content-Type': 'application/json' }
        }
      );
    }

    // Manual trigger endpoint for testing (requires authentication)
    if (url.pathname === '/check-now' && request.method === 'POST') {
      // Verify API key
      const apiKeyHeader = request.headers.get('X-Manual-Trigger-Key');
      if (!apiKeyHeader || apiKeyHeader !== env.MANUAL_TRIGGER_API_KEY) {
        return new Response(
          JSON.stringify({ error: 'Unauthorized' }),
          {
            status: 401,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }

      try {
        // Trigger a health check immediately (useful for testing)
        const workersToMonitor: WorkerConfig[] = [
          {
            name: 'testflight-welcome-worker',
            url: env.TESTFLIGHT_WORKER_URL
          },
          {
            name: 'api-proxy-worker',
            url: env.API_PROXY_WORKER_URL
          }
        ];

        const results = await Promise.all(
          workersToMonitor.map(async (config) => {
            const result = await checkWorkerHealth(config);
            await processHealthCheckResult(result, env);
            // Sanitize error messages before returning
            return {
              workerName: result.workerName,
              success: result.success,
              responseTimeMs: result.responseTimeMs,
              statusCode: result.statusCode,
              // Don't expose detailed error messages to clients
              hasError: !!result.error
            };
          })
        );

        return new Response(
          JSON.stringify({
            message: 'Health check completed',
            results,
            timestamp: new Date().toISOString()
          }),
          {
            headers: { 'Content-Type': 'application/json' }
          }
        );
      } catch (error) {
        // Don't expose internal error details
        console.error('Error in manual health check:', error);
        return new Response(
          JSON.stringify({ error: 'Internal server error' }),
          {
            status: 500,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }
    }

    // Get metrics for a specific worker (requires authentication)
    if (url.pathname.startsWith('/metrics/')) {
      // Verify API key
      const apiKeyHeader = request.headers.get('X-Manual-Trigger-Key');
      if (!apiKeyHeader || apiKeyHeader !== env.MANUAL_TRIGGER_API_KEY) {
        return new Response(
          JSON.stringify({ error: 'Unauthorized' }),
          {
            status: 401,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }

      const workerName = url.pathname.split('/metrics/')[1];

      if (!workerName) {
        return new Response(
          JSON.stringify({ error: 'Worker name required' }),
          {
            status: 400,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }

      // Validate worker name to prevent KV key injection
      const validWorkerNames = ['testflight-welcome-worker', 'api-proxy-worker'];
      if (!validWorkerNames.includes(workerName)) {
        return new Response(
          JSON.stringify({ error: 'Invalid worker name' }),
          {
            status: 400,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }

      try {
        const stateKey = `state:${workerName}`;
        const metricsKey = `metrics:${workerName}`;

        const [state, metrics] = await Promise.all([
          env.HEALTH_METRICS.get(stateKey, 'json'),
          env.HEALTH_METRICS.get(metricsKey, 'json')
        ]);

        return new Response(
          JSON.stringify({
            workerName,
            state,
            metrics,
            timestamp: new Date().toISOString()
          }),
          {
            headers: { 'Content-Type': 'application/json' }
          }
        );
      } catch (error) {
        console.error('Error fetching metrics:', error);
        return new Response(
          JSON.stringify({ error: 'Internal server error' }),
          {
            status: 500,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }
    }

    return new Response('Not Found', { status: 404 });
  }
};
