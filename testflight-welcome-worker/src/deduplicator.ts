/**
 * Feedback Deduplication using KV Storage
 * Prevents duplicate Linear issues for similar feedback
 */

/**
 * Generate SHA-256 hash of feedback for deduplication
 * Hash is based on tester email + normalized feedback text
 */
export async function generateFeedbackHash(
  testerEmail: string,
  feedbackText: string
): Promise<string> {
  // Normalize text: lowercase, trim, collapse whitespace
  const normalized = feedbackText
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ');

  // Combine email and normalized text
  const content = `${testerEmail}:${normalized}`;

  // Generate SHA-256 hash
  const encoder = new TextEncoder();
  const data = encoder.encode(content);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);

  // Convert to hex string
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');

  return hashHex;
}

/**
 * Check if feedback is a duplicate
 * Returns true if similar feedback was received within the last 7 days
 */
export async function isDuplicateFeedback(
  hash: string,
  kvNamespace: KVNamespace
): Promise<boolean> {
  const existing = await kvNamespace.get(hash);
  return existing !== null;
}

/**
 * Store feedback hash in KV with metadata
 * Expires after 7 days
 */
export async function storeFeedbackHash(
  hash: string,
  testerEmail: string,
  feedbackPreview: string,
  kvNamespace: KVNamespace
): Promise<void> {
  const record = {
    email: testerEmail,
    preview: feedbackPreview.substring(0, 100), // First 100 chars
    receivedAt: new Date().toISOString()
  };

  await kvNamespace.put(
    hash,
    JSON.stringify(record),
    {
      // 7 day TTL
      expirationTtl: 60 * 60 * 24 * 7
    }
  );
}
