/**
 * Order Processing Pipeline (Supports Single & Batch Orders)
 * Demonstrates: Secret Manager -> Pub/Sub (Fan-out) -> Cloud Storage
 */

const fs = require('fs');
const readline = require('readline');
const {
  FLOCI_URL,
  getSecret,
  publishBatchMessages,
  pullMessages,
  acknowledgeMessages,
  uploadToStorage
} = require('./utils');

const PROJECT_ID = 'order-platform-prod';
const TOPIC_NAME = 'orders-topic';
const SUB_PAYMENTS = 'orders-payment-sub';
const SUB_AUDIT = 'orders-audit-sub';
const BUCKET_NAME = `${PROJECT_ID}-receipts-archive`;
const SECRET_NAME = 'payment-gateway-api-key';

function prompt(query) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise(resolve => rl.question(query, ans => { rl.close(); resolve(ans.trim()); }));
}

async function main() {
  console.log(`\n🚀 Target: ${FLOCI_URL} | Project: ${PROJECT_ID}\n`);

  // 1. Get secret from Secret Manager
  const apiKey = await getSecret(PROJECT_ID, SECRET_NAME);
  console.log(`[1] Loaded Secret Key: ${apiKey.slice(0, 10)}...\n`);

  // 2. Read order file (can be a single object or an array of 30+ orders)
  const file = await prompt(`[2] Order file path (press Enter for orders-30.json): `) || 'orders-30.json';
  const rawData = JSON.parse(fs.readFileSync(file, 'utf8'));
  const rawOrders = Array.isArray(rawData) ? rawData : [rawData];

  // Standardize each order
  const orders = rawOrders.map((o, idx) => ({
    ...o,
    orderId: o.orderId || `ord-${Date.now().toString().slice(-4)}-${idx + 1}`,
    status: 'PAID',
    processedAt: new Date().toISOString()
  }));

  // Publish all orders in batch to Pub/Sub
  await publishBatchMessages(PROJECT_ID, TOPIC_NAME, orders);
  console.log(`    Published ${orders.length} order(s) to topic '${TOPIC_NAME}'\n`);

  // 3. Worker 1: Payment Service (Pulls all messages and ACKs in batch)
  const paymentTasks = await pullMessages(PROJECT_ID, SUB_PAYMENTS, 50);
  console.log(`[3] Payment Worker: Pulled ${paymentTasks.length} orders from '${SUB_PAYMENTS}'`);
  const paymentAckIds = paymentTasks.map(t => t.ackId);
  await acknowledgeMessages(PROJECT_ID, SUB_PAYMENTS, paymentAckIds);
  console.log(`    Acknowledged all ${paymentAckIds.length} payments to Pub/Sub.\n`);

  // 4. Worker 2: Audit Service (Pulls all messages, saves each receipt to GCS, and ACKs)
  const auditTasks = await pullMessages(PROJECT_ID, SUB_AUDIT, 50);
  console.log(`[4] Audit Worker: Pulled ${auditTasks.length} orders from '${SUB_AUDIT}'`);
  
  for (const task of auditTasks) {
    const filePath = `receipts/${task.order.orderId}.json`;
    await uploadToStorage(BUCKET_NAME, filePath, task.order);
  }
  console.log(`    Saved ${auditTasks.length} receipts to gs://${BUCKET_NAME}/receipts/`);

  const auditAckIds = auditTasks.map(t => t.ackId);
  await acknowledgeMessages(PROJECT_ID, SUB_AUDIT, auditAckIds);
  console.log(`    Acknowledged all ${auditAckIds.length} audits to Pub/Sub.\n`);

  console.log(`======================================================`);
  console.log(`✅ Success! Stored ${auditTasks.length} order receipts in GCS.`);
  console.log(`List them with: gcloud storage ls gs://${BUCKET_NAME}/receipts/**`);
  console.log(`======================================================\n`);
}

main().catch(err => {
  console.error('Error:', err.message);
});
