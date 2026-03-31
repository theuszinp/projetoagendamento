# Supabase Storage para Fotos da Instalação

## O que você precisa fazer

1. No Neon, rode [neon_incremental_upgrade.sql](/C:/Users/Matheus/Desktop/projetoagendamento/docs/sql/neon_incremental_upgrade.sql) se o seu banco já existe.
2. No Supabase SQL Editor, rode [supabase_storage_setup.sql](/C:/Users/Matheus/Desktop/projetoagendamento/docs/sql/supabase_storage_setup.sql).
3. No `.env` do backend, mantenha:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY`
4. Se quiser uma configuração mais segura para produção, adicione também:
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `SUPABASE_STORAGE_BUCKET=ticket-attachments`

## Importante

- Com a sua chave publishable atual, o upload só vai funcionar se as policies do bucket forem criadas no Supabase.
- O bucket foi definido como público porque o app mostra as imagens por URL.
- Em produção, o ideal é usar `SUPABASE_SERVICE_ROLE_KEY` no backend. Assim você não depende de policy aberta para upload.
- Se você mudar o nome do bucket, atualize `SUPABASE_STORAGE_BUCKET` no `.env`.

## O que o backend já espera

- Bucket: `ticket-attachments`
- Pasta por serviço: `tickets/{ticketId}/...`
- Tabela Neon usada para metadata: `ticket_attachments`
