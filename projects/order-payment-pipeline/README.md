# 🚀 Real-World GCP Project: Asynchronous Order & Payment Processing Pipeline

A production-grade, event-driven DevOps pipeline running 100% locally on Floci GCP.

---

## Architecture Overview

```
                      [Web Client / Order Ingestion]
                                    │
                                    ▼
                       [Pub/Sub Topic: orders-topic]
                                    │
              ┌─────────────────────┴─────────────────────┐
              ▼ (Fan-out)                                 ▼ (Fan-out)
    [orders-payment-sub]                         [orders-audit-sub]
              │                                           │
              ▼                                           ▼
       [Payment Worker]                            [Audit Archiver]
              │                                           │
              ▼ (Reads API key)                           ▼ (Saves receipt)
      [Secret Manager]                           [Cloud Storage (GCS)]
  (payment-gateway-api-key)                  (gs://...-receipts-archive)
```

---

## 🔑 GCP Services Practiced

1. **Cloud Pub/Sub (Messaging & Fan-out):** One published order message is delivered in parallel to multiple independent subscribers.
2. **Secret Manager:** Payment worker securely retrieves the API gateway key without hardcoding or unencrypted environment variables.
3. **Cloud Storage (GCS):** The audit worker formats a tamper-evident payment receipt and archives it as an immutable JSON object in GCS.
4. **Cloud IAM (Least Privilege):** 
   - `payment-worker`: only has `roles/pubsub.subscriber` and `roles/secretmanager.secretAccessor`.
   - `audit-archiver`: only has `roles/pubsub.subscriber` and `roles/storage.objectCreator`.

---

## 🛠️ Step-by-Step Instructions

### Step 1: Provision All GCP Resources via CLI

In **Git Bash**:
```bash
cd projects/order-payment-pipeline
./setup.sh
```

In **PowerShell**:
```powershell
cd projects\order-payment-pipeline
.\setup.ps1
```

*This will create the project, topic, subscriptions, GCS bucket, secret, and IAM service account bindings.*

---

### Step 2: Verify Resources with `gcloud` CLI

#### 1. Check Pub/Sub Topic and Subscriptions:
```bash
gcloud pubsub topics list --project=order-platform-prod
gcloud pubsub subscriptions list --project=order-platform-prod
```

#### 2. Check Secret in Secret Manager:
```bash
gcloud secrets list --project=order-platform-prod
gcloud secrets versions access latest --secret=payment-gateway-api-key --project=order-platform-prod
```

#### 3. Check Cloud Storage Bucket:
```bash
gcloud storage buckets list --project=order-platform-prod
```

---

### Step 3: Run the Pipeline

Execute the end-to-end pipeline:
```bash
node pipeline.js
```

**Expected Terminal Output:**
```
======================================================
📦 GCP Order Processing Pipeline Running...
Target Emulator: http://localhost:4588 | Project: order-platform-prod
======================================================

[Step 1] Payment Worker: Accessing secret 'payment-gateway-api-key'...
✅ Retrieved Gateway API Key: sk_live_gc... (Redacted)

[Step 2] Ingest: Publishing new order [ord-341902] to Pub/Sub topic 'orders-topic'...
✅ Order published successfully to topic!

[Step 3] Worker 1: Payment Worker polling subscription 'orders-payment-sub'...
💳 Payment Worker received: Order ord-341902 for $149.99 USD
💳 Authorized payment with Stripe/Gateway Key.
✅ Message ACKed on payment subscription.

[Step 4] Worker 2: Audit Worker polling subscription 'orders-audit-sub'...
📜 Audit Archiver received: Order ord-341902
☁️ Uploading audit receipt to Cloud Storage: gs://order-platform-prod-receipts-archive/receipts/ord-341902.json...
✅ Receipt successfully stored in GCS bucket!
✅ Message ACKed on audit subscription.

======================================================
🎉 Complete End-to-End GCP Pipeline Run Successful!
======================================================
```

---

### Step 4: Verify the Stored Receipts in GCS

List objects in your Cloud Storage bucket:
```bash
gcloud storage ls gs://order-platform-prod-receipts-archive/receipts/**
```

View the generated receipt directly:
```bash
gcloud storage cat gs://order-platform-prod-receipts-archive/receipts/ord-*.json
```

---

### Step 5: Clean Up

To delete all resources when finished:
```bash
# Delete Pub/Sub resources
gcloud pubsub subscriptions delete orders-payment-sub orders-audit-sub --project=order-platform-prod --quiet
gcloud pubsub topics delete orders-topic --project=order-platform-prod --quiet

# Delete Secret
gcloud secrets delete payment-gateway-api-key --project=order-platform-prod --quiet

# Delete GCS Bucket and receipts
gcloud storage rm --recursive gs://order-platform-prod-receipts-archive/
```
