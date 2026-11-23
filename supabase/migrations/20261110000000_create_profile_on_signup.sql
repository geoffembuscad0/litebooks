-- Create a profile row whenever an auth user is created.
-- Name rule: first word -> firstname, last word -> lastname
-- (middle words are dropped; a single word leaves lastname empty).
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    full_name  TEXT;
    parts      TEXT[];
    first_name TEXT := '';
    last_name  TEXT := '';
BEGIN
    full_name := btrim(COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''));

    IF full_name <> '' THEN
        parts := regexp_split_to_array(full_name, '\s+');
        first_name := parts[1];

        IF array_length(parts, 1) > 1 THEN
            last_name := parts[array_length(parts, 1)];
        END IF;
    END IF;

    INSERT INTO public.profiles (id, firstname, lastname)
    VALUES (NEW.id, left(first_name, 150), left(last_name, 150))
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_create_profile_on_signup
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

-- Backfill users who registered before this trigger existed.
INSERT INTO public.profiles (id, firstname, lastname)
SELECT
    u.id,
    left(COALESCE(split_part(btrim(u.raw_user_meta_data ->> 'full_name'), ' ', 1), ''), 150),
    left(
        CASE
            WHEN btrim(COALESCE(u.raw_user_meta_data ->> 'full_name', '')) ~ '\s'
            THEN regexp_replace(btrim(u.raw_user_meta_data ->> 'full_name'), '^.*\s', '')
            ELSE ''
        END, 150)
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = u.id);