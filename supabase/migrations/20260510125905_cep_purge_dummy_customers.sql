/*
  # Purge dummy customers while preserving events

  1. Changes
    - Change `events.customer_id` foreign key to ON DELETE SET NULL so deleting
      a customer does not wipe their historical events.
    - Delete all customer rows. Related per-customer tables cascade
      (list_members, campaign_messages, journey_enrollments, customer_consents,
      predictive_scores). Survey responses, commerce orders, and campaign
      attributions use SET NULL and remain.

  2. Security
    - No RLS changes; all operations are schema-level.

  3. Important notes
    1. Events are preserved; their customer_id becomes NULL for purged customers.
    2. Segments, lists, campaigns, templates, journeys, and funnels are NOT
       touched so the rest of the workspace still looks configured.
*/

ALTER TABLE events DROP CONSTRAINT IF EXISTS events_customer_id_fkey;
ALTER TABLE events
  ADD CONSTRAINT events_customer_id_fkey
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL;

DELETE FROM customers;
