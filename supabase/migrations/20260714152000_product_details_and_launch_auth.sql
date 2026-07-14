alter table public.products add column if not exists specs jsonb not null default '{}'::jsonb;

update public.products set
  image_url = 'https://loremflickr.com/800/600/' || case category_key
    when 'cpu' then 'computer,processor'
    when 'gpu' then 'computer,gpu'
    when 'ram' then 'computer,memory'
    when 'storage' then 'computer,ssd'
    when 'motherboard' then 'computer,motherboard'
    else 'computer,power-supply' end || '?lock=' || (1000 + id),
  specs = case category_key
    when 'cpu' then jsonb_build_object('socket',case when manufacturer='AMD' then 'AM5' else 'LGA1700' end,'cores',6+(id%11)::int,'threads',12+(id%17)::int,'frequency',(3.4+(id%15)*0.1)::numeric(3,1)||' GHz','tdp',(65+(id%5)*20)||' W','warranty','36 months')
    when 'gpu' then jsonb_build_object('memory',(8+(id%4)*4)||' GB','memory_type','GDDR6','interface','PCI Express 4.0','boost_clock',(2400+(id%12)*55)||' MHz','recommended_psu',(550+(id%5)*100)||' W','warranty','36 months')
    when 'ram' then jsonb_build_object('capacity',(16+(id%4)*16)||' GB','type',case when id%3=0 then 'DDR4' else 'DDR5' end,'speed',(3200+(id%7)*600)||' MHz','modules','2','voltage','1.35 V','warranty','Lifetime')
    when 'storage' then jsonb_build_object('capacity',case when id%5=0 then '4 TB' when id%2=0 then '2 TB' else '1 TB' end,'form_factor',case when id%4=0 then '2.5 inch' else 'M.2 2280' end,'interface',case when id%4=0 then 'SATA III' else 'PCIe 4.0 NVMe' end,'read_speed',(3500+(id%8)*500)||' MB/s','write_speed',(2800+(id%7)*450)||' MB/s','warranty','60 months')
    when 'motherboard' then jsonb_build_object('socket',case when id%2=0 then 'AM5' else 'LGA1700' end,'form_factor',case when id%3=0 then 'Micro-ATX' else 'ATX' end,'memory','4 × DDR5','network','2.5 GbE + Wi-Fi 6E','m2_slots',(2+(id%4))::text,'warranty','36 months')
    else jsonb_build_object('power',(550+(id%7)*100)||' W','efficiency',case when id%3=0 then '80 PLUS Platinum' when id%2=0 then '80 PLUS Gold' else '80 PLUS Bronze' end,'modular',case when id%2=0 then 'Yes' else 'Semi-modular' end,'fan','120 mm','protection','OVP / OPP / SCP / OTP','warranty','60 months') end;

create or replace function public.create_bot_order(p_launch_token text, p_payload jsonb)
returns jsonb language plpgsql security definer
set search_path = public, private, extensions as $$
declare
  dot_pos int; encoded_payload text; received_signature text; expected_signature text;
  padded text; launch_user jsonb; token text; user_id bigint; auth_date bigint;
  item jsonb; product_row public.products%rowtype; quantity_value integer;
  total_value numeric(12,2)=0; new_order_id bigint; seen_ids bigint[]='{}';
begin
  dot_pos:=strpos(coalesce(p_launch_token,''),'.');
  if dot_pos<2 then raise exception 'Launch authorization is missing'; end if;
  encoded_payload:=substr(p_launch_token,1,dot_pos-1); received_signature:=substr(p_launch_token,dot_pos+1);
  select bot_token into token from private.telegram_config where singleton=true;
  expected_signature:=encode(hmac(convert_to(encoded_payload,'UTF8'),convert_to(token,'UTF8'),'sha256'),'hex');
  if expected_signature<>received_signature then raise exception 'Invalid launch signature'; end if;
  padded:=translate(encoded_payload,'-_','+/'); padded:=padded||repeat('=',(4-length(padded)%4)%4);
  launch_user:=convert_from(decode(padded,'base64'),'UTF8')::jsonb;
  auth_date:=coalesce((launch_user->>'auth_date')::bigint,0);
  if abs(extract(epoch from now())::bigint-auth_date)>86400 then raise exception 'Launch authorization expired'; end if;
  user_id:=(launch_user->>'id')::bigint;
  if user_id is null then raise exception 'Invalid Telegram user'; end if;
  if jsonb_typeof(p_payload->'items')<>'array' or jsonb_array_length(p_payload->'items')<1 then raise exception 'Cart is empty'; end if;
  if length(trim(p_payload->>'customer_name')) not between 2 and 100 then raise exception 'Invalid customer name'; end if;
  if length(trim(p_payload->>'phone')) not between 7 and 30 then raise exception 'Invalid phone'; end if;
  if p_payload->>'delivery_method' not in ('nova_poshta','pickup') then raise exception 'Invalid delivery method'; end if;
  for item in select * from jsonb_array_elements(p_payload->'items') loop
    if (item->>'product_id')::bigint=any(seen_ids) then raise exception 'Duplicate product'; end if;
    seen_ids:=array_append(seen_ids,(item->>'product_id')::bigint); quantity_value:=(item->>'quantity')::integer;
    if quantity_value not between 1 and 20 then raise exception 'Invalid quantity'; end if;
    select * into product_row from public.products where id=(item->>'product_id')::bigint and active for update;
    if not found then raise exception 'Product is unavailable'; end if;
    if product_row.stock<quantity_value then raise exception 'Not enough stock: %',product_row.name; end if;
    total_value:=total_value+product_row.price*quantity_value;
  end loop;
  insert into public.customers(telegram_id,username,first_name,last_name,phone)
  values(user_id,launch_user->>'username',launch_user->>'first_name',launch_user->>'last_name',trim(p_payload->>'phone'))
  on conflict(telegram_id) do update set username=excluded.username,first_name=excluded.first_name,last_name=excluded.last_name,phone=excluded.phone,updated_at=now();
  insert into public.orders(telegram_id,customer_name,phone,delivery_method,address,comment,total)
  values(user_id,trim(p_payload->>'customer_name'),trim(p_payload->>'phone'),p_payload->>'delivery_method',coalesce(p_payload->>'address',''),coalesce(p_payload->>'comment',''),total_value) returning id into new_order_id;
  for item in select * from jsonb_array_elements(p_payload->'items') loop
    quantity_value:=(item->>'quantity')::integer; select * into product_row from public.products where id=(item->>'product_id')::bigint;
    insert into public.order_items(order_id,product_id,product_name,price,quantity) values(new_order_id,product_row.id,product_row.name,product_row.price,quantity_value);
    update public.products set stock=stock-quantity_value where id=product_row.id;
  end loop;
  return jsonb_build_object('id',new_order_id,'total',total_value);
end $$;
revoke all on function public.create_bot_order(text,jsonb) from public;
grant execute on function public.create_bot_order(text,jsonb) to anon,authenticated;
