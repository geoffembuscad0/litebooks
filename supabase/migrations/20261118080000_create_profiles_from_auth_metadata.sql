-- Create a profile from the full_name metadata submitted during Supabase Auth signup.
-- Preserve profile names already set by a user.
CREATE OR REPLACE FUNCTION public.handle_new_user_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    full_name text;
    first_name text;
    last_name text;
BEGIN
    full_name := btrim(regexp_replace(coalesce(NEW.raw_user_meta_data ->> 'full_name', ''), '\s+', ' ', 'g'));
    IF full_name = '' THEN
        RETURN NEW;
    END IF;

    first_name := split_part(full_name, ' ', 1);
    last_name := nullif(btrim(substr(full_name, length(first_name) + 2)), '');

    INSERT INTO public.profiles (id, firstname, lastname)
    VALUES (NEW.id, first_name, last_name)
    ON CONFLICT (id) DO UPDATE
    SET firstname = coalesce(nullif(btrim(public.profiles.firstname), ''), EXCLUDED.firstname),
        lastname = coalesce(nullif(btrim(public.profiles.lastname), ''), EXCLUDED.lastname),
        updated_at = now();

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_create_profile ON auth.users;
CREATE TRIGGER on_auth_user_created_create_profile
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user_profile();

-- Backfill accounts that predate this migration without replacing existing names.
WITH names AS (
    SELECT
        id,
        btrim(regexp_replace(coalesce(raw_user_meta_data ->> 'full_name', ''), '\s+', ' ', 'g')) AS full_name
    FROM auth.users
)
INSERT INTO public.profiles (id, firstname, lastname)
SELECT
    id,
    split_part(full_name, ' ', 1),
    nullif(btrim(substr(full_name, length(split_part(full_name, ' ', 1)) + 2)), '')
FROM names
WHERE full_name <> ''
ON CONFLICT (id) DO UPDATE
SET firstname = coalesce(nullif(btrim(public.profiles.firstname), ''), EXCLUDED.firstname),
    lastname = coalesce(nullif(btrim(public.profiles.lastname), ''), EXCLUDED.lastname),
    updated_at = now();
