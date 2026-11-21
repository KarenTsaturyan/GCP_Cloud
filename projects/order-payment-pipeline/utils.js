/**
 * GCP REST Helpers for Pub/Sub, Secret Manager, and Storage.
 */

const FLOCI_URL = process.env.FLOCI_URL || 'http://localhost:4588';

// Read secret value from Secret Manager (payload is base64)
async function getSecret(projectId, secretName) {
  const url = `${FLOCI_URL}/v1/projects/${projectId}/secrets/${secretName}/versions/latest:access`;
  const res = await fetch(url);
  const data = await res.json();
  return Buffer.from(data.payload.data, 'base64').toString('utf8');
}

// Publish an array of JSON messages to a topic
async function publishBatchMessages(projectId, topicName, payloads) {
  const url = `${FLOCI_URL}/v1/projects/${projectId}/topics/${topicName}:publish`;
  const messages = payloads.map(p => ({
    data: Buffer.from(JSON.stringify(p)).toString('base64')
  }));

  await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ messages })
  });
}

// Pull messages from subscription (leases up to maxMessages with an ackId)
async function pullMessages(projectId, subscriptionName, maxMessages = 50) {
  const url = `${FLOCI_URL}/v1/projects/${projectId}/subscriptions/${subscriptionName}:pull`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ maxMessages, returnImmediately: true })
  });

  const data = await res.json();
  if (!data.receivedMessages) return [];

  return data.receivedMessages.map(item => ({
    ackId: item.ackId,
    order: JSON.parse(Buffer.from(item.message.data, 'base64').toString('utf8'))
  }));
}

// Acknowledge messages: tells Pub/Sub messages were processed, so delete them from queue
async function acknowledgeMessages(projectId, subscriptionName, ackIds) {
  if (!ackIds || ackIds.length === 0) return;
  const url = `${FLOCI_URL}/v1/projects/${projectId}/subscriptions/${subscriptionName}:acknowledge`;
  await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ ackIds })
  });
}

// Upload file to GCS bucket
async function uploadToStorage(bucketName, filePath, jsonContent) {
  const url = `${FLOCI_URL}/upload/storage/v1/b/${bucketName}/o?uploadType=media&name=${encodeURIComponent(filePath)}`;
  await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(jsonContent, null, 2)
  });
}

module.exports = {
  FLOCI_URL,
  getSecret,
  publishBatchMessages,
  pullMessages,
  acknowledgeMessages,
  uploadToStorage
};
