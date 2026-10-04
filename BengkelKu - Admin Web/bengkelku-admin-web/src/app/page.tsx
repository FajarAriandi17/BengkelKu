import { redirect } from "next/navigation";

// Root → arahkan ke dashboard (middleware menjaga auth).
export default function Home() {
  redirect("/dashboard");
}
