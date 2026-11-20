# 🧠 GCP DevOps & Cloud Engineering Knowledge Base

> **Living Knowledge Source** — Continuously updated with your hands-on labs, real-world DevOps scenarios, architecture patterns, and key cloud principles.

---

## 📑 Table of Contents
1. [Core Principles & Mental Models](#1-core-principles--mental-models)
2. [Hands-On Labs Log](#2-hands-on-labs-log)
   - [Lab 1: Project Provisioning & Viewer Role Binding](#lab-1-project-provisioning--viewer-role-binding)
   - [Lab 2: Service Account Creation & Role Assignment](#lab-2-service-account-creation--role-assignment)
3. [Master IAM CLI Walkthrough (1 Project, 1 User, 1 Service Account)](#4-master-iam-cli-walkthrough-1-project-1-user-1-service-account)
   - [Environment Setup (Locked Context)](#environment-setup-locked-context)
   - [Part 1: Human User Lifecycle (Add, Verify, Update, Revoke)](#part-1-human-user-lifecycle)
   - [Part 2: Service Account Lifecycle (Create, Verify, Add Roles, Impersonate, Revoke)](#part-2-service-account-lifecycle)
   - [Part 3: Custom Roles Lifecycle (Create, Verify, Assign, Update, Delete)](#part-3-custom-roles-lifecycle)
   - [Part 4: Other Member Types (Groups, Domains, Public)](#part-4-other-member-types)
4. [Key Rules, Floci Emulation & Interview Notes](#5-key-rules-floci-emulation--interview-notes)
   - [Deep Dive: Why `gcloud iam roles create` returned 404 in Floci](#deep-dive-why-gcloud-iam-roles-create-returned-404-in-floci)

---

## 1. Core Principles & Mental Models

### The GCP IAM Triangle: **WHO** has **WHAT** access **WHERE**

```
    ┌──────────────────────────┐
    │       WHO (Member)       │  user:devops.engineer@example.com
    │  User, Group, or Bot SA  │  serviceAccount:devops-bot@...
    └─────────────┬────────────┘
                  │  Bound together via
                  │  IAM Policy Binding
                  ▼
    ┌──────────────────────────┐
    │       WHAT (Role)        │  roles/viewer (Read-only)
    │  Collection of Perms     │  roles/cloudbuild.builds.editor (Build admin)
    └─────────────┬────────────┘  projects/{id}/roles/customDeployer
                  │  Scoped at
                  ▼
    ┌──────────────────────────┐
    │      WHERE (Resource)    │  Organization -> Folder -> Project -> Resource
    └──────────────────────────┘
```

### The 3 Types of IAM Roles in GCP
| Role Type | Example | Characteristics | Production Recommendation |
| :--- | :--- | :--- | :--- |
| **Basic (Primitive)** | `roles/viewer`, `roles/editor`, `roles/owner` | Coarse-grained, historical legacy. `Editor` has write access across almost *all* GCP services. | ❌ Never use in production pipelines. |
| **Predefined** | `roles/cloudbuild.builds.editor`, `roles/container.developer` | Maintained by Google. Bundles typical job functions for specific services. | ✅ Great starting point for standard workflows. |
| **Custom** | `projects/{id}/roles/gkeDeployer` | User-defined list of exact atomic permissions (e.g. `container.deployments.create`). | 🏆 **Gold Standard for Least Privilege (PoLP)**. |

---

## 2. Hands-On Labs Log

### Lab 1: Project Provisioning & Viewer Role Binding

#### Objective
Provision an isolated cloud project with a unique timestamped identifier and assign a read-only role (`roles/viewer`) to a human engineer.

#### Commands Executed
```bash
# 1. Generate unique project identifier using UNIX epoch timestamp
export PROJECT_ID="devops-iam-demo-$(date +%s)"

# 2. Provision the project and switch active context
gcloud projects create $PROJECT_ID
gcloud config set project $PROJECT_ID

# 3. Attach IAM policy binding granting Viewer access
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:devops.engineer@example.com" \
  --role="roles/viewer"
```

#### What Happens Under the Hood
* `gcloud projects add-iam-policy-binding` triggers `POST /v1/projects/{id}:getIamPolicy`, appends the new member to the `roles/viewer` array, and calls `POST /v1/projects/{id}:setIamPolicy`.
* **Security Result:** `devops.engineer@example.com` can view all resources, metadata, and logs, but cannot create, modify, or delete anything.

---

### Lab 2: Service Account Creation & Role Assignment

#### Objective
Create a non-human identity (**Service Account**) dedicated to an automated CI/CD pipeline and assign it permission to execute and manage Cloud Build pipelines.

#### Commands Executed
```bash
# 1. Create a dedicated Service Account identity (always specify --project to avoid default project mismatch)
gcloud iam service-accounts create devops-bot \
  --project=$PROJECT_ID \
  --display-name="DevOps Pipeline Bot"

# 2. Define the exact Service Account email
export SA_EMAIL="devops-bot@${PROJECT_ID}.iam.gserviceaccount.com"

# 3. Grant Cloud Build Editor role to the Service Account
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/cloudbuild.builds.editor"
```

#### Key Architecture Insights
* **Service Account Email Anatomy:**
  `[SA_NAME]@[PROJECT_ID].iam.gserviceaccount.com`
* **⚠️ Project Mismatch Warning:**
  If you omit `--project=$PROJECT_ID` during creation, `gcloud` creates the service account in your default config project (e.g. `floci-local`). If your policy binding command references `@$PROJECT_ID.iam.gserviceaccount.com` (e.g. `iam-demo-1`), the identities will **not** match, resulting in a silent failure / `403 Forbidden` at runtime! Always specify `--project=$PROJECT_ID`.

---

 ## 3. Master IAM CLI Walkthrough (1 Project, 1 User, 1 Service Account)

A complete, practical command flow demonstrating every variation of adding, inspecting, updating, and revoking IAM bindings.

---

### Environment Setup (Locked Context)
Run these definitions in your terminal first. All commands below strictly use these variables:

* **In Bash / Git Bash / Linux / macOS:**
  ```bash
  export PROJECT_ID="iam-demo-1"
  export USER_EMAIL="alex.dev@example.com"
  export SA_NAME="payment-worker"
  export SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
  ```
* **In PowerShell:**
  ```powershell
  $PROJECT_ID = "iam-demo-1"
  $USER_EMAIL = "alex.dev@example.com"
  $SA_NAME = "payment-worker"
  $SA_EMAIL = "${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
  ```

---

### Part 1: Human User Lifecycle

#### Step 1.1: Grant Viewer Role (Add Binding)
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/viewer"
```

#### Step 1.2: Check & Verify User Binding
```bash
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:$USER_EMAIL" \
  --format="table(bindings.role)"
```
*Expected Output:*
```text
ROLE
roles/viewer
```

#### Step 1.3: Grant a Second Role (Storage Object Viewer)
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/storage.objectViewer"
```

#### Step 1.4: Check & Verify Both Roles are Active

#### Step 1.5: Revoke One Role (Remove Binding)
```bash
gcloud projects remove-iam-policy-binding $PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/viewer"
```

#### Step 1.6: Check & Verify Role Was Revoked

---

### Part 2: Service Account Lifecycle

#### Step 2.1: Create the Service Account (Explicitly in `$PROJECT_ID`)
```bash
gcloud iam service-accounts create $SA_NAME \
  --project=$PROJECT_ID \
  --display-name="Payment Background Worker"
```

#### Step 2.2: Check & Verify the Service Account Exists
```bash
gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID
```
*Expected Output:*
```text
displayName: Payment Background Worker
email: payment-worker@iam-demo-1.iam.gserviceaccount.com
```

#### Step 2.3: Grant Pub/Sub Subscriber Role to the SA
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/pubsub.subscriber"
```

#### Step 2.4: Check & Verify SA Binding
```bash
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:$SA_EMAIL" \
  --format="table(bindings.role)"
```
*Expected Output:*
```text
ROLE
roles/pubsub.subscriber
```

#### Step 2.5: Grant Secret Manager Access to the SA
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/secretmanager.secretAccessor"
```

#### Step 2.6: Check & Verify Multiple Roles on the SA

#### Step 2.7: Allow User to Impersonate the SA (`roles/iam.serviceAccountUser`)
*(Notice: This policy binding is attached directly to the **Service Account resource**, not the project)*
```bash
gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL \
  --project=$PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/iam.serviceAccountUser"
```

#### Step 2.8: Check & Verify the Service Account's Resource Policy
```bash
gcloud iam service-accounts get-iam-policy $SA_EMAIL --project=$PROJECT_ID
```
*Expected Output:*
```yaml
bindings:
- members:
  - user:alex.dev@example.com
  role: roles/iam.serviceAccountUser
```

#### Step 2.9: Revoke Secret Manager Role from the SA
```bash
gcloud projects remove-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/secretmanager.secretAccessor"
```

#### Step 2.10: Check & Verify Revocation on the SA
```bash
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:$SA_EMAIL" \
  --format="table(bindings.role)"
```
*Expected Output:*
```text
ROLE
roles/pubsub.subscriber
```

---

### Part 3: Custom Roles Lifecycle

#### Step 3.1: Create a Custom Role
* **In Live Google Cloud:**
  ```bash
  gcloud iam roles create orderAuditor \
    --project=$PROJECT_ID \
    --title="Order Auditor" \
    --description="Can read storage objects and secrets" \
    --permissions="storage.objects.get,secretmanager.versions.access" \
    --stage="GA"
  ```
* **In Local Floci Emulator (Direct REST call):**
  *PowerShell:*
  ```powershell
  Invoke-RestMethod -Uri "http://localhost:4588/v1/projects/$PROJECT_ID/roles" -Method Post -ContentType "application/json" -Body '{"roleId": "orderAuditor", "role": {"title": "Order Auditor", "description": "Can read storage objects and secrets", "includedPermissions": ["storage.objects.get", "secretmanager.versions.access"]}}'
  ```
  *Bash:*
  ```bash
  curl -s -X POST "http://localhost:4588/v1/projects/$PROJECT_ID/roles" -H "Content-Type: application/json" -d '{"roleId": "orderAuditor", "role": {"title": "Order Auditor", "includedPermissions": ["storage.objects.get", "secretmanager.versions.access"]}}'
  ```

#### Step 3.2: Check & Verify Custom Role Details
```bash
gcloud iam roles describe orderAuditor --project=$PROJECT_ID
```
*Expected Output:*
```text
description: Can read storage objects and secrets
includedPermissions:
- secretmanager.versions.access
- storage.objects.get
name: projects/iam-demo-1/roles/orderAuditor
title: Order Auditor
```

#### Step 3.3: Assign Custom Role to the Service Account
*(Custom roles use path: `projects/[PROJECT_ID]/roles/[ROLE_ID]`)*
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="projects/$PROJECT_ID/roles/orderAuditor"
```

#### Step 3.4: Check & Verify Custom Role is Bound
```bash
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:$SA_EMAIL" \
  --format="table(bindings.role)"
```
*Expected Output:*
```text
ROLE
projects/iam-demo-1/roles/orderAuditor
roles/pubsub.subscriber
```

#### Step 3.5: Revoke Custom Role from the Service Account
```bash
gcloud projects remove-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="projects/$PROJECT_ID/roles/orderAuditor"
```

#### Step 3.6: Check & Verify Custom Role Revocation
```bash
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:$SA_EMAIL" \
  --format="table(bindings.role)"
```
*Expected Output:*
```text
ROLE
roles/pubsub.subscriber
```

---

### Part 4: Other Member Types

GCP supports 5 distinct member prefixes:

| Prefix | Example Syntax | When to Use in Production |
| :--- | :--- | :--- |
| **`user:`** | `user:alex.dev@example.com` | Individual human account (Google Workspace or Gmail). |
| **`serviceAccount:`** | `serviceAccount:bot@project.iam.gserviceaccount.com` | Automated app, background job, or CI/CD runner. |
| **`group:`** | `group:devops-team@example.com` | **Enterprise Best Practice:** Manage team membership in Google Workspace; assign roles to groups, not individuals. |
| **`domain:`** | `domain:mycompany.com` | Grants everyone in the organization domain access. |
| **`allUsers`** / **`allAuthenticatedUsers`** | `allUsers` (public) | Static web hosting (e.g. public GCS bucket object reader). |

#### Example: Grant & Verify a Google Group
```bash
# 1. Grant Group Viewer Role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="group:devops-team@example.com" \
  --role="roles/viewer"

# 2. Check & Verify Group Binding
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:devops-team" \
  --format="table(bindings.role)"
```
*Expected Output:*
```text
ROLE
roles/viewer
```

---

## 4. Key Rules, Floci Emulation & Interview Notes

### Deep Dive: Why `gcloud iam roles create` returned 404 in Floci

When you executed:
```powershell
gcloud iam roles create gkeWorkloadDeployer --project="iam-demo-1" ...
# ERROR: (gcloud.iam.roles.create) HTTPError 404: <html><body><h1>Resource not found</h1></body></html>
```

Here is **exactly** what happened behind the scenes:

1. **The Hidden `gcloud` Pre-Validation Call:**
   Before creating a custom role, the `gcloud` CLI automatically makes a preliminary query to:
   `POST /v1/permissions:queryTestablePermissions?alt=json`
   This is a client-side sanity check where `gcloud` asks Google Cloud: *"Are these strings valid permission names in Google's central dictionary of 5,000+ permissions?"*
2. **The Local Emulator Limitation:**
   Floci is a lightweight local emulator. It does not carry Google's massive global catalog of 5,000+ permissions, so the `queryTestablePermissions` endpoint returns `404 Not Found`. Seeing the 404 on the pre-check, `gcloud` aborts before sending the role creation request.
3. **Floci's Actual Role Endpoint DOES Work:**
   Floci's backend implements the real Custom Roles REST endpoint (`POST /v1/projects/{project}/roles`). When you call it directly via `Invoke-RestMethod` or `curl`, the role is created instantly, saved in `data/`, and all subsequent `gcloud` commands (`gcloud iam roles list`, `gcloud iam roles describe`, `gcloud projects add-iam-policy-binding`) work with zero issues!
4. **Behavior in Live GCP Production:**
   In real Google Cloud, `gcloud iam roles create` succeeds out-of-the-box because Google's live API implements `permissions:queryTestablePermissions`.

---

### Essential Interview & Certification Principles

1. **Role ID Path Rules:**
   * Predefined roles: `roles/[NAME]` (e.g. `roles/viewer`, `roles/storage.admin`)
   * Project-level custom roles: `projects/[PROJECT_ID]/roles/[ROLE_ID]`
   * Organization-level custom roles: `organizations/[ORG_ID]/roles/[ROLE_ID]`
2. **Principle of Least Privilege (PoLP):**
   * Never assign primitive roles (`roles/owner`, `roles/editor`) to CI/CD service accounts.
   * A service account should only have permissions required to deploy resources, never to delete shared infrastructure (like GKE clusters or VPC networks).
3. **Service Account Key Hygiene:**
   * Avoid exporting static JSON service account keys (`gcloud iam service-accounts keys create`). Keys can be leaked in Git repositories.
   * Prefer **Workload Identity Federation** (for GitHub Actions, GitLab, AWS) and attached service accounts (for Cloud Build, Cloud Run, GKE).
4. **Resource Hierarchy & Inheritance:**
   * Permissions flow downward: `Organization -> Folder -> Project -> Resource`.
   * An IAM role granted at the Organization or Folder level **cannot** be revoked or overridden at the Project level. Access is additive.

---

### Troubleshooting: Why `gcloud` Commands Lag in Git Bash on Windows

If you run `gcloud` in Git Bash (MINGW64) and it takes 5–15 seconds to finish or feels sluggish, there are 3 main causes:

1. **MSYS POSIX Path Conversion (`--role="roles/viewer"`):**
   * Git Bash intercepts arguments containing slashes and tries to check if `roles/viewer` is a Windows filesystem path.
   * **Fix:** Add `export MSYS_NO_PATHCONV=1` to disable path translation for CLI flags.
2. **The Bash Wrapper Script vs `gcloud.cmd`:**
   * In Git Bash, `gcloud` runs a bash wrapper script that spawns a slow Python process across MSYS pseudo-terminals (mintty).
   * **Fix:** Use `gcloud.cmd` directly, or alias it: `alias gcloud="gcloud.cmd"`.
3. **GCE Metadata Checks & Usage Telemetry:**
   * By default, `gcloud` tries to reach Google's GCE metadata IP (`169.254.169.254`), which times out when running locally.
   * **Fix:** Disable metadata checks: `export CLOUDSDK_CORE_CHECK_GCE_METADATA="false"` and `gcloud config set core/check_gce_metadata false`.

*(All 3 optimizations are pre-packaged in [`env.sh`](./env.sh)—just run `source env.sh`)*.

---

### Concept: ETags & Optimistic Concurrency Control in GCP IAM

Whenever you see an error like:
```text
Resource in projects [iam-demo-1:setIamPolicy] is the subject of a conflict:
There were concurrent policy changes... The request's ETag did not match the current policy's ETag.
```

Here is what is happening under the hood:

#### 1. What is an ETag?
In GCP, every IAM policy has a unique hash/fingerprint called an **ETag** (e.g. `etag: SThlna51jEM=`).

#### 2. The Read-Modify-Write Concurrency Cycle
To prevent two admins or automated scripts from accidentally overwriting each other's changes:
1. **Read:** `gcloud` fetches the current policy and its current ETag (`getIamPolicy`).
2. **Modify:** `gcloud` removes or adds the binding locally in memory.
3. **Write:** `gcloud` sends the new policy back along with the original ETag (`setIamPolicy`).
4. **Validation:** GCP checks: *“Has anyone else modified this policy since step 1?”*
   - If someone did, the server's ETag has changed, and GCP rejects your update with a **409 Conflict** so you don't overwrite changes you haven't seen!

#### 3. The Local Emulator Base64 Quirk (`+` vs `-` and `/` vs `_`)
Notice the error you encountered:
```text
Request's ETag: 'Sh6peB-PeEE='  (contains a hyphen -)
Server's  ETag: 'Sh6peB+PeEE='  (contains a plus   +)
```
* Google's `gcloud` CLI automatically converts Base64 strings to **URL-Safe Base64** (replacing `+` with `-` and `/` with `_`).
* The local Floci emulator generates standard Base64 (with `+` and `/`) and performs an exact string match.
* Whenever Floci generates an ETag that contains `+` or `/`, `gcloud`'s URL-safe normalization causes a false-positive conflict.
* In live Google Cloud, this never happens because Google's live API natively uses URL-Safe Base64 throughout.
* **Resolution in Floci:** 
  1. Simply re-run your `add-iam-policy-binding` or `remove-iam-policy-binding` command.
  2. If it is stuck, run the helper command `fix-iam-etag` (or `./fix-etag.sh`) to force Floci to regenerate a clean alphanumeric ETag.
  3. Or run the 1-liner directly in your terminal:
     ```bash
     P=$(curl -s -X POST "http://localhost:4588/v1/projects/$PROJECT_ID:getIamPolicy" -H "Content-Type: application/json" -d "{}")
     curl -s -X POST "http://localhost:4588/v1/projects/$PROJECT_ID:setIamPolicy" -H "Content-Type: application/json" -d "{\"policy\": $P}"
     ```
