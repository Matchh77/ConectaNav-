// Webhook do Mercado Pago: confirma o pagamento direto na API (não confia no corpo recebido) e libera o contato.
const { SUPABASE_URL: SU, SUPABASE_SERVICE_ROLE_KEY: SK, MP_ACCESS_TOKEN: MP } = process.env;
const UUID = /^[0-9a-f-]{36}$/i;

module.exports = async (req, res) => {
  try {
    const id = (req.body && req.body.data && req.body.data.id) || (req.query && (req.query['data.id'] || req.query.id));
    if (!id) return res.status(200).end();
    const p = await fetch(`https://api.mercadopago.com/v1/payments/${encodeURIComponent(id)}`, { headers: { Authorization: `Bearer ${MP}` } }).then(r => r.json());
    if (p.status === 'approved' && Number(p.transaction_amount) >= 15 && p.external_reference) {
      const [company_id, candidate_id] = p.external_reference.split(':');
      if (!UUID.test(company_id || '') || !UUID.test(candidate_id || '')) return res.status(200).end();
      const r = await fetch(`${SU}/rest/v1/unlocks?on_conflict=company_id,candidate_id`, {
        method: 'POST',
        headers: { apikey: SK, Authorization: `Bearer ${SK}`, 'Content-Type': 'application/json', Prefer: 'resolution=ignore-duplicates' },
        body: JSON.stringify({ company_id, candidate_id, method: 'pix', payment_id: String(id) })
      });
      if (!r.ok) return res.status(500).end(); // o Mercado Pago tenta de novo
    }
    res.status(200).end();
  } catch (e) { console.error(e); res.status(500).end(); }
};
