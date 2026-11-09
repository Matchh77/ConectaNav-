// Chamado por cron (vercel.json) para evitar a pausa por inatividade do Supabase gratuito.
module.exports = async (req, res) => {
  const r = await fetch(`${process.env.SUPABASE_URL}/rest/v1/jobs?select=id&limit=1`, {
    headers: { apikey: process.env.SUPABASE_ANON_KEY, Authorization: `Bearer ${process.env.SUPABASE_ANON_KEY}` }
  });
  res.status(200).json({ ok: r.ok });
};
