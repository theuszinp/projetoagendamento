BEGIN;

INSERT INTO storage.buckets (id, name, public)
VALUES ('ticket-attachments', 'ticket-attachments', true)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'storage'
          AND tablename = 'objects'
          AND policyname = 'Public read ticket attachments'
    ) THEN
        CREATE POLICY "Public read ticket attachments"
        ON storage.objects
        FOR SELECT
        TO public
        USING (bucket_id = 'ticket-attachments');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'storage'
          AND tablename = 'objects'
          AND policyname = 'Anon upload ticket attachments'
    ) THEN
        CREATE POLICY "Anon upload ticket attachments"
        ON storage.objects
        FOR INSERT
        TO anon
        WITH CHECK (bucket_id = 'ticket-attachments');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'storage'
          AND tablename = 'objects'
          AND policyname = 'Authenticated upload ticket attachments'
    ) THEN
        CREATE POLICY "Authenticated upload ticket attachments"
        ON storage.objects
        FOR INSERT
        TO authenticated
        WITH CHECK (bucket_id = 'ticket-attachments');
    END IF;
END $$;

COMMIT;
