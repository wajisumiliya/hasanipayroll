/** Wait for the disposable database's closing sockets; never kill sessions. */
export async function dropFixtureDatabase(bootstrap, name) {
  if (!/^hasani_[a-z0-9_]+_test$/.test(name)) throw new Error('Unsafe fixture database name');
  for (let attempt = 0; attempt < 100; attempt++) {
    const result = await bootstrap.query('SELECT count(*)::int AS n FROM pg_stat_activity WHERE datname=$1', [name]);
    if (result.rows[0].n === 0) {
      await bootstrap.query(`DROP DATABASE "${name}"`);
      return;
    }
    await new Promise(resolve => setTimeout(resolve, 10));
  }
  throw new Error(`Fixture database ${name} still has open connections after pool shutdown`);
}
