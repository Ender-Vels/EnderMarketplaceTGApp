# Ender Marketplace Telegram Mini App

Vue 3 + Vite магазин комплектуючих для Telegram із каталогом у Supabase, кошиком та захищеним оформленням замовлення через PostgreSQL RPC.

## Локальний запуск

```powershell
npm install
npm run dev
```

Скопіюйте `.env.example` у `.env.local` і вкажіть Supabase URL та publishable key. Секретні ключі й токен Telegram ніколи не додавайте у Vite-змінні.

## База даних

Міграція розташована в `supabase/migrations`. Вона створює каталог, клієнтів, замовлення, RLS і RPC, яка перевіряє підпис Telegram та оформлює замовлення транзакційно.

## Публікація

Push у `main` запускає GitHub Actions і розгортає `dist` у GitHub Pages.

This template should help get you started developing with Vue 3 in Vite. The template uses Vue 3 `<script setup>` SFCs, check out the [script setup docs](https://v3.vuejs.org/api/sfc-script-setup.html#sfc-script-setup) to learn more.

Learn more about IDE Support for Vue in the [Vue Docs Scaling up Guide](https://vuejs.org/guide/scaling-up/tooling.html#ide-support).
