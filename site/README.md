# site/

The public website: a landing page plus the privacy policy, served by GitHub
Pages. It is static and loads nothing from other servers.

## Rebuild

```bash
python3 tool/build_site.py
```

This regenerates `privacy/index.html` from `docs/privacy-policy.md`, and copies
the icon, screenshots and fonts into `assets/`. `index.html` and
`styles.css` are edited by hand.

## Before publishing

1. Fill the placeholders in `docs/privacy-policy.md`: date, developer name,
   email, minimum age. Remove its draft box, then rebuild.
2. In `index.html`:
   - replace `support@example.com`;
   - at launch, replace the "Coming soon" labels with the Google Play link and
     the official "Get it on Google Play" badge (follow Google's badge
     guidelines).
3. If the brand name changes, update the text here and regenerate the images
   (see `docs/brand/BRAND.md`).

## Publish (owner)

1. Copy `docs/ci/pages.yml` to `.github/workflows/pages.yml` and push.
2. GitHub → Settings → Pages → Source: **GitHub Actions**.
3. The site appears at `https://<user>.github.io/<repo>/`. The privacy policy
   is at `…/privacy/`.
4. Put that privacy URL in:
   - `AppConstants.privacyPolicyUrl` (`lib/core/constants/app_constants.dart`),
     which turns `test/release_config_test.dart` from skipped to passing;
   - Play Console → App content → Privacy policy.

## Preview locally

```bash
python3 -m http.server 8765 --directory site
```
