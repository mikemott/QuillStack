/**
 * Linear GraphQL API Client
 * Creates issues for TestFlight feedback
 */

export interface FeedbackIssue {
  title: string;
  description: string;
  testerEmail: string;
  deviceInfo?: {
    model?: string;
    osVersion?: string;
  };
  timestamp: string;
}

export interface LinearIssueResponse {
  identifier: string;
  id: string;
  url: string;
}

/**
 * Create a Linear issue from TestFlight feedback
 */
export async function createFeedbackIssue(
  feedback: FeedbackIssue,
  apiKey: string,
  teamId: string,
  labelId: string
): Promise<LinearIssueResponse> {
  // Build the description with metadata
  const description = buildIssueDescription(feedback);

  // GraphQL mutation
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
      title: feedback.title,
      description: description,
      teamId: teamId,
      labelIds: [labelId],
      priority: 0 // No priority
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
 * Build formatted markdown description for Linear issue
 */
function buildIssueDescription(feedback: FeedbackIssue): string {
  const sections: string[] = [];

  // Feedback content
  sections.push('## Feedback\n');
  sections.push(feedback.description);
  sections.push('');

  // Metadata section
  sections.push('## Metadata\n');
  sections.push(`**Submitted by:** ${feedback.testerEmail}`);
  sections.push(`**Received:** ${new Date(feedback.timestamp).toLocaleString('en-US', {
    dateStyle: 'medium',
    timeStyle: 'short'
  })}`);

  // Device info if available
  if (feedback.deviceInfo?.model || feedback.deviceInfo?.osVersion) {
    sections.push('');
    sections.push('### Device Information');
    if (feedback.deviceInfo.model) {
      sections.push(`**Device:** ${feedback.deviceInfo.model}`);
    }
    if (feedback.deviceInfo.osVersion) {
      sections.push(`**iOS Version:** ${feedback.deviceInfo.osVersion}`);
    }
  }

  return sections.join('\n');
}
