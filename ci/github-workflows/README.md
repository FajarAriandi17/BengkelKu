# Workflow GitHub Actions

GitHub App yang dipakai asisten tidak punya izin `workflows`, jadi file
workflow disimpan di sini. Aktifkan sekali saja:

```bash
mkdir -p .github/workflows
git mv ci/github-workflows/*.yml .github/workflows/
git commit -m "ci: aktifkan workflow" && git push
```

(atau upload kedua file lewat web GitHub → Add file → `.github/workflows/`).

- `mobile-release.yml` — jalankan manual (Actions → mobile-release → Run workflow)
  atau push tag `v1.0.0`. Hasil: APK + AAB (Android) dan IPA (iOS, runner macOS).
- `admin-web.yml` — typecheck/lint/build admin web setiap perubahan.

Secrets wajib: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GMAPS_API_KEY`.
Tanda tangan rilis (opsional): `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `IOS_P12_BASE64`, `IOS_P12_PASSWORD`,
`IOS_PROVISION_PROFILE_BASE64`, `IOS_TEAM_ID`. Tanpa sertifikat iOS, IPA dibuat
tanpa tanda tangan (perlu re-sign sebelum dipasang / diunggah ke TestFlight).
