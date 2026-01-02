/**
 * App Store Connect API Client
 * Fetches beta testers for a given app
 */

export interface BetaTester {
  id: string;
  email: string;
  firstName: string | null;
  lastName: string | null;
  state: string;
}

interface BetaTesterResponse {
  data: Array<{
    type: string;
    id: string;
    attributes: {
      email: string;
      firstName: string | null;
      lastName: string | null;
      state: string;
    };
  }>;
  links?: {
    next?: string;
  };
}

/**
 * Fetch all accepted beta testers for an app
 * Handles pagination automatically
 *
 * @param jwt - JWT token from generateJWT()
 * @param appId - Your App Store Connect app ID
 * @returns Array of beta testers with state === 'ACCEPTED'
 */
export async function fetchBetaTesters(
  jwt: string,
  appId: string
): Promise<BetaTester[]> {
  const testers: BetaTester[] = [];
  let nextUrl: string | null =
    `https://api.appstoreconnect.apple.com/v1/betaTesters?` +
    `filter[apps]=${appId}&` +
    `fields[betaTesters]=email,firstName,lastName,state&` +
    `limit=200`;

  while (nextUrl) {
    const response = await fetch(nextUrl, {
      headers: {
        'Authorization': `Bearer ${jwt}`,
        'Content-Type': 'application/json'
      }
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(
        `App Store Connect API error: ${response.status} - ${errorText}`
      );
    }

    const data: BetaTesterResponse = await response.json();

    for (const tester of data.data) {
      // Only include testers who have accepted the invite
      if (tester.attributes.state === 'ACCEPTED') {
        testers.push({
          id: tester.id,
          email: tester.attributes.email,
          firstName: tester.attributes.firstName,
          lastName: tester.attributes.lastName,
          state: tester.attributes.state
        });
      }
    }

    // Handle pagination
    nextUrl = data.links?.next || null;
  }

  return testers;
}
