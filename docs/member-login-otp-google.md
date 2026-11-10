# Member sign-in for orphan sponsorship (staging)

Version targeted: **1.0.3**. Existing email/password sign-in and WooCommerce checkout are preserved.

## Mobile app changes

- When an orphan sponsorship is selected while signed out, show a choice to sign in/register or continue as guest.
- Preserve the selected sponsorship URL; after a successful member login, return to the WooCommerce cart inside the app.
- For email signup, query GET `/wp-json/altaawun-app/v1/auth-capabilities`.
- If `email_otp: true`, require name, email, password (12+ characters), phone; call POST `register-start`, then POST `register-verify` with the 6-digit code; finally use the EXISTING `/login` endpoint to obtain the established app session token.
- The WordPress OTP add-on implements `auth-capabilities`, `register-start`, `register-verify`, and `register-resend`.
- Existing login is the default until the add-on is enabled; existing customers are not migrated.

## Enabling Google

The Flutter client is prepared, but **Google login is not active yet**.

1. Configure the Google/Firebase OAuth clients for the Android app's package `com.altaawuncharity.altaawun_charity_app`, its Play App Signing SHA-1/SHA-256 and local debug certificate as applicable. Current checked-in Android google-services.json contains no OAuth clients.
2. Set GitHub repository variables `ALTAWUN_GOOGLE_WEB_CLIENT_ID` and (for iOS) `ALTAWUN_GOOGLE_IOS_CLIENT_ID`. They are client IDs, not client secrets.
3. Implement `POST /wp-json/altaawun-app/v1/google-login` on the EXISTING WordPress auth service. Accept `id_token`, verify Google's signature, expiration, issuer and exact expected client audience; use the stable `sub` as user identity. Do not automatically link a different pre-existing email account without a secure account-linking proof.
4. The endpoint must return the exact same `{token, user}` schema/session format as the existing `/login`, so `/me`, `/orders` and `/cart-session` continue working.
5. Set `google_login:true` in the server capabilities response only after the endpoint is implemented and tested. Otherwise the Google button remains hidden to avoid misleading users.
6. Complete iOS URL scheme and Google Sign-In iOS config before iOS releases.

## Checks before publishing

- Test SMTP email delivery, OTP expiration, resend throttling, wrong-code attempts and expired code.
- Test existing accounts, forgotten-password flow, registration and Google login when enabled.
- Verify WooCommerce cart session bridge, order history and the same WordPress user ID across login methods.
- Test Android on the 21 previously affected devices or compare supported-device reports before Play rollout.
- Do not publish the staged PR until WordPress and Google configuration are verified.

## Notes

- A paired **Altaawun Email Verification 1.0.0** WordPress add-on is provided separately as a ZIP for staging installation.
- Site-side WooCommerce registration UI is a separate integration task; the WordPress add-on currently covers REST registration for the app.
- This branch has not been built or tested on a physical device.
