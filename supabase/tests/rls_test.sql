\set ON_ERROR_STOP 0
insert into auth.users values ('11111111-1111-1111-1111-111111111111'),('22222222-2222-2222-2222-222222222222');
insert into public.daily_cards values ('2026-11-22','America/Sao_Paulo','leo','venus','m03',false,'trine','m07','cancer',now());
insert into public.mood_shifts values ('2026-11-22T10:00:00Z',10,'c03','cancer');
insert into public.user_daily_cards values ('22222222-2222-2222-2222-222222222222','2026-11-22','mars','m16',true,'square','m07','cancer',now());

-- user 1
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false), set_config('request.jwt.claim.role','authenticated',false);
\echo T1 insert own profile, natal_sun forced null:
insert into public.profiles (id,first_name,birth_date,sun_sign,focus_topics,is_adult,natal_sun) values ('11111111-1111-1111-1111-111111111111','Maria','1972-08-14','leo','{family}',true, 123) returning natal_sun is null as natal_null;
\echo T2 insert someone else profile -> must fail:
insert into public.profiles (id,first_name,birth_date,sun_sign,focus_topics,is_adult) values ('22222222-2222-2222-2222-222222222222','X','1980-01-01','capricorn','{love}',true);
\echo T3 3 focus topics -> must fail:
update public.profiles set focus_topics='{a,b,c}' where id='11111111-1111-1111-1111-111111111111';
\echo T4 not adult -> must fail:
insert into public.profiles (id,first_name,birth_date,sun_sign,focus_topics,is_adult) values ('11111111-1111-1111-1111-111111111111','M','1972-08-14','leo','{a}',false);
\echo T5 read public cards (1) and mood shifts (1); other users personal cards (0):
select (select count(*) from public.daily_cards) dc, (select count(*) from public.mood_shifts) ms, (select count(*) from public.user_daily_cards) udc;
\echo T6 write public cards -> must fail:
insert into public.daily_cards values ('2026-11-23','America/Sao_Paulo','leo','venus','x',false,null,'y','cancer',now());
\echo T7 reading + rate once, re-rate fails:
insert into public.readings (user_id,day,topic) values ('11111111-1111-1111-1111-111111111111','2026-11-22','family');
update public.readings set rating=1 where day='2026-11-22';
update public.readings set rating=-1 where day='2026-11-22';
\echo T8 user cannot set natal_sun:
update public.profiles set natal_sun=50 where id='11111111-1111-1111-1111-111111111111';
reset role;
select natal_sun from public.profiles;
\echo T9 service role sets natal, then user edits birth date -> cleared:
select set_config('request.jwt.claim.role','service_role',false);
update public.profiles set natal_sun=140.5;
select set_config('request.jwt.claim.role','authenticated',false);
set role authenticated;
update public.profiles set birth_date='1972-08-15' where id='11111111-1111-1111-1111-111111111111';
reset role;
select natal_sun is null as cleared from public.profiles;
\echo T10 anon reads public data, no profiles:
set role anon; select set_config('request.jwt.claim.sub','',false);
select (select count(*) from public.daily_cards) dc, (select count(*) from public.profiles) p;
reset role;
\echo T11 delete auth user cascades:
delete from auth.users where id='11111111-1111-1111-1111-111111111111';
select (select count(*) from public.profiles) p, (select count(*) from public.readings) r;
