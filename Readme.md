# GCP Local Environment (Floci)

Run and test Google Cloud Platform (GCP) services locally on port `4588` using Floci GCP—no cloud account, billing, or real credentials needed.

> 🧠 **Active Knowledge Base & Labs:** Check out your living hands-on learning log and DevOps scenarios in **[`LEARNING.md`](./LEARNING.md)**.

---

## 1. How to Run

### Start the Emulator
From this directory (`gcp/`):

```powershell
docker compose up -d
```

### Stop the Emulator
```powershell
docker compose down
```

> **Data Persistence:** State is saved in the local `./data` folder across restarts. To reset everything, delete `./data` or call the reset endpoint: `curl.exe -X POST http://localhost:4588/_floci-gcp/state/reset`.

---

## 2. How to Check if `gcloud` CLI Works with Floci

Floci runs locally on `http://localhost:4588/`. You must tell `gcloud` to route its API calls to Floci instead of Google's live servers.

### Step 1: Load Environment Variables
Run this one-liner in your active PowerShell window (from the `gcp/` directory):

```powershell
. .\env.ps1
```

*(On Linux / macOS / Git Bash, run: `source env.sh`)*

### Step 2: Run the Verification Probe
```powershell
gcloud storage buckets list
```

### Step 3: Interpret the Result

| Result | What It Means |
| :--- | :--- |
| **✅ Success:** Returns buckets (or empty output) immediately without asking for login. | `gcloud` is connected to Floci! |
| **❌ Routed to live Google:** Prompted to run `gcloud auth login` or got `401 Unauthorized / Anonymous caller does not have access`. | Endpoint overrides are missing for that service. Re-run Step 1 in your active shell. |
| **❌ Connection Refused:** `Failed to connect to localhost port 4588`. | Floci container is stopped. Run `docker compose up -d`. |
| **❌ Command Not Found:** `'gcloud' is not recognized`. | CLI not installed. Install via `winget install --id Google.CloudSDK --exact`. |

*(To double-check from Floci's side, run `docker logs --tail 5 floci-gcp`—you will see `Incoming request: GET /storage/v1/b`.)*

---

## 3. All Services Environment Variables Reference

GCP uses two types of environment variables:
1. **`CLOUDSDK_API_ENDPOINT_OVERRIDES_<SERVICE>`**: Used by the `gcloud` CLI to redirect REST API requests to port `4588`.
2. **`<SERVICE>_EMULATOR_HOST`**: Used by official client SDKs (Python, Node.js, Go, Java) to connect over HTTP or gRPC.

### Complete PowerShell Block (All Services)
Copy and paste this into PowerShell to enable every Floci GCP service:

```powershell
# Core Project & Auth (Bypasses Google Login)
$env:CLOUDSDK_CORE_PROJECT = "floci-local"
$env:CLOUDSDK_AUTH_ACCESS_TOKEN = "floci"
$env:GOOGLE_CLOUD_PROJECT = "floci-local"

# gcloud CLI API Endpoint Overrides
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_STORAGE = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_PUBSUB = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_SECRETMANAGER = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDRESOURCEMANAGER = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_SERVICEUSAGE = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_IAM = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDFUNCTIONS = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_RUN = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDTASKS = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_FIRESTORE = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_DATASTORE = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_BIGQUERY = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDKMS = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_LOGGING = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_MONITORING = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDSCHEDULER = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_EVENTARC = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_SQLADMIN = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_COMPUTE = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_CONTAINER = "http://localhost:4588/"

# Client Library SDK Emulators (Python, Node.js, Go)
$env:STORAGE_EMULATOR_HOST = "http://localhost:4588"
$env:PUBSUB_EMULATOR_HOST = "localhost:4588"
$env:FIRESTORE_EMULATOR_HOST = "localhost:4588"
$env:DATASTORE_EMULATOR_HOST = "localhost:4588"
$env:SECRET_MANAGER_EMULATOR_HOST = "localhost:4588"
$env:CLOUD_TASKS_EMULATOR_HOST = "localhost:4588"
$env:BIGQUERY_EMULATOR_HOST = "http://localhost:4588"
$env:FIREBASE_AUTH_EMULATOR_HOST = "localhost:4588"
```

### Complete Bash / Linux / macOS Block
```bash
# Core Project & Auth
export CLOUDSDK_CORE_PROJECT="floci-local"
export CLOUDSDK_AUTH_ACCESS_TOKEN="floci"
export GOOGLE_CLOUD_PROJECT="floci-local"

# gcloud CLI API Endpoint Overrides
export CLOUDSDK_API_ENDPOINT_OVERRIDES_STORAGE="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_PUBSUB="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_SECRETMANAGER="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDRESOURCEMANAGER="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_SERVICEUSAGE="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_IAM="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDFUNCTIONS="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_RUN="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDTASKS="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_FIRESTORE="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_DATASTORE="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_BIGQUERY="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDKMS="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_LOGGING="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_MONITORING="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDSCHEDULER="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_EVENTARC="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_SQLADMIN="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_COMPUTE="http://localhost:4588/"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_CONTAINER="http://localhost:4588/"

# Client Library SDK Emulators
export STORAGE_EMULATOR_HOST="http://localhost:4588"
export PUBSUB_EMULATOR_HOST="localhost:4588"
export FIRESTORE_EMULATOR_HOST="localhost:4588"
export DATASTORE_EMULATOR_HOST="localhost:4588"
export SECRET_MANAGER_EMULATOR_HOST="localhost:4588"
export CLOUD_TASKS_EMULATOR_HOST="localhost:4588"
export BIGQUERY_EMULATOR_HOST="http://localhost:4588"
export FIREBASE_AUTH_EMULATOR_HOST="localhost:4588"
```

---

## 4. Quick Default Commands

### Check Emulator Health & Enabled Services
```powershell
curl.exe -s http://localhost:4588/health
```

### Projects & Resource Manager
```powershell
# Create project
gcloud projects create my-demo-project

# List projects
gcloud projects list
```

### IAM (Identity & Access Management)
```powershell
# Create service account (pass --project to set email domain)
gcloud iam service-accounts create demo-sa --project=floci-local --display-name="Demo SA"

# List service accounts
gcloud iam service-accounts list --project=floci-local
```

### Cloud Storage (GCS)
```powershell
# Create bucket
gcloud storage buckets create gs://dev-bucket

# Upload file
echo "Hello Floci GCP" > test.txt
gcloud storage cp test.txt gs://dev-bucket/

# List files
gcloud storage ls gs://dev-bucket/
```

### Cloud Pub/Sub
```powershell
# Create topic & subscription
gcloud pubsub topics create dev-topic
gcloud pubsub subscriptions create dev-sub --topic=dev-topic

# Publish message
gcloud pubsub topics publish dev-topic --message="Hello from local PubSub"

# Pull and acknowledge message
gcloud pubsub subscriptions pull dev-sub --auto-ack
```

### Secret Manager
```powershell
# Create secret
gcloud secrets create db-password --replication-policy=automatic

# Store value
echo "my_secure_db_pass" | gcloud secrets versions add db-password --data-file=-

# Retrieve value
gcloud secrets versions access latest --secret=db-password
```

---

## 📖 Full Command List & Enabled Services

For the complete list of all 25 enabled services (BigQuery, Firestore, Cloud Run, Cloud Tasks, etc.), REST/PowerShell alternatives, and advanced commands, see **[`commands.md`](./commands.md)**.
