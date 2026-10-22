const DAY_MS = 86400000;

// One public launch clock, independent of employee adoption and payroll data.
// Called inside the application's existing startup transaction/advisory lock.
export async function ensureMysteryEggCampaign(client) {
  await client.query(`CREATE TABLE IF NOT EXISTS app_private.mystery_egg_campaign (
    id integer PRIMARY KEY CHECK (id = 1),
    started_at timestamptz NOT NULL DEFAULT now()
  )`);
  await client.query('REVOKE ALL ON app_private.mystery_egg_campaign FROM PUBLIC');
  await client.query(`INSERT INTO app_private.mystery_egg_campaign(id)
    VALUES (1) ON CONFLICT (id) DO NOTHING`);
}

export function installMysteryEggApi(app, { pool }) {
  // Public login-page metadata only. No accounts, employee IDs or mutations.
  app.get('/api/mystery-eggs', async (_req, res) => {
    res.set('Cache-Control', 'no-store');
    try {
      const { rows: [row] } = await pool.query(`SELECT started_at, now() AS server_now
        FROM app_private.mystery_egg_campaign WHERE id = 1`);
      if (!row) return res.status(503).json({ ok: false, message: 'Surprise temporarily unavailable' });
      const startedAt = new Date(row.started_at);
      const serverNow = new Date(row.server_now);
      const ageDays = Math.max(0, Math.floor((serverNow - startedAt) / DAY_MS));
      return res.json({ ok: true, egg: {
        startedAt: startedAt.toISOString(),
        hatchAt: new Date(startedAt.getTime() + 3 * DAY_MS).toISOString(),
        serverNow: serverNow.toISOString(),
        stage: ageDays < 3 ? 'egg' : ageDays < 15 ? 'chick' : ageDays < 45 ? 'juvenile' : 'adult',
      } });
    } catch {
      return res.status(503).json({ ok: false, message: 'Surprise temporarily unavailable' });
    }
  });
}
