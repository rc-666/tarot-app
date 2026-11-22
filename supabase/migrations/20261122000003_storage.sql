-- Public buckets: explanation library (JSON per language, versioned) and card art (WebP).
insert into storage.buckets (id, name, public) values ('library', 'library', true), ('cards', 'cards', true)
on conflict (id) do nothing;
