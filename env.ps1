# ==============================================================================
# Floci GCP — Session Environment Setup for PowerShell
# Run in your shell: . .\env.ps1
# ==============================================================================

$FlociHost = "http://localhost:4588/"
$Project = "floci-local"

Write-Host "Configuring gcloud CLI and GCP SDKs for Floci local emulator..." -ForegroundColor Cyan

# Core GCP Settings
$env:CLOUDSDK_CORE_PROJECT = $Project
$env:CLOUDSDK_AUTH_ACCESS_TOKEN = "floci"
$env:GOOGLE_CLOUD_PROJECT = $Project

# gcloud CLI API Endpoint Overrides (all services on port 4588)
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_STORAGE = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_PUBSUB = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_SECRETMANAGER = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDRESOURCEMANAGER = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_SERVICEUSAGE = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_IAM = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDFUNCTIONS = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_RUN = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDTASKS = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_FIRESTORE = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_DATASTORE = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_BIGQUERY = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDKMS = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_LOGGING = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_MONITORING = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDSCHEDULER = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_EVENTARC = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_SQLADMIN = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_COMPUTE = $FlociHost
$env:CLOUDSDK_API_ENDPOINT_OVERRIDES_CONTAINER = $FlociHost

# Official Google Cloud Client SDK Emulator Hosts (Python, Node.js, Go, Java)
$env:STORAGE_EMULATOR_HOST = "http://localhost:4588"
$env:PUBSUB_EMULATOR_HOST = "localhost:4588"
$env:FIRESTORE_EMULATOR_HOST = "localhost:4588"
$env:DATASTORE_EMULATOR_HOST = "localhost:4588"
$env:SECRET_MANAGER_EMULATOR_HOST = "localhost:4588"
$env:CLOUD_TASKS_EMULATOR_HOST = "localhost:4588"
$env:BIGQUERY_EMULATOR_HOST = "http://localhost:4588"
$env:FIREBASE_AUTH_EMULATOR_HOST = "localhost:4588"

# Helper: Refresh IAM ETag if Floci gets stuck on a + or / character
function Fix-IamEtag {
    param([string]$ProjectId = $env:CLOUDSDK_CORE_PROJECT)
    if (-not $ProjectId) { $ProjectId = "floci-local" }
    $pol = Invoke-RestMethod -Uri "http://localhost:4588/v1/projects/$ProjectId`:getIamPolicy" -Method Post -ContentType "application/json" -Body "{}"
    Invoke-RestMethod -Uri "http://localhost:4588/v1/projects/$ProjectId`:setIamPolicy" -Method Post -ContentType "application/json" -Body (@{ policy = $pol } | ConvertTo-Json -Depth 5) | Out-Null
    Write-Host "✅ IAM ETag refreshed for project: $ProjectId" -ForegroundColor Green
}

Write-Host "✅ Environment configured! All gcloud CLI calls and SDKs will route to $FlociHost" -ForegroundColor Green
