const pool = require('../db/pool');

async function checkAjayRecord() {
  try {
    const result = await pool.query(
      `SELECT id, source, message, lat, lng, created_at 
       FROM sos_reports 
       WHERE source = 'sonic_cascade' 
       AND message = 'MESH TEST from Ajay'
       ORDER BY created_at DESC LIMIT 1`
    );
    
    if (result.rows.length > 0) {
      console.log('SUCCESS: Record found!');
      console.log(JSON.stringify(result.rows[0], null, 2));
    } else {
      console.log('NOT FOUND: No record matching Ajay\'s criteria found yet.');
    }
  } catch (err) {
    console.error('DB Error:', err.message);
  } finally {
    process.exit(0);
  }
}

checkAjayRecord();
