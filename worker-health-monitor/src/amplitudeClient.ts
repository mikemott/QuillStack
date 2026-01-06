/**
 * Amplitude HTTP API Client
 * Tracks worker health metrics events
 */

export interface HealthMetricEvent {
  workerName: string;
  success: boolean;
  responseTimeMs: number;
  consecutiveFailures?: number;
  statusCode?: number;
  timestamp: string;
}

/**
 * Track worker health check event in Amplitude
 */
export async function trackHealthMetric(
  event: HealthMetricEvent,
  apiKey: string
): Promise<void> {
  const amplitudeEvent = {
    api_key: apiKey,
    events: [{
      event_type: 'worker_health_check',
      user_id: 'system',
      event_properties: {
        worker_name: event.workerName,
        success: event.success,
        response_time_ms: event.responseTimeMs,
        consecutive_failures: event.consecutiveFailures || 0,
        status_code: event.statusCode
      },
      time: new Date(event.timestamp).getTime()
    }]
  };

  const response = await fetch('https://api2.amplitude.com/2/httpapi', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(amplitudeEvent)
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Amplitude API error: ${response.status} - ${errorText}`);
  }

  const data = await response.json() as any;

  if (data.code !== 200) {
    throw new Error(`Amplitude tracking failed: ${JSON.stringify(data)}`);
  }
}

/**
 * Track worker alert creation event in Amplitude
 */
export async function trackAlertCreated(
  workerName: string,
  alertType: 'consecutive_failures' | 'sustained_slow_response',
  linearIssueId: string,
  apiKey: string
): Promise<void> {
  const amplitudeEvent = {
    api_key: apiKey,
    events: [{
      event_type: 'worker_alert_created',
      user_id: 'system',
      event_properties: {
        worker_name: workerName,
        alert_type: alertType,
        linear_issue_id: linearIssueId
      },
      time: Date.now()
    }]
  };

  const response = await fetch('https://api2.amplitude.com/2/httpapi', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(amplitudeEvent)
  });

  if (!response.ok) {
    // Consume response body to prevent resource leaks
    const errorText = await response.text();
    console.warn(`Failed to track alert in Amplitude: ${response.status} - ${errorText}`);
  }
}
