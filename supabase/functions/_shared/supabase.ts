import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
const publishableKey = Deno.env.get("SUPABASE_PUBLISHABLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}
console.log("supabaseUrl: " + supabaseUrl);
console.log("serviceRoleKey: " + serviceRoleKey);
export const supabaseAdmin: SupabaseClient = createClient(supabaseUrl, publishableKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});

export async function getUserId(request: Request): Promise<string> {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader) {
    throw new Error("MISSING_AUTH");
  }

  const token = authHeader.replace("Bearer ", "").trim();
  if (!token) {
    throw new Error("MISSING_AUTH");
  }

  const { data, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !data?.user) {
    throw new Error("INVALID_AUTH");
  }

  return data.user.id;
}
