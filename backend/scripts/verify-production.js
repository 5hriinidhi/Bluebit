const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

async function verifyAjayProduction() {
  const url = 'https://bluebit-production.up.railway.app/api/sos/heatmap?limit=10';
  console.log(`Checking production URL: ${url}`);
  
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const reports = await response.json();
    const ajayReport = reports.find(r => 
      r.source === 'sonic_cascade' && 
      r.message.includes('Ajay')
    );
    
    if (ajayReport) {
      console.log('✅ SUCCESS: Found Ajay\'s record on Production!');
      console.log(JSON.stringify(ajayReport, null, 2));
    } else {
      console.log('❌ NOT FOUND: Could not find Ajay\'s report in the last 10 records.');
      console.log('Most recent records:');
      reports.slice(0, 3).forEach(r => {
        console.log(`- [${r.created_at}] ${r.source}: ${r.message}`);
      });
    }
  } catch (err) {
    console.error('Error fetching from production:', err.message);
  }
}

verifyAjayProduction();
