/**
 * TestFlight Feedback Email Parser
 * Handles both structured Apple feedback and free-form user replies
 */

import { FeedbackIssue } from './linearClient';

/**
 * Parse TestFlight feedback from an incoming email message
 */
export async function parseFeedbackEmail(
  message: ForwardableEmailMessage
): Promise<FeedbackIssue> {
  const from = message.from;
  const subject = message.headers.get('subject') || 'No Subject';

  // Extract tester email (use from address)
  const testerEmail = extractEmail(from);

  // Get email body (read from raw stream)
  const rawStream = message.raw;
  const reader = rawStream.getReader();
  const chunks: Uint8Array[] = [];

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
  }

  const totalLength = chunks.reduce((acc, chunk) => acc + chunk.length, 0);
  const combined = new Uint8Array(totalLength);
  let offset = 0;
  for (const chunk of chunks) {
    combined.set(chunk, offset);
    offset += chunk.length;
  }

  const rawText = new TextDecoder().decode(combined);

  // Clean the email content (remove quoted replies, signatures, etc.)
  const cleanedText = cleanEmailContent(rawText);

  // Extract device info if present
  const deviceInfo = extractDeviceInfo(rawText);

  // Generate title from first line or subject
  const title = generateTitle(cleanedText, subject);

  return {
    title,
    description: cleanedText,
    testerEmail,
    deviceInfo,
    timestamp: new Date().toISOString()
  };
}

/**
 * Extract email address from "Name <email@domain.com>" format
 */
function extractEmail(fromHeader: string): string {
  const match = fromHeader.match(/<(.+?)>/);
  if (match && match[1]) {
    return match[1];
  }
  // If no angle brackets, assume the whole string is an email
  return fromHeader.trim();
}

/**
 * Clean email content by removing quoted replies, signatures, etc.
 */
function cleanEmailContent(text: string): string {
  const lines = text.split('\n');
  const cleanedLines: string[] = [];

  for (const line of lines) {
    const trimmed = line.trim();

    // Stop at common email reply markers
    if (trimmed.startsWith('>') ||
        trimmed.startsWith('On ') && trimmed.includes('wrote:') ||
        trimmed.includes('-----Original Message-----') ||
        trimmed.includes('________________________________')) {
      break;
    }

    // Stop at common signature markers
    if (trimmed === '--' ||
        trimmed === '---' ||
        trimmed.startsWith('Sent from my iPhone') ||
        trimmed.startsWith('Sent from my iPad')) {
      break;
    }

    cleanedLines.push(line);
  }

  // Join and trim excessive whitespace
  return cleanedLines
    .join('\n')
    .trim()
    .replace(/\n{3,}/g, '\n\n'); // Max 2 consecutive newlines
}

/**
 * Extract device information from email content
 * Looks for patterns like "iPhone 15 Pro", "iOS 18.2", etc.
 */
function extractDeviceInfo(text: string): {
  model?: string;
  osVersion?: string;
} | undefined {
  const deviceInfo: { model?: string; osVersion?: string } = {};

  // Look for device model patterns
  const devicePattern = /(iPhone|iPad)[\s]*([\d]+[\s]*(?:Pro|Plus|Max|mini)?)/i;
  const deviceMatch = text.match(devicePattern);
  if (deviceMatch) {
    deviceInfo.model = deviceMatch[0];
  }

  // Look for iOS version patterns
  const iosPattern = /iOS[\s]*([\d]+\.[\d]+(?:\.[\d]+)?)/i;
  const iosMatch = text.match(iosPattern);
  if (iosMatch) {
    deviceInfo.osVersion = iosMatch[1];
  }

  // Return undefined if no device info found
  return (deviceInfo.model || deviceInfo.osVersion) ? deviceInfo : undefined;
}

/**
 * Generate issue title from first line of feedback or subject
 */
function generateTitle(feedbackText: string, subject: string): string {
  // Try to get first meaningful line from feedback
  const lines = feedbackText.split('\n').filter(line => line.trim().length > 0);

  if (lines.length > 0) {
    const firstLine = lines[0]?.trim();
    if (firstLine) {
      // Use first line if it's substantial but not too long
      if (firstLine.length >= 10 && firstLine.length <= 100) {
        return `TestFlight: ${firstLine}`;
      }
      // If first line is too long, truncate it
      if (firstLine.length > 100) {
        return `TestFlight: ${firstLine.substring(0, 97)}...`;
      }
    }
  }

  // Fall back to subject line
  if (subject && subject !== 'No Subject' && !subject.toLowerCase().startsWith('re:')) {
    return `TestFlight: ${subject}`;
  }

  // Last resort
  return 'TestFlight: User Feedback';
}
