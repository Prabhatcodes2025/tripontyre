-- PostgreSQL requires a newly added enum value to be committed before it is used.
alter type public.package_category add value if not exists 'strangers_meetup';
