export const webConfig = {
  supabaseUrl:
    process.env.NEXT_PUBLIC_SUPABASE_URL ??
    "https://qsyhkpaeyzhjojdvbntq.supabase.co",
  supabaseAnonKey:
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
    "sb_publishable_smWWadjejdbKYvmg3fidsg_41XPu70e",
  apiBaseUrl:
    process.env.NEXT_PUBLIC_API_BASE_URL ??
    "https://api.chillnoteai.com",
};
