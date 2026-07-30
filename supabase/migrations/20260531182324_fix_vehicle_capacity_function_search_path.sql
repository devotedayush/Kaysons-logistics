create or replace function public.vehicle_capacity_category_for_weight(weight_mt numeric)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when coalesce(weight_mt, 0) <= 1 then 'Up to 1 MT'
    when weight_mt <= 3 then 'Up to 3 MT'
    when weight_mt <= 6 then '3-6 MT'
    when weight_mt <= 9 then '6-9 MT'
    when weight_mt <= 12 then '9-12 MT'
    when weight_mt <= 15 then '12-15 MT'
    else '15+ MT'
  end
$$;
