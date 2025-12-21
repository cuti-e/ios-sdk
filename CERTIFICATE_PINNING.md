# Certificate Pinning

This SDK implements SSL certificate pinning to protect against man-in-the-middle attacks. This document explains the implementation and update process.

## Current Configuration

| Property | Value |
|----------|-------|
| Pinned CAs | Google Trust Services Root R1, R2, R3, R4 |
| Intermediate | WE1 (Cloudflare) |
| Expiry Date | **June 22, 2036** |
| Monitoring | Automated CI check (monthly) |

## How It Works

The SDK pins to Google Trust Services root CAs, which are used by Cloudflare for our API endpoints. This is safer than pinning to leaf certificates because:

1. Root CAs have long validity periods (10+ years)
2. Cloudflare can rotate leaf certificates without breaking the SDK
3. Users don't need to update the SDK for routine certificate renewals

## Pinned Domains

- `api.cuti-e.com` (production)
- `cutie-worker-sandbox.invotekas.workers.dev` (sandbox)
- `invotekas.workers.dev` (workers subdomain)

## Monitoring

### Automated CI Check

A GitHub Actions workflow runs monthly to check pin expiry:

- **Workflow:** `.github/workflows/pin-expiry-check.yml`
- **Schedule:** 1st of each month at 00:00 UTC
- **Action:** Creates/updates a GitHub issue when < 1 year remaining

### Runtime Check

The SDK logs a warning at initialization if pins are expiring soon:

```
[CutiE] WARNING: Certificate pins expire in X days (June 22, 2036). Plan SDK update.
```

## When to Update

Update certificate pins when:

1. Current pins are within 1 year of expiry
2. Cloudflare changes their certificate chain
3. Google Trust Services issues new root CAs
4. A pinned certificate is compromised (emergency)

## Update Process

### 1. Identify New Certificates

Check which root CAs Cloudflare is currently using:

```bash
# Get the certificate chain from production API
openssl s_client -connect api.cuti-e.com:443 -showcerts < /dev/null 2>/dev/null | \
  openssl x509 -noout -issuer
```

Visit [Google Trust Services](https://pki.goog/) for current root CA information.

### 2. Extract SPKI Hashes

For each certificate in the chain:

```bash
# Download the certificate (example for GTS Root R1)
curl -O https://pki.goog/repo/certs/gtsr1.der

# Convert DER to PEM if needed
openssl x509 -inform DER -in gtsr1.der -out gtsr1.pem

# Extract SPKI hash
openssl x509 -in gtsr1.pem -pubkey -noout | \
  openssl pkey -pubin -outform DER | \
  openssl dgst -sha256 -binary | \
  base64
```

### 3. Update the SDK

Edit `Sources/CutiE/CutiECertificatePinning.swift`:

1. Add new hashes to `pinnedHashes`
2. Update `pinExpiryDate` to the new expiry date
3. Update comments with new certificate details

```swift
private let pinnedHashes: Set<String> = [
    // NEW: GTS Root RX (add new certificates here)
    "newHashHere=",
    // Keep old hashes during transition period
    "hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc=",
    // ...
]

private static let pinExpiryDate: Date = {
    var components = DateComponents()
    components.year = 2046  // Update to new expiry year
    // ...
}()
```

### 4. Test Thoroughly

```bash
# Build and run tests
swift build
swift test

# Test against sandbox API
# (Manual testing in a test app)

# Test against production API
# (Verify pinning works correctly)
```

### 5. Release New SDK Version

1. Update version in `Package.swift` if needed
2. Create PR with changes
3. After merge, create a new release tag
4. Update CHANGELOG.md

### 6. Notify SDK Users

- Create a GitHub release with update notes
- Consider a deprecation warning in the old version
- Allow transition period (keep old + new hashes)

## Timeline

| Date | Action |
|------|--------|
| Monthly | CI checks expiry, creates issue if < 1 year |
| 1 year before | Start planning certificate update |
| 6 months before | Release SDK with new pins |
| 3 months before | Deprecation warnings for old SDK versions |
| Expiry date | Old pins stop working |

## Troubleshooting

### Connection Failures After Update

If users report connection failures after a certificate update:

1. Verify the new hashes are correct
2. Check if Cloudflare changed their certificate chain
3. Temporarily add more root CA hashes to cover edge cases
4. Release a hotfix SDK version

### Extracting Hashes from Live Server

```bash
# Get all certificates in the chain
echo | openssl s_client -connect api.cuti-e.com:443 -showcerts 2>/dev/null | \
  awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{ print }' > chain.pem

# Split into individual certificates and hash each one
```

## Security Considerations

- Never remove old hashes immediately; allow transition period
- Keep at least 2-3 backup root CA hashes
- Monitor for certificate chain changes proactively
- Have an emergency update process ready

## References

- [OWASP Certificate Pinning](https://owasp.org/www-community/controls/Certificate_and_Public_Key_Pinning)
- [Google Trust Services](https://pki.goog/)
- [Cloudflare SSL/TLS](https://developers.cloudflare.com/ssl/)
