# ConectaNav — deploy no Vercel + Supabase

## 1. Supabase (grátis)
1. Crie um projeto em supabase.com.
2. SQL Editor → cole `supabase/schema.sql` → Run.
3. Authentication → URL Configuration: em *Site URL* e *Redirect URLs* coloque o domínio do Vercel (ex.: `https://conectanav.vercel.app`).
4. Authentication → SMTP: configure um SMTP próprio (Resend, Brevo etc.). O envio padrão do Supabase é muito limitado e não serve para produção.
5. Settings → API: copie `Project URL`, `anon key` e `service_role key`.

## 2. Configurar o app
- Edite `config.js` com `SUPABASE_URL` e `SUPABASE_ANON_KEY` (a anon key é pública; a segurança vem do RLS).
- **Nunca** coloque a `service_role` no front-end.

## 3. Pix (Mercado Pago)
- Crie uma aplicação em mercadopago.com.br/developers e copie o Access Token.
- Teste primeiro com credenciais de teste; só depois use as de produção.

## 4. Vercel
1. Suba esta pasta para um repositório no GitHub e importe no Vercel (ou rode `vercel` pela CLI).
2. Settings → Environment Variables:
   - `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `MP_ACCESS_TOKEN`
3. Deploy. O cron em `vercel.json` chama `/api/keepalive` duas vezes por semana para reduzir o risco de pausa do Supabase gratuito.

## 5. Antes de lançar de verdade
- Revisar a Política de Privacidade com um profissional jurídico (há candidatos de 16–17 anos).
- Conferir os termos do plano Hobby do Vercel (uso comercial) e do Mercado Pago.
- Validar a assinatura (`x-signature`) do webhook, para reforçar a segurança além da checagem direta do pagamento.
- Trocar o Tailwind via CDN por um build próprio (melhor desempenho).
- Alertas por WhatsApp/e-mail ainda não existem: hoje o candidato recebe alerta em tempo real no app (e notificação do navegador, se ativada).
