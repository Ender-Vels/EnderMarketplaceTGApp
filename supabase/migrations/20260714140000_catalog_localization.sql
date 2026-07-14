alter table public.products add column if not exists manufacturer text not null default 'Other';
alter table public.products add column if not exists name_uk text;
alter table public.products add column if not exists name_ru text;
alter table public.products add column if not exists name_en text;
alter table public.products add column if not exists description_uk text;
alter table public.products add column if not exists description_ru text;
alter table public.products add column if not exists description_en text;
alter table public.products add column if not exists category_key text;

truncate table public.order_items, public.orders, public.products restart identity cascade;

with categories as (
  select * from (values
    ('cpu','Процесори','Процессоры','Processors','Висока продуктивність для ігор, роботи та творчості','Высокая производительность для игр, работы и творчества','High performance for gaming, work and creativity','https://images.unsplash.com/photo-1591799264318-7e6ef8ddb7ea?auto=format&fit=crop&w=900&q=80',4200),
    ('gpu','Відеокарти','Видеокарты','Graphics cards','Сучасна графіка, апаратне прискорення та підтримка нових технологій','Современная графика, аппаратное ускорение и поддержка новых технологий','Modern graphics, hardware acceleration and support for new technologies','https://images.unsplash.com/photo-1591488320449-011701bb6704?auto=format&fit=crop&w=900&q=80',9500),
    ('ram','Оперативна пам’ять','Оперативная память','Memory','Швидка пам’ять для стабільної багатозадачності','Быстрая память для стабильной многозадачности','Fast memory for smooth multitasking','https://images.unsplash.com/photo-1562976540-1502c2145186?auto=format&fit=crop&w=900&q=80',1200),
    ('storage','Накопичувачі','Накопители','Storage','Швидке та надійне зберігання ваших даних','Быстрое и надежное хранение ваших данных','Fast and reliable storage for your data','https://images.unsplash.com/photo-1531492746076-161ca9bcad58?auto=format&fit=crop&w=900&q=80',1400),
    ('motherboard','Материнські плати','Материнские платы','Motherboards','Надійна платформа з актуальними інтерфейсами','Надежная платформа с актуальными интерфейсами','A reliable platform with modern connectivity','https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=900&q=80',3200),
    ('psu','Блоки живлення','Блоки питания','Power supplies','Стабільне живлення та захист усіх компонентів','Стабильное питание и защита всех компонентов','Stable power delivery and component protection','https://images.unsplash.com/photo-1587202372775-e229f172b9d7?auto=format&fit=crop&w=900&q=80',1800)
  ) v(key,uk,ru,en,duk,dru,den,image,base_price)
), generated as (
  select c.*, n,
    case c.key
      when 'cpu' then (array['AMD','Intel','AMD','Intel','AMD'])[1+((n-1)%5)]
      when 'gpu' then (array['ASUS','MSI','Gigabyte','Sapphire','Palit'])[1+((n-1)%5)]
      when 'ram' then (array['Kingston','Corsair','G.Skill','Crucial','Patriot'])[1+((n-1)%5)]
      when 'storage' then (array['Samsung','Kingston','WD','Crucial','Seagate'])[1+((n-1)%5)]
      when 'motherboard' then (array['ASUS','MSI','Gigabyte','ASRock','Biostar'])[1+((n-1)%5)]
      else (array['be quiet!','Corsair','Seasonic','Chieftec','DeepCool'])[1+((n-1)%5)] end manufacturer,
    case c.key
      when 'cpu' then (array['Ryzen 5 7600','Core i5-14400F','Ryzen 7 7700X','Core i7-14700K','Ryzen 9 7900X','Core i9-14900K'])[1+((n-1)/5)]
      when 'gpu' then (array['GeForce RTX 4060','GeForce RTX 4060 Ti','Radeon RX 7700 XT','GeForce RTX 4070 SUPER','Radeon RX 7800 XT','GeForce RTX 4080 SUPER'])[1+((n-1)/5)]
      when 'ram' then (array['Fury 16GB DDR4','Vengeance 32GB DDR5','Ripjaws 32GB DDR5','Pro 48GB DDR5','Viper 64GB DDR5','Dominator 96GB DDR5'])[1+((n-1)/5)]
      when 'storage' then (array['NVMe 500GB','NVMe 1TB','NVMe 2TB','SATA SSD 2TB','NVMe Pro 4TB','HDD 8TB'])[1+((n-1)/5)]
      when 'motherboard' then (array['B550 Gaming','B650 WiFi','Z790 Pro','X670E Gaming','B760 Creator','Z890 Ultra'])[1+((n-1)/5)]
      else (array['Bronze 550W','Bronze 650W','Gold 750W','Gold 850W','Platinum 1000W','Platinum 1200W'])[1+((n-1)/5)] end model
  from categories c cross join generate_series(1,30) n
)
insert into public.products(name,category,description,price,stock,image_url,active,manufacturer,name_uk,name_ru,name_en,description_uk,description_ru,description_en,category_key)
select manufacturer||' '||model, uk, duk,
  base_price + ((n-1)/5)*round(base_price*0.34) + ((n-1)%5)*170,
  case when n%13=0 then 0 else 3+(n*7)%24 end,
  image,true,manufacturer,
  manufacturer||' '||model,manufacturer||' '||model,manufacturer||' '||model,
  duk||'. '||manufacturer||' · '||model||'.',
  dru||'. '||manufacturer||' · '||model||'.',
  den||'. '||manufacturer||' · '||model||'.',key
from generated;

create index if not exists products_category_key_idx on public.products(category_key);
create index if not exists products_manufacturer_idx on public.products(manufacturer);
create index if not exists products_price_idx on public.products(price);

create table if not exists public.telegram_preferences (
  telegram_id bigint primary key,
  language text not null check (language in ('uk','ru','en')),
  updated_at timestamptz not null default now()
);
alter table public.telegram_preferences enable row level security;
revoke all on public.telegram_preferences from anon, authenticated;
