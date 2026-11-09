// Cria cobrança Pix (Mercado Pago) de R$ 15,00 para desbloquear um contato.
const { SUPABASE_URL: SU, SUPABASE_ANON_KEY: AK, SUPABASE_SERVICE_ROLE_KEY: SK, MP_ACCESS_TOKEN: MP } = process.env;
const UUID = /^[0-9a-f-]{36}$/i;
const sbH = { apikey: SK, Authorization: `Bearer ${SK}` };

module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método inválido' });
  try {
    const token = (req.headers.authorization || '').replace('Bearer ', '');
    const u = await fetch(`${SU}/auth/v1/user`, { headers: { apikey: AK, Authorization: `Bearer ${token}` } });
    if (!u.ok) return res.status(401).json({ error: 'Sessão inválida' });
    const user = await u.json();

    const cid = req.body && req.body.candidate_id;
    if (!UUID.test(cid || '')) return res.status(400).json({ error: 'Candidato inválido' });

    const prof = await fetch(`${SU}/rest/v1/profiles?id=eq.${user.id}&select=role`, { headers: sbH }).then(r => r.json());
    if (!prof[0] || prof[0].role !== 'empresa') return res.status(403).json({ error: 'Apenas empresas' });
    const cand = await fetch(`${SU}/rest/v1/candidates?user_id=eq.${cid}&select=user_id`, { headers: sbH }).then(r => r.json());
    if (!cand[0]) return res.status(404).json({ error: 'Candidato não encontrado' });

    const pay = await fetch('https://api.mercadopago.com/v1/payments', {
      method: 'POST',
      headers: { Authorization: `Bearer ${MP}`, 'Content-Type': 'application/json', 'X-Idempotency-Key': require('crypto').randomUUID() },
      body: JSON.stringify({
        transaction_amount: 15,
        description: 'ConectaNav - desbloqueio de contato',
        payment_method_id: 'pix',
        external_reference: `${user.id}:${cid}`,
        notification_url: `https://${req.headers.host}/api/pix-webhook`,
        payer: { email: user.email }
      })
    }).then(r => r.json());

    const t = pay.point_of_interaction && pay.point_of_interaction.transaction_data;
    if (!t) return res.status(502).json({ error: 'Não foi possível gerar o Pix' });
    res.status(200).json({ payment_id: pay.id, qr_code: t.qr_code, qr_base64: t.qr_code_base64 });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Erro interno' });
  }
};
