import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

export const supabaseAdmin: SupabaseClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
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
