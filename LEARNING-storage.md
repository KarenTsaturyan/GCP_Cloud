# 🧠 Google Cloud Storage (GCS) & Storage Services — DevOps Knowledge Base

> 📖 **Living document.** Follows the practical learning pattern: Core Concepts → Environment Setup → Step-by-Step Hands-On with `gcloud` CLI → Verification after each step → IAM Security & Keyless Access → Cleanup.

---

## Table of Contents

1. [GCP Storage Services Overview & Mental Model](#1-gcp-storage-services-overview--mental-model)
2. [DevOps Use Cases & Architecture](#2-devops-use-cases--architecture)
3. [Environment Setup (Locked Context)](#3-environment-setup-locked-context)
4. [Hands-On Lab: Google Cloud Storage (GCS) Full Flow](#4-hands-on-lab-google-cloud-storage-gcs-full-flow)
   - [4.1 Create a Storage Bucket](#41-create-a-storage-bucket)
   - [4.2 Upload, Download & Inspect Objects](#42-upload-download--inspect-objects)
   - [4.3 Bucket Permissions & IAM Access Control](#43-bucket-permissions--iam-access-control)
   - [4.4 Storage Classes & Lifecycle Management](#44-storage-classes--lifecycle-management)
   - [4.5 Object Versioning & Data Protection](#45-object-versioning--data-protection)
5. [Secure Keyless Access via Service Account](#5-secure-keyless-access-via-service-account)
6. [Cleanup / Space Reclaim](#6-cleanup--space-reclaim)
7. [Floci Emulation Notes](#7-floci-emulation-notes)
8. [Cheatsheet & Common Commands](#8-cheatsheet--common-commands)

---

## 1. GCP Storage Services Overview & Mental Model

Google Cloud provides specialized storage offerings depending on access patterns, protocol, and structure:

| Service | Type | Protocol / Scope | Durability | Equivalent AWS / Azure |
| :--- | :--- | :--- | :--- | :--- |
| **Cloud Storage (GCS)** | Object Storage | HTTP / REST API (Buckets) | 99.999999999% (11 9's) | AWS S3, Azure Blob |
| **Filestore** | Managed File (NFS) | POSIX / NFSv3 (Shared directories) | Regional / Zonal HA | AWS EFS, Azure Files |
| **Local SSD** | Ephemeral Block | NVMe / SCSI attached directly to host | Tied to VM lifecycle | AWS Instance Store |
| **Bigtable** | NoSQL Wide-column DB | Low-latency key-value / analytics | Regional replication | AWS DynamoDB, HBase |
| **Pub/Sub** | Messaging Bus | Event streaming / PubSub topic & sub | Global distributed | AWS SQS/SNS, Kafka |

---

## 2. DevOps Use Cases & Architecture

### Cloud Storage (GCS)
- **CI/CD Pipelines:** Storing build artifacts, test logs, container tarballs, and Helm charts.
- **Terraform / IaC:** Remote backend state storage (`backend "gcs"`).
- **Backups & Disaster Recovery:** Database dumps, persistent disk snapshots, Kubernetes Velero backups.
- **Static Hosting:** Internal docs, static dashboards, and compliance evidence.

### Filestore
- Shared persistence across multiple Kubernetes pods (ReadWriteMany / RWX).
- Legacy file systems migrated to cloud without code rewrites.

### Local SSD
- Ultra-high IOPS cache for CI/CD compilation and temporary ETL staging tables.

### Bigtable
- Massive time-series metrics, telemetry, and observability storage.

### Pub/Sub
- Asynchronous messaging decoupling services, trigger-based pipelines, and log forwarding.

---

## 3. Environment Setup (Locked Context)

All examples below use this single consistent project, bucket, and service account context:

| Variable | Value | Description |
| :--- | :--- | :--- |
| `PROJECT_ID` | `web-prod` | Target GCP project |
| `REGION` | `us-central1` | Regional bucket location |
| `BUCKET_NAME` | `gs://web-prod-artifacts-demo` | Global unique bucket URI |
| `SA_NAME` | `gcs-storage-sa` | Service account for storage access |

### Bash
```bash
source env.sh

export PROJECT_ID="web-prod"
export REGION="us-central1"
export BUCKET_NAME="gs://web-prod-artifacts-demo"
export SA_NAME="gcs-storage-sa"
export SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
```

### PowerShell
```powershell
. .\env.ps1

$PROJECT_ID   = "web-prod"
$REGION       = "us-central1"
$BUCKET_NAME  = "gs://web-prod-artifacts-demo"
$SA_NAME      = "gcs-storage-sa"
$SA_EMAIL     = "${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
```

---

## 4. Hands-On Lab: Google Cloud Storage (GCS) Full Flow

### 4.1 Create a Storage Bucket

Create a regional bucket using the modern `gcloud storage` CLI:

```bash
gcloud storage buckets create $BUCKET_NAME \
  --project=$PROJECT_ID \
  --location=$REGION \
  --default-storage-class=STANDARD \
  --uniform-bucket-level-access
```

> 💡 `--uniform-bucket-level-access` ensures IAM policies control access uniformly across all objects (best practice; disables legacy per-object ACLs).

**Verify — check bucket exists:**
```bash
gcloud storage buckets list --project=$PROJECT_ID
```
**Expected Output:**
```
gs://web-prod-artifacts-demo/
```

**Inspect bucket details:**
```bash
gcloud storage buckets describe $BUCKET_NAME
```

---

### 4.2 Upload, Download & Inspect Objects

#### Step 1: Create local sample files
```bash
echo "Hello from GCP Cloud Storage!" > hello.txt
echo '{"app": "payment-api", "version": "1.0.0"}' > config.json
```

#### Step 2: Upload files to GCS
```bash
# Upload a single file
gcloud storage cp hello.txt $BUCKET_NAME/

# Upload multiple files / directory structure
gcloud storage cp config.json $BUCKET_NAME/configs/config.json
```

**Verify — list files in the bucket:**
```bash
gcloud storage ls $BUCKET_NAME/**
```
**Expected Output:**
```
gs://web-prod-artifacts-demo/configs/config.json
gs://web-prod-artifacts-demo/hello.txt
```

#### Step 3: View file contents directly from GCS
```bash
gcloud storage cat $BUCKET_NAME/hello.txt
```
**Expected Output:**
```
Hello from GCP Cloud Storage!
```

#### Step 4: Download object back to local machine
```bash
gcloud storage cp $BUCKET_NAME/hello.txt ./downloaded-hello.txt
```

---

### 4.3 Bucket Permissions & IAM Access Control

Access to buckets is managed using IAM roles:
- `roles/storage.objectViewer` — Read-only access to objects.
- `roles/storage.objectCreator` — Write-only (good for CI uploaders or logging agents).
- `roles/storage.objectAdmin` — Full read, write, and delete permissions on objects.
- `roles/storage.admin` — Full control over buckets and objects.

#### Grant read access to a specific user or service account on the bucket:
```bash
gcloud storage buckets add-iam-policy-binding $BUCKET_NAME \
  --member="user:devops.engineer@example.com" \
  --role="roles/storage.objectViewer"
```

**Verify bucket IAM policy:**
```bash
gcloud storage buckets get-iam-policy $BUCKET_NAME
```

---

### 4.4 Storage Classes & Lifecycle Management

GCS provides 4 primary storage classes:
1. **Standard:** Frequently accessed data (active builds, web assets).
2. **Nearline:** Accessed less than once a month (monthly reports, backups).
3. **Coldline:** Accessed less than once a quarter (quarterly compliance data).
4. **Archive:** Long-term archival, accessed less than once a year (legal retention).

#### Setting a Lifecycle Rule (e.g., delete objects older than 30 days)
Create a lifecycle configuration file `lifecycle.json`:
```json
{
  "rule": [
    {
      "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
      "condition": {"age": 30, "matchesPrefix": ["backups/"]}
    },
    {
      "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
      "condition": {"age": 90, "matchesPrefix": ["backups/"]}
    },
    {
      "action": {"type": "Delete"},
      "condition": {"age": 365, "matchesSuffix": [".log"]}
    }
  ]
}
```

Apply the lifecycle policy to your bucket:
```bash
gcloud storage buckets update $BUCKET_NAME --lifecycle-file=lifecycle.json
```

**Verify:**
```bash
gcloud storage buckets describe $BUCKET_NAME --format="value(lifecycle_config)"
```

---

### 4.5 Object Versioning & Data Protection

Object versioning prevents accidental deletion or overwriting of state files and release artifacts.

#### Enable versioning:
```bash
gcloud storage buckets update $BUCKET_NAME --versioning
```

**Verify:**
```bash
gcloud storage buckets describe $BUCKET_NAME --format="value(versioning.enabled)"
```
**Expected Output:**
```
True
```

#### Test versioning:
```bash
# Overwrite the file with new content
echo "Updated content v2" > hello.txt
gcloud storage cp hello.txt $BUCKET_NAME/

# List all versions including archived ones
gcloud storage ls --all-versions $BUCKET_NAME/hello.txt
```

---

## 5. Secure Keyless Access via Service Account

Historically, developers downloaded a Service Account JSON key file and stored it in their app or CI/CD pipeline to authenticate with Google Cloud. That is now a major security risk—if that key leaks in a Git repo or logs, anyone can access your data until it is revoked.

In modern DevOps, we use keyless authentication (via Workload Identity Federation for CI/CD runners like GitHub Actions, or Attached Service Accounts for GCP services like Cloud Run and GKE). Instead of giving your app a static password file, you create a dedicated Service Account (an identity for your app), grant it permissions only on the specific bucket it needs, and let Google Cloud issue short-lived, automatic credentials at runtime.

### Step 1: Create a dedicated Service Account for Storage
```bash
gcloud iam service-accounts create $SA_NAME \
  --project=$PROJECT_ID \
  --display-name="GCS App Uploader SA"
```

**Verify SA created:**
```bash
gcloud iam service-accounts list --project=$PROJECT_ID --filter="name:$SA_NAME"
```

### Step 2: Grant the Service Account Object Admin role on the Bucket
```bash
gcloud storage buckets add-iam-policy-binding $BUCKET_NAME \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin"
```

**Verify the binding:**
```bash
gcloud storage buckets get-iam-policy $BUCKET_NAME \
  --format="json"
```

---

## 6. Cleanup / Space Reclaim

To delete uploaded objects and the bucket cleanly:

```bash
# 1. Delete all objects inside the bucket
gcloud storage rm --recursive $BUCKET_NAME/**

# 2. Delete the bucket itself
gcloud storage buckets delete $BUCKET_NAME --quiet

# 3. Delete the demo service account
gcloud iam service-accounts delete $SA_EMAIL --project=$PROJECT_ID --quiet

# 4. Remove temporary local files
rm -f hello.txt config.json downloaded-hello.txt lifecycle.json
```

**Verify everything is cleaned up:**
```bash
gcloud storage buckets list --project=$PROJECT_ID
```

---

## 7. Floci Emulation Notes

| Storage Operation | Floci Support | Notes |
| :--- | :--- | :--- |
| `buckets create` | ✅ Fully Supported | Stores metadata locally in `./data/` |
| `storage cp` (Upload/Download) | ✅ Fully Supported | File bytes are persisted locally |
| `storage ls` | ✅ Fully Supported | Instant local listing |
| `storage cat` | ✅ Fully Supported | Dumps content to terminal |
| `buckets add-iam-policy-binding` | ✅ Fully Supported | Evaluated by Floci IAM engine |
| Object Versioning | ⚠️ Basic | Emulated via local file indexing |
| Lifecycle Rules | ⚠️ Stored | Config stored; auto-purge daemon not active in mock |

---

## 8. Cheatsheet & Common Commands

```bash
# Create bucket
gcloud storage buckets create gs://my-bucket --project=$PROJECT_ID --location=us-central1

# Upload file / folder recursively
gcloud storage cp my-file.txt gs://my-bucket/
gcloud storage cp -r ./build-dist/ gs://my-bucket/artifacts/

# List objects with human-readable sizes
gcloud storage ls --long gs://my-bucket/**

# Stream file content directly
gcloud storage cat gs://my-bucket/app.log

# Sync local folder with bucket (like rsync)
gcloud storage rsync -r ./local-dir gs://my-bucket/remote-dir

# Remove object
gcloud storage rm gs://my-bucket/old-file.txt

# Delete bucket and all its contents
gcloud storage rm --recursive gs://my-bucket/
```
