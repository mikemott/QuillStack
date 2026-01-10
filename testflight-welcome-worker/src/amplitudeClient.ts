/**
 * Amplitude HTTP API Client
 * Tracks beta feedback events
 */

export interface FeedbackEvent {
  testerEmail: string;
  feedbackLength: number;
  hasDeviceInfo: boolean;
  linearIssueIdentifier: string;
  timestamp: string;
}

/**
 * Track beta feedback received event in Amplitude
 */
export async function trackFeedbackEvent(
  event: FeedbackEvent,
  apiKey: string
): Promise<void> {
  const amplitudeEvent = {
    api_key: apiKey,
    events: [{
      event_type: 'beta_feedback_received',
      user_id: event.testerEmail,
      event_properties: {
        feedback_length: event.feedbackLength,
        has_device_info: event.hasDeviceInfo,
        linear_issue_id: event.linearIssueIdentifier
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

  // Amplitude returns success even with validation errors, check the response
  if (data.code !== 200) {
    throw new Error(`Amplitude tracking failed: ${JSON.stringify(data)}`);
  }
}
