# Hostel Buddy

## Authentication setup

The app uses Supabase Auth for email/password and Google authentication. Supply
the Supabase anon/publishable key at build or run time; it is intentionally not
stored in the source:

```powershell
flutter run --dart-define="SUPABASE_ANON_KEY=<your-anon-key>"
```

For VS Code, create a **user** environment variable named
`SUPABASE_ANON_KEY` containing the Supabase anon/publishable key, then restart
VS Code and select **Hostel Buddy (Chrome)** from Run and Debug. The launch
profile passes that variable to Flutter without saving the key in the
workspace. Do not use a service-role key.

Enable Google in Supabase Authentication → Sign In / Providers. Configure the
Web OAuth client ID
`285226459021-fhfjusjeol6552jbmgbcqdg9tqmnuk5o.apps.googleusercontent.com` and
its secret in the Supabase dashboard only. Its authorized redirect URI must
include:

`https://jegdiogqnehlzkdrbomp.supabase.co/auth/v1/callback`

If the provider offers **Authorized Client IDs**, include both the Web client
and Android client IDs. The Android OAuth client is
`285226459021-na1o6eku6nhso0f421q7hoa4d7qsgqco.apps.googleusercontent.com`.
The Android application ID is `com.hostelbuddy.hostel_buddy`; Google Cloud must
also have the SHA-1 certificate fingerprint for each signing key used. The
debug fingerprint supplied for the current development machine is
`E9:85:F7:20:21:1B:F7:D0:3F:CA:BC:32:FA:A4:59:D5:DD:A7:01:89`.

Web Google sign-in uses Supabase's browser OAuth redirect. For iOS, add
`io.supabase.flutter://login-callback/` to Supabase's allowed redirect URLs.
For Web, add the app's origin (for example, the local development URL and
production domain) to Supabase's allowed redirect URLs. Start Web with the
same `--dart-define` key setup. Never put a Google client secret, Supabase
service-role key, or database password in the Flutter app.
