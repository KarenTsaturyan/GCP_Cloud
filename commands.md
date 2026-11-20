# Floci GCP — Command Reference & Enabled Services

Comprehensive reference for inspecting services, checking emulator health, and running commands via `gcloud` CLI and REST/PowerShell against local Floci GCP (port `4588`).

---

## 1. Checking Enabled & Available Services

Floci GCP consolidates all services onto port `4588`. You can inspect running services directly from the emulator's runtime endpoints.

### Check Running Services (Health Endpoint)
The health endpoint is the source of truth for all services active inside the emulator container:

* **PowerShell (clean table):**
  ```powershell
  (Invoke-RestMethod http://localhost:4588/health).services.PSObject.Properties |
    Select-Object @{N="Service";E={$_.Name}}, @{N="Status";E={$_.Value}} |
    Format-Table -AutoSize
  ```
* **curl / Bash:**
  ```bash
  curl -s http://localhost:4588/health | jq .services
  ```

### Check Emulator Runtime Metadata
```powershell
curl.exe -s http://localhost:4588/_floci-gcp/info
```
*Expected response:* `{"version":"0.13.0","port":4588,"defaultProject":"floci-local"}`

### Wipe / Reset Emulator State
Wipes all buckets, messages, and secrets between tests without restarting Docker:
```powershell
Invoke-RestMethod -Uri "http://localhost:4588/_floci-gcp/state/reset" -Method Post
```

### View Live Emulator Logs
Inspect incoming requests in real-time:
```bash
docker logs -f floci-gcp
```

---

## 2. All 25 Enabled Services in Floci GCP (v0.13.0)

| Service | Protocol | Key Features / Notes |
| :--- | :--- | :--- |
| **Cloud Storage (`gcs`)** | REST | Buckets, object upload/download, metadata, resumable uploads |
| **Cloud Pub/Sub (`pubsub`)** | REST / gRPC | Topics, pull subscriptions, message publishing & acking |
| **Secret Manager (`secretmanager`)** | REST / gRPC | Secrets, payload versions, `latest:access` |
| **Cloud Firestore (`firestore`)** | gRPC / REST | Document database, collections, batch writes, queries |
| **Cloud Datastore (`datastore`)** | gRPC / REST | Entities, keys, ancestor queries |
| **Cloud Run (`cloudrun`)** | REST / gRPC | Containerized serverless services & revisions |
| **Cloud Functions (`cloudfunctions`)** | REST | Event-driven function invocations |
| **Cloud Tasks (`cloudtasks`)** | REST / gRPC | Asynchronous queue management & task dispatch |
| **BigQuery (`bigquery`)** | REST | Datasets, tables, query jobs |
| **Cloud SQL (`cloudsql`)** | REST | Local instance management |
| **Cloud KMS (`kms`)** | REST / gRPC | Key rings, crypto keys, encrypt/decrypt operations |
| **Eventarc (`eventarc`)** | REST / gRPC | Event routing & triggers |
| **Cloud Scheduler (`scheduler`)** | REST / gRPC | Cron job execution engine |
| **Cloud Logging (`logging`)** | REST / gRPC | Log entries, sinks, write/read logs |
| **Cloud Monitoring (`monitoring`)** | REST / gRPC | Time-series metrics and alerts |
| **IAM (`iam`)** | REST / gRPC | Service accounts, roles, policy simulation |
| **IAM Credentials (`iamcredentials`)** | REST / gRPC | Short-lived token generation |
| **Firebase Auth (`firebaseauth`)** | REST | User records, auth token verification |
| **Compute Engine (`compute`)** | REST | Instance metadata and VM simulation |
| **GKE (`gke`)** | REST | Cluster control plane stubs |
| **Cloud Billing (`cloudbilling`)** | REST | Project billing info stubs |
| **Kafka (`kafka`)** | REST / Native | Managed Kafka cluster emulation |
| **Resource Manager (`resourcemanager`)** | REST / gRPC | Projects, folders, resource hierarchy |
| **Service Usage (`serviceusage`)** | REST | API enablement tracking |
| **STS (`sts`)** | REST | Security Token Service federation |

---

## 3. `gcloud` CLI Commands

Ensure your terminal session has the required overrides configured before running these:

```powershell
. .\env.ps1
```

*(Or set individually:)*
```powershell
$env:CLOUDSDK_CORE_PROJECT = "floci-local"
$env:CLOUDSDK_AUTH_ACCESS_TOKEN = "floci"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_STORAGE = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_PUBSUB = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_SECRETMANAGER = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDRESOURCEMANAGER = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_SERVICEUSAGE = "http://localhost:4588/"
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_IAM = "http://localhost:4588/"
```

### Projects & Resource Manager
```powershell
# Create a local project
gcloud projects create my-project

# List all local projects
gcloud projects list

# Describe a project
gcloud projects describe my-project
```

### IAM (Identity & Access Management)
```powershell
# Create service account (always pass --project to ensure correct email domain)
gcloud iam service-accounts create demo-sa --project=floci-local --display-name="Demo SA"

# List service accounts in project
gcloud iam service-accounts list --project=floci-local

# Describe service account
gcloud iam service-accounts describe demo-sa@floci-local.iam.gserviceaccount.com --project=floci-local
```

### Cloud Storage (GCS)
```powershell
# Create bucket
gcloud storage buckets create gs://my-bucket

# List buckets
gcloud storage buckets list

# Upload file
echo "Hello Floci" > test.txt
gcloud storage cp test.txt gs://my-bucket/test.txt

# List files in bucket
gcloud storage ls gs://my-bucket

# Download file
gcloud storage cp gs://my-bucket/test.txt downloaded.txt

# Delete object & bucket
gcloud storage rm gs://my-bucket/test.txt
gcloud storage buckets delete gs://my-bucket
```

### Cloud Pub/Sub
```powershell
# Create topic
gcloud pubsub topics create my-topic

# List topics
gcloud pubsub topics list

# Create pull subscription
gcloud pubsub subscriptions create my-sub --topic=my-topic

# Publish message
gcloud pubsub topics publish my-topic --message="Hello from gcloud CLI"

# Pull message and automatically acknowledge
gcloud pubsub subscriptions pull my-sub --auto-ack
```

### Secret Manager
```powershell
# Create secret container
gcloud secrets create api-token --replication-policy=automatic

# List secrets
gcloud secrets list

# Add a secret value (version)
echo "super_secret_password_123" | gcloud secrets versions add api-token --data-file=-

# Access latest secret value
gcloud secrets versions access latest --secret=api-token
```

---

## 4. REST / PowerShell Direct Commands (No CLI required)

If you don't have `gcloud` installed, you can interact with all services directly via HTTP:

### Cloud Storage
```powershell
# Create bucket
Invoke-RestMethod -Uri "http://localhost:4588/storage/v1/b?project=floci-local" -Method Post -ContentType "application/json" -Body '{"name": "rest-bucket"}'

# Upload file
curl.exe -s -X POST "http://localhost:4588/upload/storage/v1/b/rest-bucket/o?uploadType=media&name=hello.txt" -H "Content-Type: text/plain" -d "Hello REST"

# Download file
curl.exe -s "http://localhost:4588/storage/v1/b/rest-bucket/o/hello.txt?alt=media"
```

### Cloud Pub/Sub
```powershell
# Create topic
Invoke-RestMethod -Uri "http://localhost:4588/v1/projects/floci-local/topics/rest-topic" -Method Put

# Create subscription
Invoke-RestMethod -Uri "http://localhost:4588/v1/projects/floci-local/subscriptions/rest-sub" -Method Put -ContentType "application/json" -Body '{"topic": "projects/floci-local/topics/rest-topic"}'

# Publish message (data must be Base64)
$b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('{"event": "test"}'))
Invoke-RestMethod -Uri "http://localhost:4588/v1/projects/floci-local/topics/rest-topic:publish" -Method Post -ContentType "application/json" -Body "{`"messages`": [{`"data`": `"$b64`"}]}"

# Pull message
Invoke-RestMethod -Uri "http://localhost:4588/v1/projects/floci-local/subscriptions/rest-sub:pull" -Method Post -ContentType "application/json" -Body '{"maxMessages": 1}'
```

### Secret Manager
```powershell
# Create secret
Invoke-RestMethod -Uri "http://localhost:4588/v1/projects/floci-local/secrets?secretId=rest-secret" -Method Post -ContentType "application/json" -Body '{"replication": {"automatic": {}}}'

# Add version
$b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('my_secret_token'))
Invoke-RestMethod -Uri "http://localhost:4588/v1/projects/floci-local/secrets/rest-secret:addVersion" -Method Post -ContentType "application/json" -Body "{`"payload`": {`"data`": `"$b64`"}}"

# Access secret
$resp = Invoke-RestMethod -Uri "http://localhost:4588/v1/projects/floci-local/secrets/rest-secret/versions/latest:access"
[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($resp.payload.data))
```
