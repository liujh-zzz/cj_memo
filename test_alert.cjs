// 复现前端逻辑
const token = process.argv[2];
async function main() {
  const r = await fetch('http://127.0.0.1:8080/api/shop/buy', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
    body: JSON.stringify({ productId: 5, qty: 1 })
  });
  console.log('Response.ok:', r.ok);
  console.log('Response.status:', r.status);
  const j = await r.json();
  console.log('JSON:', JSON.stringify(j));
  console.log('j?.ok:', j?.ok);
  console.log('!j?.ok → alert 触发条件:', !j?.ok);
}
main().catch(e => console.error('ERR:', e));
