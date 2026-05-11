/*
  # No-code event schema

  Adds a JSONB property schema to `event_definitions` so non-technical users
  can document and validate the properties an event carries, without writing
  SDK code.

  1. Column additions on `public.event_definitions`
    - `schema` (jsonb) — array of { key: text, type: 'string'|'number'|'boolean'|'date', required: boolean, description: text }
    - `source` (text) — 'sdk' | 'manual' | 'ui' — lets us distinguish user-
      defined events from auto-discovered ones.

  2. No security changes — existing RLS on event_definitions still applies.
*/

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='event_definitions' AND column_name='schema') THEN
    ALTER TABLE public.event_definitions ADD COLUMN schema jsonb NOT NULL DEFAULT '[]'::jsonb;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='event_definitions' AND column_name='source') THEN
    ALTER TABLE public.event_definitions ADD COLUMN source text NOT NULL DEFAULT 'ui';
  END IF;
END $$;
