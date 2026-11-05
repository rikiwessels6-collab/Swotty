# Getting Swotty onto TestFlight (no Mac needed)

GitHub's Mac servers build, sign and upload the app. You do the one-off setup
below in Safari, then press one button each time you want a new build.

## One-off setup

### 1. Register the app ID and create the app record
- developer.apple.com → Certificates, Identifiers & Profiles → **Identifiers → +**
  → App IDs → App. Bundle ID (Explicit), e.g. `com.rikiwessels.swotty`.
  Enable no extra capabilities (Swotty doesn't need any).
- appstoreconnect.apple.com → **Apps → + → New App**. Platform iOS, name
  *Swotty*, pick that bundle ID, any SKU (e.g. `swotty`).
- Make sure `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` matches exactly.

### 2. Create an App Store Connect API key
- App Store Connect → **Users and Access → Integrations → App Store Connect API**
  → **+**. Name it "GitHub", access **Admin** (needed so Xcode can create the
  signing certificate and profile automatically).
- Download the `.p8` file (you can only download it once) and note the
  **Key ID** and the **Issuer ID** shown at the top of that page.

### 3. Add GitHub secrets
Repository → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | 10-character Team ID (developer.apple.com → Membership details) |
| `ASC_KEY_ID` | Key ID from step 2 |
| `ASC_ISSUER_ID` | Issuer ID from step 2 |
| `ASC_KEY_P8_BASE64` | The `.p8` file's contents, base64-encoded (see below) |

Base64-encoding the key without a Mac: open the `.p8` in any text editor,
copy everything (including the BEGIN/END lines), and paste it into a
base64 encoder such as https://www.base64encode.org (Encode, UTF-8, keep line
breaks). Paste the result as the secret.

## Each build
1. GitHub → **Actions → Upload to TestFlight → Run workflow**.
2. Wait ~10–15 minutes. The build number is the workflow run number, so it
   always increases.
3. In App Store Connect → your app → **TestFlight**, the build appears after
   Apple's processing (usually a few minutes more). Answer the export-compliance
   prompt if shown (the app declares no non-exempt encryption).
4. Add yourself under **Internal Testing** (Users and Access → add your Apple ID
   as a user first if needed), then install via the TestFlight app.

## If it fails
Open the failed run in Actions and read the step that went red. Common causes:
a missing secret, a bundle ID that doesn't match the registered one, or the
API key not having Admin access.
