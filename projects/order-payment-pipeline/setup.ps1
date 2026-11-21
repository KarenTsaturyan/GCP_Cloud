# ==============================================================================
# Setup Script for Order & Payment Processing Pipeline (PowerShell)
# Run from gcp/projects/order-payment-pipeline/ with: .\setup.ps1
# ==============================================================================

if (Test-Path "..\..\env.ps1") { . ..\..\env.ps1 }
elseif (Test-Path "..\env.ps1") { . ..\env.ps1 }

$PROJECT_ID    = if ($env:PROJECT_ID) { $env:PROJECT_ID } else { "order-platform-prod" }
$TOPIC_NAME    = "orders-topic"
$SUB_PAYMENTS  = "orders-payment-sub"
$SUB_AUDIT     = "orders-audit-sub"
$BUCKET_NAME   = "gs://${PROJECT_ID}-receipts-archive"
$SECRET_NAME   = "payment-gateway-api-key"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🚀 Provisioning GCP Resources for Project: $PROJECT_ID" -ForegroundColor Cyan
Write-Host "=========================================================="

# 1. Project
Write-Host "1. Creating project: $PROJECT_ID..."
gcloud projects create $PROJECT_ID 2>$null

# 2. Pub/Sub Topic and Subscriptions
Write-Host "2. Setting up Cloud Pub/Sub Topic & Subscriptions..."
gcloud pubsub topics create $TOPIC_NAME --project=$PROJECT_ID 2>$null
gcloud pubsub subscriptions create $SUB_PAYMENTS --project=$PROJECT_ID --topic=$TOPIC_NAME 2>$null
gcloud pubsub subscriptions create $SUB_AUDIT --project=$PROJECT_ID --topic=$TOPIC_NAME 2>$null

# 3. GCS Bucket
Write-Host "3. Creating Cloud Storage Archive Bucket: $BUCKET_NAME..."
gcloud storage buckets create $BUCKET_NAME --project=$PROJECT_ID --location="us-central1" --uniform-bucket-level-access 2>$null

# 4. Secret Manager
Write-Host "4. Storing Payment Gateway credentials in Secret Manager..."
gcloud secrets create $SECRET_NAME --project=$PROJECT_ID --replication-policy="automatic" 2>$null
"sk_live_gcp_mock_key_998877665544" | gcloud secrets versions add $SECRET_NAME --project=$PROJECT_ID --data-file=- 2>$null

# 5. Service Accounts
Write-Host "5. Creating Dedicated Service Accounts..."
gcloud iam service-accounts create payment-worker --project=$PROJECT_ID --display-name="Payment Processing Worker SA" 2>$null
gcloud iam service-accounts create audit-archiver --project=$PROJECT_ID --display-name="Audit & Compliance Archiver SA" 2>$null

# 6. IAM Roles
Write-Host "6. Applying IAM Role Bindings..."
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:payment-worker@${PROJECT_ID}.iam.gserviceaccount.com" --role="roles/pubsub.subscriber" | Out-Null
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:payment-worker@${PROJECT_ID}.iam.gserviceaccount.com" --role="roles/secretmanager.secretAccessor" | Out-Null

gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:audit-archiver@${PROJECT_ID}.iam.gserviceaccount.com" --role="roles/pubsub.subscriber" | Out-Null
gcloud storage buckets add-iam-policy-binding $BUCKET_NAME --member="serviceAccount:audit-archiver@${PROJECT_ID}.iam.gserviceaccount.com" --role="roles/storage.objectCreator" | Out-Null

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "✅ All resources provisioned successfully!" -ForegroundColor Green
Write-Host "Pub/Sub Topic:      $TOPIC_NAME"
Write-Host "Sub 1:              $SUB_PAYMENTS"
Write-Host "Sub 2:              $SUB_AUDIT"
Write-Host "Secret:             $SECRET_NAME"
Write-Host "GCS Bucket:         $BUCKET_NAME"
Write-Host "=========================================================="
