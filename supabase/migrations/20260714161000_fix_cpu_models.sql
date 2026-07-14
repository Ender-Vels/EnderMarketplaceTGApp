with ranked as (
  select id,row_number() over(order by id) rn from public.products where category_key='cpu'
), models as (
  select id,rn,
    case when rn<=15 then 'AMD' else 'Intel' end brand,
    case when rn<=15 then (array['Ryzen 5 7500F','Ryzen 5 7600','Ryzen 5 7600X','Ryzen 5 9600X','Ryzen 7 7700','Ryzen 7 7700X','Ryzen 7 7800X3D','Ryzen 7 9700X','Ryzen 7 9800X3D','Ryzen 9 7900','Ryzen 9 7900X','Ryzen 9 7900X3D','Ryzen 9 7950X','Ryzen 9 7950X3D','Ryzen 9 9950X'])[rn]
    else (array['Core i5-12400F','Core i5-13400F','Core i5-13600K','Core i5-14400F','Core i5-14600K','Core i7-12700K','Core i7-13700K','Core i7-14700K','Core i7-14700F','Core Ultra 7 265K','Core i9-12900K','Core i9-13900K','Core i9-14900K','Core i9-14900KS','Core Ultra 9 285K'])[rn-15] end model
  from ranked
), named as (
  select id,brand,brand||' '||model full_name from models
)
update public.products p set
  manufacturer=n.brand,name=n.full_name,name_uk=n.full_name,name_ru=n.full_name,name_en=n.full_name,
  description_uk='Висока продуктивність для ігор, роботи та творчості. '||n.full_name||'.',
  description_ru='Высокая производительность для игр, работы и творчества. '||n.full_name||'.',
  description_en='High performance for gaming, work and creativity. '||n.full_name||'.',
  description='Висока продуктивність для ігор, роботи та творчості. '||n.full_name||'.',
  specs=jsonb_set(p.specs,'{socket}',to_jsonb(case when n.brand='AMD' then 'AM5' else 'LGA1700' end))
from named n where p.id=n.id;
