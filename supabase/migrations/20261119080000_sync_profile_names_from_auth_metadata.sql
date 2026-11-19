-- Prefer the explicit name fields submitted during registration, while retaining
-- full_name parsing for older clients that only send that field.
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
    first_name := nullif(btrim(NEW.raw_user_meta_data ->> 'firstname'), '');
    last_name := nullif(btrim(NEW.raw_user_meta_data ->> 'lastname'), '');

    first_name := coalesce(first_name, nullif(split_part(full_name, ' ', 1), ''));
    last_name := coalesce(
        last_name,
        nullif(btrim(substr(full_name, length(split_part(full_name, ' ', 1)) + 2)), '')
    );

    IF first_name IS NULL AND last_name IS NULL THEN
        RETURN NEW;
    END IF;

    INSERT INTO public.profiles (id, firstname, lastname)
    VALUES (NEW.id, first_name, last_name)
    ON CONFLICT (id) DO UPDATE
    SET firstname = coalesce(nullif(btrim(public.profiles.firstname), ''), EXCLUDED.firstname),
        lastname = coalesce(nullif(btrim(public.profiles.lastname), ''), EXCLUDED.lastname),
        updated_at = now();

    RETURN NEW;
END;
$$;

-- Backfill existing accounts from explicit registration fields when available,
-- falling back to full_name for accounts created by older clients. Keep any
-- nonblank profile names that a user has already saved.
WITH auth_names AS (
    SELECT
        id,
        btrim(regexp_replace(coalesce(raw_user_meta_data ->> 'full_name', ''), '\s+', ' ', 'g')) AS full_name,
        nullif(btrim(raw_user_meta_data ->> 'firstname'), '') AS metadata_firstname,
        nullif(btrim(raw_user_meta_data ->> 'lastname'), '') AS metadata_lastname
    FROM auth.users
), names AS (
    SELECT
        id,
        coalesce(metadata_firstname, nullif(split_part(full_name, ' ', 1), '')) AS firstname,
        coalesce(
            metadata_lastname,
            nullif(btrim(substr(full_name, length(split_part(full_name, ' ', 1)) + 2)), '')
        ) AS lastname
    FROM auth_names
)
INSERT INTO public.profiles (id, firstname, lastname)
SELECT id, firstname, lastname
FROM names
WHERE firstname IS NOT NULL OR lastname IS NOT NULL
ON CONFLICT (id) DO UPDATE
SET firstname = coalesce(nullif(btrim(public.profiles.firstname), ''), EXCLUDED.firstname),
    lastname = coalesce(nullif(btrim(public.profiles.lastname), ''), EXCLUDED.lastname),
    updated_at = now();
