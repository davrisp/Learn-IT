-- Run with: supabase test db   (pgTAP). Guards against broken access control.
begin;
create extension if not exists pgtap with schema extensions;
select * from no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a@test.dev'),
  ('00000000-0000-0000-0000-0000000000b2', 'b@test.dev');

-- A creates a private, a public and a link set
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;
select lives_ok($$insert into public.study_sets (id, owner_id, title, visibility) values
  ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000a1','private','private'),
  ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-0000000000a1','public','public'),
  ('10000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-0000000000a1','link','link')$$, 'A creates sets');
select lives_ok($$insert into public.cards (set_id, term, definition)
  values ('10000000-0000-0000-0000-000000000001','t','d')$$, 'A adds a card');
select set_config('app.tok', public.create_share_link('10000000-0000-0000-0000-000000000003'), true);
reset role;

-- B (another user)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.study_sets where id = '10000000-0000-0000-0000-000000000001'), 0::bigint, 'B cannot read A''s private set');
select is((select count(*) from public.cards), 0::bigint, 'B cannot read cards of private sets');
select is((select count(*) from public.study_sets where id = '10000000-0000-0000-0000-000000000002'), 1::bigint, 'B can read A''s public set');
select lives_ok($$update public.study_sets set title = 'hacked' where id = '10000000-0000-0000-0000-000000000001'$$, 'B update runs but matches nothing');
select throws_ok($$insert into public.cards (set_id, term, definition)
  values ('10000000-0000-0000-0000-000000000001','x','y')$$, '42501', null, 'B cannot add cards to A''s set');
select lives_ok($$delete from public.study_sets where id = '10000000-0000-0000-0000-000000000001'$$, 'B delete runs but matches nothing');
select throws_ok($$select public.create_share_link('10000000-0000-0000-0000-000000000003')$$, 'P0002', null, 'B cannot mint a link for A''s set');
select throws_ok($$select public.review_card((select id from public.cards limit 1), 4)$$, null, null, 'B cannot review a card it cannot see');
select isnt(public.get_set_by_link('10000000-0000-0000-0000-000000000003', current_setting('app.tok')), null, 'valid link token works');
select is(public.get_set_by_link('10000000-0000-0000-0000-000000000003', 'wrong'), null, 'wrong token returns null');
select is(public.get_set_by_link('10000000-0000-0000-0000-000000000001', current_setting('app.tok')), null, 'token does not unlock other sets');
reset role;

-- anonymous visitor
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select is((select count(*) from public.study_sets), 1::bigint, 'anon sees only the public set');
select is((select count(*) from public.set_share_links), 0::bigint, 'anon cannot read share links') ;
reset role;

-- verify nothing was changed by B, as superuser
select is((select title from public.study_sets where id = '10000000-0000-0000-0000-000000000001'), 'private', 'A''s set untouched');

-- switching away from link kills the token
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;
update public.study_sets set visibility = 'private' where id = '10000000-0000-0000-0000-000000000003';
reset role;
select is(public.get_set_by_link('10000000-0000-0000-0000-000000000003', current_setting('app.tok')), null, 'token dead after set made private');

select * from finish();
rollback;
