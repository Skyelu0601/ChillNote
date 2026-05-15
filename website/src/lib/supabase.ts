"use client";

import { createClient } from "@supabase/supabase-js";
import { webConfig } from "./config";

export const supabase = createClient(webConfig.supabaseUrl, webConfig.supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
    flowType: "pkce",
  },
});
