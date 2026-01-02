/**
 * JWT Generation for App Store Connect API
 * Uses ES256 (ECDSA with SHA-256) algorithm
 */

import { SignJWT, importPKCS8 } from 'jose';

/**
 * Generate a JWT token for App Store Connect API authentication
 * Token is valid for 15 minutes
 *
 * @param issuerId - Your Issuer ID from App Store Connect
 * @param keyId - Your API Key ID
 * @param privateKeyPem - Full contents of .p8 private key file
 * @returns JWT token string
 */
export async function generateJWT(
  issuerId: string,
  keyId: string,
  privateKeyPem: string
): Promise<string> {
  // Import the private key (ES256 algorithm)
  const privateKey = await importPKCS8(privateKeyPem, 'ES256');

  const now = Math.floor(Date.now() / 1000);

  // Create and sign the JWT
  const jwt = await new SignJWT({})
    .setProtectedHeader({
      alg: 'ES256',
      kid: keyId,
      typ: 'JWT'
    })
    .setIssuer(issuerId)
    .setAudience('appstoreconnect-v1')
    .setIssuedAt(now)
    .setExpirationTime(now + 900) // 15 minutes
    .sign(privateKey);

  return jwt;
}
