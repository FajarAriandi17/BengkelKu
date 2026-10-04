export default function KonfigurasiPage() {
  return (
    <div>
      <h1 className="mb-2 text-2xl font-bold text-ink">Konfigurasi</h1>
      <p className="text-sm text-ink/60">
        atur komisi (default 8%), tenggat pembayaran, ambang jarak GPS
        (<code>max_gps_distance_m</code>, default 300 m), preset oli, dll. lihat
        <code> docs/PAGES.md</code> (halaman <code>cfg</code>).
      </p>
    </div>
  );
}
