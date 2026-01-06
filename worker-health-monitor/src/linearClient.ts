/**
 * Linear GraphQL API Client
 * Creates issues for worker health alerts
 */

export interface HealthAlert {
  workerName: string;
  alertType: 'consecutive_failures' | 'sustained_slow_response';
  details: {
    consecutiveFailures?: number;
    lastError?: string;
    responseTimeMs?: number;
    duration?: number;
  };
  timestamp: string;
}

export interface LinearIssueResponse {
  identifier: string;
  id: string;
  url: string;
}

/**
 * Create a Linear issue for worker health alert
 */
export async function createHealthAlertIssue(
  alert: HealthAlert,
  apiKey: string,
  teamId: string
): Promise<LinearIssueResponse> {
  const title = buildIssueTitle(alert);
  const description = buildIssueDescription(alert);

  const mutation = `
    mutation CreateIssue($input: IssueCreateInput!) {
      issueCreate(input: $input) {
        success
        issue {
          id
          identifier
          url
        }
      }
    }
  `;

  const variables = {
    input: {
      title: title,
      description: description,
      teamId: teamId,
      priority: 1, // Urgent priority for production issues
      labelIds: [] // Can be extended to use specific labels
    }
  };

  const response = await fetch('https://api.linear.app/graphql', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': apiKey
    },
    body: JSON.stringify({ query: mutation, variables })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Linear API error: ${response.status} - ${errorText}`);
  }

  const data = await response.json() as any;

  if (!data.data?.issueCreate?.success) {
    throw new Error(`Linear issue creation failed: ${JSON.stringify(data)}`);
  }

  return {
    identifier: data.data.issueCreate.issue.identifier,
    id: data.data.issueCreate.issue.id,
    url: data.data.issueCreate.issue.url
  };
}

/**
 * Build issue title based on alert type
 */
function buildIssueTitle(alert: HealthAlert): string {
  if (alert.alertType === 'consecutive_failures') {
    return `🚨 ${alert.workerName} - Multiple Health Check Failures`;
  } else {
    return `⚠️ ${alert.workerName} - Sustained Slow Response Times`;
  }
}

/**
 * Build formatted markdown description for Linear issue
 */
function buildIssueDescription(alert: HealthAlert): string {
  const sections: string[] = [];

  // Alert summary
  sections.push('## Alert Summary\n');
  sections.push(`**Worker:** ${alert.workerName}`);
  sections.push(`**Alert Type:** ${alert.alertType.replace('_', ' ')}`);
  sections.push(`**Detected:** ${new Date(alert.timestamp).toLocaleString('en-US', {
    dateStyle: 'medium',
    timeStyle: 'short'
  })}`);
  sections.push('');

  // Details based on alert type
  if (alert.alertType === 'consecutive_failures') {
    sections.push('## Failure Details\n');
    sections.push(`**Consecutive Failures:** ${alert.details.consecutiveFailures || 'Unknown'}`);
    if (alert.details.lastError) {
      sections.push(`**Last Error:** ${alert.details.lastError}`);
    }
  } else {
    sections.push('## Performance Details\n');
    sections.push(`**Response Time:** ${alert.details.responseTimeMs}ms`);
    sections.push(`**Duration:** ${alert.details.duration} minutes`);
    sections.push(`**Threshold:** >5000ms for >15 minutes`);
  }

  sections.push('');
  sections.push('## Next Steps\n');
  sections.push('1. Check worker logs: `wrangler tail ' + alert.workerName + '`');
  sections.push('2. Verify worker deployment status');
  sections.push('3. Check for any recent code changes');
  sections.push('4. Review Cloudflare dashboard for service issues');

  return sections.join('\n');
}
