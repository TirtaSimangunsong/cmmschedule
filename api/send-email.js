// POST /api/send-email — sends one teacher their timetable (Admin only).
// Body: { to, subject, html, pdfBase64?, filename? }   Header: Authorization: Bearer <Supabase access token>
// Env: SUPABASE_URL, SUPABASE_ANON_KEY, RESEND_API_KEY, MAIL_FROM
module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
  const url = process.env.SUPABASE_URL, anon = process.env.SUPABASE_ANON_KEY;
  const key = process.env.RESEND_API_KEY, from = process.env.MAIL_FROM;
  if (!key || !from) return res.status(501).json({ error: 'email_not_configured' });
  if (!url || !anon) return res.status(500).json({ error: 'supabase_not_configured' });

  // 1) Who is calling? Check the Supabase session token.
  const token = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!token) return res.status(401).json({ error: 'not_logged_in' });
  const who = await fetch(url + '/auth/v1/user', { headers: { apikey: anon, Authorization: 'Bearer ' + token } });
  if (!who.ok) return res.status(401).json({ error: 'session_expired' });
  const user = await who.json();

  // 2) Only the Admin role may send emails.
  const prof = await fetch(url + '/rest/v1/profiles?select=role&id=eq.' + encodeURIComponent(user.id), {
    headers: { apikey: anon, Authorization: 'Bearer ' + token }
  });
  const rows = prof.ok ? await prof.json() : [];
  if (!rows[0] || rows[0].role !== 'admin') return res.status(403).json({ error: 'admin_only' });

  // 3) Validate and send through Resend.
  const body = req.body || {};
  const to = String(body.to || '').trim();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(to)) return res.status(400).json({ error: 'bad_email' });
  if (!body.subject || !body.html) return res.status(400).json({ error: 'missing_content' });
  const payload = { from, to: [to], subject: String(body.subject).slice(0, 200), html: String(body.html) };
  if (body.pdfBase64) payload.attachments = [{ filename: String(body.filename || 'timetable.pdf'), content: String(body.pdfBase64) }];

  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + key, 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  const out = await r.json().catch(() => ({}));
  if (!r.ok) return res.status(502).json({ error: 'send_failed', detail: out.message || out.name || r.status });
  return res.status(200).json({ ok: true, id: out.id });
};
