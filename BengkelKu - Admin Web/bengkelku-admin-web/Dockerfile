# BengkelKu Admin Web — image produksi Next.js (standalone).
# Output: .next/standalone berisi hanya dependensi yang benar-benar dipakai,
# sehingga image akhir tidak membutuhkan node_modules dan sangat kecil.

FROM node:20-alpine AS base

# ---- deps: install dependensi (layer ini di-cache) ---------------------------
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

# ---- builder: build aplikasi -------------------------------------------------
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Matikan telemetri agar build tidak mengirim data.
ENV NEXT_TELEMETRY_DISABLED=1

# NEXT_PUBLIC_* disisipkan ke client bundle saat BUILD, bukan runtime.
# Karena itu harus tersedia di tahap ini lewat build-arg / env.
ARG NEXT_PUBLIC_SUPABASE_URL=""
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY=""
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY

RUN npm run build

# ---- runner: image produksi akhir yang ramping -------------------------------
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Jalankan sebagai user non-root.
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Hanya salin hasil standalone + static. Tidak ada node_modules, tidak ada source.
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000

CMD ["node", "server.js"]
