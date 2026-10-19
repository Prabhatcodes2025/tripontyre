-- Commit enum labels in their own migration before any later migration can use
-- them in inserts, defaults, constraints or casts. PostgreSQL does not allow a
-- newly added enum label to be used until the transaction that added it commits.

alter type public.package_category add value if not exists 'strangers_meetup';
alter type public.package_category add value if not exists 'custom';
