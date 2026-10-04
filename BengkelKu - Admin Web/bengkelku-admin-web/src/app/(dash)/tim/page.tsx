import { createClient } from "@/lib/supabase/server";
import { dateTime, requireAdmin } from "@/lib/admin";
import { ROLE_LABEL, type AdminRole } from "@/lib/admin-access";
import { Badge, DataTable, ErrorBox, PageTitle } from "@/components/DataTable";
import { RpcAction } from "@/components/RpcAction";

const ROLE_OPTIONS = (Object.keys(ROLE_LABEL) as AdminRole[]).map((r) => ({ value: r, label: ROLE_LABEL[r] }));

// Tim admin (super_admin): tambah/ubah peran/nonaktifkan.
export default async function TimPage() {
  const me = await requireAdmin("/tim");
  const supabase = createClient();
  const { data, error } = await supabase
    .from("admin_users")
    .select("id, email, full_name, role, is_active, totp_enabled, created_at")
    .order("created_at");
  type Row = { id: string; email: string; full_name: string | null; role: AdminRole; is_active: boolean; totp_enabled: boolean; created_at: string };
  const rows = (data ?? []) as Row[];

  return (
    <div>
      <PageTitle
        title="Tim Admin"
        subtitle="akun harus sudah terdaftar di Supabase Auth (undang lewat dashboard Supabase → Authentication → Invite)."
      />
      <ErrorBox message={error?.message} />
      <div className="mb-6 max-w-md rounded-lg bg-panel p-5 shadow-sm">
        <h2 className="mb-3 font-semibold text-ink">Tambah / ubah peran admin</h2>
        <RpcAction
          rpc="admin_team_upsert"
          args={{}}
          fields={[
            { name: "p_email", label: "email akun", required: true, placeholder: "nama@bengkelku.id" },
            { name: "p_full_name", label: "nama lengkap" },
            { name: "p_role", label: "peran", type: "select", options: ROLE_OPTIONS, defaultValue: "verifikator" },
          ]}
          label="simpan admin"
          successText="admin tersimpan"
        />
      </div>
      <DataTable
        head={["Admin", "Peran", "Status", "2FA", "Ditambahkan", "Aksi"]}
        rows={rows.map((a) => ({
          key: a.id,
          cells: [
            <div key="n"><div className="font-medium text-ink">{a.full_name ?? "-"}</div><div className="text-xs text-ink/50">{a.email}</div></div>,
            ROLE_LABEL[a.role],
            a.is_active ? <Badge key="s" label="aktif" cls="bg-okSoft text-ok" /> : <Badge key="s" label="nonaktif" cls="bg-badSoft text-bad" />,
            a.totp_enabled ? "✓" : "—",
            dateTime(a.created_at),
            a.id === me.id ? (
              <span key="a" className="text-xs text-ink/40">akun kamu</span>
            ) : a.is_active ? (
              <RpcAction key="a" rpc="admin_team_set_active" args={{ p_admin_id: a.id, p_active: false }} label="nonaktifkan" tone="danger"
                confirmText={`Nonaktifkan ${a.email}? Akses panel langsung dicabut.`} successText="dinonaktifkan" />
            ) : (
              <RpcAction key="a" rpc="admin_team_set_active" args={{ p_admin_id: a.id, p_active: true }} label="aktifkan" tone="ok" successText="diaktifkan" />
            ),
          ],
        }))}
      />
    </div>
  );
}
