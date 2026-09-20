-- Keep relation resolution deterministic, including when a caller has a
-- temporary schema. Do not change or grant any client-facing privileges.
ALTER FUNCTION public.chillo_invalidate_note_index()
  SET search_path = pg_catalog, public, pg_temp;
