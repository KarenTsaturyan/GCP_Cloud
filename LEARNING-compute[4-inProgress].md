# 🧠 GCP Compute Engine — DevOps Knowledge Base

> 📖 **Living document.** Every new command run, error hit, and fix discovered gets added here. This is your personal GCP Compute Engine field guide.

---

## Table of Contents

1. [Core Concepts & Mental Model](#1-core-concepts--mental-model)
2. [Environment Setup](#2-environment-setup)
3. [VM Lifecycle — Full CRUD Flow](#3-vm-lifecycle--full-crud-flow)
4. [Startup Scripts — Configuration as Code](#4-startup-scripts--configuration-as-code)
5. [Firewall Rules — Network Access Control](#5-firewall-rules--network-access-control)
6. [Custom Images — Standardized Base Images](#6-custom-images--standardized-base-images)
7. [Instance Templates & Managed Instance Groups (MIGs)](#7-instance-templates--managed-instance-groups-migs)
8. [SSH & Remote Access](#8-ssh--remote-access)
9. [Real-World DevOps Scenario](#9-real-world-devops-scenario)
10. [Floci Emulation Notes](#10-floci-emulation-notes)
11. [Cheatsheet & Key Rules](#11-cheatsheet--key-rules)

---

## 1. Core Concepts & Mental Model

### What Is Compute Engine?
Compute Engine is GCP's **IaaS** layer — you get raw virtual machines (VMs) you fully control. No managed runtimes. You pick the OS, install software, and decide how it runs.

**When to use it:**
- Need full OS control (custom kernel, OS tuning)
- Running software that isn't containerized yet
- Stateful workloads (databases, game servers, legacy apps)
- Building a base image for a container fleet

### AWS → GCP Mental Model

| AWS Concept | GCP Equivalent | Notes |
|---|---|---|
| EC2 Instance | Compute Engine Instance | Same idea — a VM |
| AMI | Custom Image | Snapshot of a disk you can reuse |
| Security Group | Firewall Rule | GCP uses network tags to target rules |
| User Data / Launch Script | Startup Script | Runs at boot |
| EBS Volume | Persistent Disk | Block storage attached to VM |
| Auto Scaling Group | Managed Instance Group (MIG) | Auto-scales from an Instance Template |
| Launch Template | Instance Template | Blueprint for creating VMs |
| Placement Group | — | GCP handles placement automatically |
| Key Pair | SSH Keys (metadata) | Added to VM metadata or project-wide |

### Key Terms

| Term | What It Is |
|---|---|
| **Instance** | A running VM in a GCP zone |
| **Zone** | Single data center (`us-central1-a`) |
| **Region** | A group of zones (`us-central1`) |
| **Machine Type** | CPU + RAM spec (`e2-micro`, `n1-standard-4`) |
| **Boot Disk** | Persistent disk with the OS — attached at launch |
| **Startup Script** | Shell script that runs when the VM first boots |
| **Firewall Rule** | Allow/deny traffic by tag, protocol, port |
| **Network Tag** | Label applied to a VM; firewall rules target tags |
| **Instance Template** | Immutable blueprint for a VM (image + type + script) |
| **Managed Instance Group (MIG)** | Auto-scaling fleet of identical VMs from a template |
| **Custom Image** | A saved snapshot of a VM's disk — reusable as a base OS |

---

## 2. Environment Setup

### Locked Context (used throughout this entire document)

| Variable | Value |
|---|---|
| Project | `web-prod` |
| VM name | `api-server` |
| Zone | `us-central1-a` |
| Region | `us-central1` |
| Machine type | `e2-micro` |
| Image family | `ubuntu-2004-lts` |
| Network tag | `http-server` |

### Bash
```bash
source env.sh   # loads Floci overrides

export PROJECT_ID="web-prod"
export ZONE="us-central1-a"
export REGION="us-central1"
export VM_NAME="api-server"
export MACHINE_TYPE="e2-micro"
export IMAGE_FAMILY="ubuntu-2004-lts"
export IMAGE_PROJECT="ubuntu-os-cloud"
export TAG="http-server"
```

### PowerShell
```powershell
. .\env.ps1   # loads Floci overrides

$PROJECT_ID   = "web-prod"
$ZONE         = "us-central1-a"
$REGION       = "us-central1"
$VM_NAME      = "api-server"
$MACHINE_TYPE = "e2-micro"
$IMAGE_FAMILY = "ubuntu-2004-lts"
$IMAGE_PROJECT= "ubuntu-os-cloud"
$TAG          = "http-server"
```

> ⚠️ **Always load env first.** Without endpoint overrides, every `gcloud compute` call goes to live GCP and fails with auth errors.

---

## 3. VM Lifecycle — Full CRUD Flow

### 3.0 — Prerequisites (VPC Network, Subnet & Boot Disk)

In a new or custom GCP project (and inside Floci emulator), the `default` VPC subnetwork and local OS image repository must be initialized before launching an instance.

#### Step 1: Create the VPC Network and Subnet
```bash
# 1. Create custom VPC network
gcloud compute networks create default \
  --project=$PROJECT_ID \
  --subnet-mode=custom

# 2. Create the regional subnet in us-central1
gcloud compute networks subnets create default \
  --project=$PROJECT_ID \
  --network=default \
  --region=$REGION \
  --range=10.128.0.0/20
```

#### Step 2: Create a Boot Disk (Required in Floci)
In live GCP, `--image-family` points to Google-managed public projects (`ubuntu-os-cloud`). In Floci, public image clouds are not downloaded locally, so we create a local persistent boot disk first:
```bash
gcloud compute disks create boot-disk-1 \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --size=10GB
```

**Verify disk created:**
```bash
gcloud compute disks list --project=$PROJECT_ID
```
```
NAME         ZONE           SIZE_GB  TYPE         STATUS
boot-disk-1  us-central1-a  10       pd-standard  READY
```

---

### 3.1 — Create a VM

Launch the VM attached to our network and boot disk:

```bash
gcloud compute instances create $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --machine-type=$MACHINE_TYPE \
  --disk=name=boot-disk-1,boot=yes \
  --tags=$TAG \
  --network=default \
  --subnet=default
```

> 💡 **Live GCP vs Floci:** In live GCP, you can omit `--disk` and use `--image-family=ubuntu-2004-lts --image-project=ubuntu-os-cloud`. In Floci, attaching `--disk=name=boot-disk-1,boot=yes` works immediately without downloading external multi-GB images.

**Verify — list instances:**
```bash
gcloud compute instances list --project=$PROJECT_ID
```

**Expected output:**
```
NAME        ZONE           MACHINE_TYPE  PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP  STATUS
api-server  us-central1-a  e2-micro                   10.128.0.2   203.0.113.1  RUNNING
```

> 💡 `--tags` applies a network tag. Firewall rules target this tag — not the VM name.

---

### 3.2 — Describe a VM (get IP, status, disk info)

```bash
gcloud compute instances describe $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE
```

**Get just the external IP:**
```bash
gcloud compute instances describe $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)"
```

**Expected output:**
```
34.72.45.100
```

**Get status only:**
```bash
gcloud compute instances describe $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --format="value(status)"
```
```
RUNNING
```

---

### 3.3 — Stop a VM

```bash
gcloud compute instances stop $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE
```

**Verify:**
```bash
gcloud compute instances describe $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --format="value(status)"
```
```
TERMINATED
```

> 💡 `TERMINATED` means stopped (not deleted). GCP uses this term — it's confusing but normal.

---

### 3.4 — Start a VM

```bash
gcloud compute instances start $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE
```

**Verify:**
```bash
gcloud compute instances describe $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --format="value(status)"
```
```
RUNNING
```

---

### 3.5 — Add Labels to a VM

Labels are key-value pairs for cost tracking and filtering (like AWS resource tags).

```bash
gcloud compute instances add-labels $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --labels=env=prod,team=backend,app=api
```

**Verify — list labels:**
```bash
gcloud compute instances describe $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --format="value(labels)"
```
```
{'app': 'api', 'env': 'prod', 'team': 'backend'}
```

**Filter instances by label:**
```bash
gcloud compute instances list \
  --project=$PROJECT_ID \
  --filter="labels.env=prod"
```

---

### 3.6 — Add Metadata to a VM

Metadata is key-value config readable from inside the VM at `http://metadata.google.internal/`.

```bash
gcloud compute instances add-metadata $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --metadata=app-version=1.4.2,config-bucket=web-prod-configs
```

**Verify:**
```bash
gcloud compute instances describe $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --format="value(metadata.items)"
```

**Read metadata from inside VM:**
```bash
# Run this inside the VM (after SSH in)
curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/app-version" \
  -H "Metadata-Flavor: Google"
```
```
1.4.2
```

---

### 3.7 — Change Machine Type (Resize VM)

VM must be stopped first.

```bash
# Stop
gcloud compute instances stop $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE

# Change machine type
gcloud compute instances set-machine-type $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --machine-type=e2-medium

# Start again
gcloud compute instances start $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE
```

**Verify:**
```bash
gcloud compute instances describe $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --format="value(machineType)"
```
```
zones/us-central1-a/machineTypes/e2-medium
```

---

### 3.8 — Delete a VM & Clean Up Resources (Free Up Space)

To tear down the VM and remove associated disks and networks to reclaim all disk space on your local machine / environment:

#### Step 1: Delete the Instance
```bash
gcloud compute instances delete $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --quiet
```

**Verify instance is deleted:**
```bash
gcloud compute instances list --project=$PROJECT_ID
```
```
Listed 0 items.
```

#### Step 2: Delete Persistent Disk (Reclaim Storage)
If the disk was created separately or retained:
```bash
gcloud compute disks delete boot-disk-1 \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --quiet
```

**Verify disk is deleted:**
```bash
gcloud compute disks list --project=$PROJECT_ID
```
```
Listed 0 items.
```

#### Step 3: Delete Subnet and VPC Network
```bash
# Delete the subnet first
gcloud compute networks subnets delete default \
  --project=$PROJECT_ID \
  --region=$REGION \
  --quiet

# Delete the network
gcloud compute networks delete default \
  --project=$PROJECT_ID \
  --quiet
```

#### Step 4: Reset Local Floci Storage (To Zero Out Local Disk State)
If you want to clear all emulator state files and reset local docker storage:
```bash
# In Git Bash or WSL:
curl.exe -X POST http://localhost:4588/_floci-gcp/state/reset

# OR remove the local data directory when emulator is down:
# rm -rf ./data
```

---

## 4. Startup Scripts — Configuration as Code

Startup scripts run as `root` at **first boot** (and every boot if you configure it). Used to install software, configure the VM, pull secrets, etc.

> ⚠️ **Windows / Git Bash Note:** Passing multiline strings (`'#!/bin/bash\n...'`) directly in Git Bash can trigger:  
> `'C:\Users\...\Google\Cloud' is not recognized as an internal or external command`  
> because of spaces in the `Cloud SDK` path. To avoid this, either use a single-line command or use `--metadata-from-file` (recommended).

---

### 4.1 — Add Startup Script to Existing VM (Recommended & Fastest)

You can attach a startup script directly to your already running `$VM_NAME`:

```bash
# 1. Create the script file locally
cat << 'EOF' > startup.sh
#!/bin/bash
apt-get update -y
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx
echo "api-server ready" > /var/www/html/index.html
EOF

# 2. Attach it to your VM
gcloud compute instances add-metadata $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --metadata-from-file=startup-script=startup.sh
```

**Verify metadata was attached:**
```bash
gcloud compute instances describe $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --format="value(metadata.items)"
```

---

### 4.2 — Launch a New VM with Startup Script

When launching a brand new VM with a startup script:

```bash
# 1. Create a dedicated boot disk first
gcloud compute disks create boot-disk-nginx \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --size=10GB

# 2. Launch instance with the startup script file attached
gcloud compute instances create nginx-vm \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --machine-type=$MACHINE_TYPE \
  --disk=name=boot-disk-nginx,boot=yes \
  --tags=$TAG \
  --network=default \
  --subnet=default \
  --metadata-from-file=startup-script=startup.sh
```

**Verify new instance is running:**
```bash
gcloud compute instances list --project=$PROJECT_ID
```
```
NAME        ZONE           MACHINE_TYPE  PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP  STATUS
api-server  us-central1-a  e2-micro                   10.128.0.2   203.0.113.1  RUNNING
nginx-vm    us-central1-a  e2-micro                   10.128.0.3   203.0.113.2  RUNNING
```

---

### 4.3 — Check Startup Script Logs

On real GCP instances, check serial port boot logs:
```bash
gcloud compute instances get-serial-port-output $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE | tail -30
```

Inside the VM (via SSH):
```bash
sudo journalctl -u google-startup-scripts.service
# OR
sudo cat /var/log/syslog | grep startup
```

---

### 4.4 — Re-triggering a Startup Script
Updating a startup script does **not** re-run it immediately. It runs on the next boot:

```bash
# Reset / restart the VM to run the updated script
gcloud compute instances reset $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE
```

---

## 5. Firewall Rules — Network Access Control

GCP firewall rules are **project-wide** (not per-VM). They target VMs via **network tags**.

### Firewall Rule Anatomy

```
gcloud compute firewall-rules create <RULE_NAME>
  --direction=INGRESS          # or EGRESS
  --priority=1000              # lower = higher priority (default: 1000)
  --network=default            # VPC network
  --action=ALLOW               # or DENY
  --rules=tcp:80               # protocol:port
  --target-tags=http-server    # apply to VMs with this tag
  --source-ranges=0.0.0.0/0   # who can connect (0.0.0.0/0 = anyone)
```

---

### 5.1 — List Existing Firewall Rules

```bash
gcloud compute firewall-rules list --project=$PROJECT_ID
```

**Expected output:**
```
NAME                 NETWORK  DIRECTION  PRIORITY  ALLOW       DENY
default-allow-ssh    default  INGRESS    65534     tcp:22
default-allow-http   default  INGRESS    1000      tcp:80
```

---

### 5.2 — Allow HTTP (port 80)

```bash
gcloud compute firewall-rules create allow-http \
  --project=$PROJECT_ID \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:80 \
  --target-tags=http-server \
  --source-ranges=0.0.0.0/0 \
  --description="Allow HTTP from anywhere"
```

**Verify:**
```bash
gcloud compute firewall-rules describe allow-http --project=$PROJECT_ID
```
```
allowed:
- IPProtocol: tcp
  ports: ['80']
direction: INGRESS
name: allow-http
targetTags: ['http-server']
```

---

### 5.3 — Allow HTTPS (port 443)

```bash
gcloud compute firewall-rules create allow-https \
  --project=$PROJECT_ID \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:443 \
  --target-tags=http-server \
  --source-ranges=0.0.0.0/0
```

**Verify:**
```bash
gcloud compute firewall-rules list \
  --project=$PROJECT_ID \
  --filter="name~allow-"
```

---

### 5.4 — Allow Custom Port (Node.js app on 3000)

```bash
gcloud compute firewall-rules create allow-node-api \
  --project=$PROJECT_ID \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:3000 \
  --target-tags=http-server \
  --source-ranges=0.0.0.0/0
```

**Verify:**
```bash
gcloud compute firewall-rules describe allow-node-api --project=$PROJECT_ID \
  --format="value(allowed)"
```
```
[{'IPProtocol': 'tcp', 'ports': ['3000']}]
```

---

### 5.5 — Restrict SSH to Your IP Only (Security Best Practice)

```bash
# Replace with your actual IP
MY_IP="203.0.113.42"

gcloud compute firewall-rules create allow-ssh-myip \
  --project=$PROJECT_ID \
  --direction=INGRESS \
  --priority=500 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:22 \
  --target-tags=http-server \
  --source-ranges="${MY_IP}/32"
```

> ⚠️ Priority `500` is **higher priority** than the default SSH rule (65534), so this more restrictive rule wins.

**Verify:**
```bash
gcloud compute firewall-rules describe allow-ssh-myip --project=$PROJECT_ID \
  --format="value(sourceRanges)"
```
```
['203.0.113.42/32']
```

---

### 5.6 — Update a Firewall Rule

```bash
gcloud compute firewall-rules update allow-node-api \
  --project=$PROJECT_ID \
  --source-ranges=10.0.0.0/8   # restrict to internal network only
```

**Verify:**
```bash
gcloud compute firewall-rules describe allow-node-api --project=$PROJECT_ID \
  --format="value(sourceRanges)"
```
```
['10.0.0.0/8']
```

---

### 5.7 — Delete a Firewall Rule

```bash
gcloud compute firewall-rules delete allow-node-api \
  --project=$PROJECT_ID \
  --quiet
```

**Verify:**
```bash
gcloud compute firewall-rules list \
  --project=$PROJECT_ID \
  --filter="name=allow-node-api"
```
```
Listed 0 items.
```

---

## 6. Custom Images — Standardized Base Images

**Why:** Build a VM once with all your software installed, snapshot it, and launch 100 identical VMs from that image. Faster boots, consistent environments.

### 6.1 — Stop the Source VM

A VM must be stopped before imaging its disk.

```bash
gcloud compute instances stop $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE
```

**Verify:**
```bash
gcloud compute instances describe $VM_NAME \
  --project=$PROJECT_ID --zone=$ZONE \
  --format="value(status)"
```
```
TERMINATED
```

---

### 6.2 — Create Image from Disk

```bash
gcloud compute images create api-server-image-v1 \
  --project=$PROJECT_ID \
  --source-disk=$VM_NAME \
  --source-disk-zone=$ZONE \
  --description="NGINX + Node.js base image for api-server fleet"
```

**Verify — list images:**
```bash
gcloud compute images list \
  --project=$PROJECT_ID \
  --no-standard-images
```

**Expected output:**
```
NAME                    PROJECT   FAMILY  STATUS
api-server-image-v1     web-prod          READY
```

---

### 6.3 — Launch a New VM from Custom Image

```bash
gcloud compute instances create api-server-v2 \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --machine-type=$MACHINE_TYPE \
  --image=api-server-image-v1 \
  --image-project=$PROJECT_ID \
  --tags=$TAG
```

**Verify:**
```bash
gcloud compute instances list --project=$PROJECT_ID
```
```
NAME            ZONE           MACHINE_TYPE  STATUS
api-server      us-central1-a  e2-micro      TERMINATED
api-server-v2   us-central1-a  e2-micro      RUNNING
```

---

### 6.4 — Add an Image to a Family

Image families let you always reference the "latest" image without hardcoding the name.

```bash
gcloud compute images create api-server-image-v2 \
  --project=$PROJECT_ID \
  --source-disk=$VM_NAME \
  --source-disk-zone=$ZONE \
  --family=api-server-base
```

**Use the family name instead of exact image:**
```bash
gcloud compute instances create api-server-new \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --machine-type=$MACHINE_TYPE \
  --image-family=api-server-base \    # always picks the latest in family
  --image-project=$PROJECT_ID \
  --tags=$TAG
```

---

### 6.5 — Delete an Image

```bash
gcloud compute images delete api-server-image-v1 \
  --project=$PROJECT_ID \
  --quiet
```

**Verify:**
```bash
gcloud compute images list \
  --project=$PROJECT_ID \
  --no-standard-images
```
```
NAME                   PROJECT   STATUS
api-server-image-v2    web-prod  READY
```

---

## 7. Instance Templates & Managed Instance Groups (MIGs)

This is how **auto-scaling production fleets** work in GCP.

```
Instance Template → MIG → N identical VMs (auto-scales)
```

### 7.1 — Create an Instance Template

```bash
gcloud compute instance-templates create api-server-template \
  --project=$PROJECT_ID \
  --machine-type=$MACHINE_TYPE \
  --image-family=$IMAGE_FAMILY \
  --image-project=$IMAGE_PROJECT \
  --tags=$TAG \
  --metadata=startup-script='#!/bin/bash
apt-get update -y && apt-get install -y nginx
systemctl start nginx'
```

**Verify:**
```bash
gcloud compute instance-templates list --project=$PROJECT_ID
```
```
NAME                  MACHINE_TYPE  PREEMPTIBLE
api-server-template   e2-micro
```

**Describe template:**
```bash
gcloud compute instance-templates describe api-server-template \
  --project=$PROJECT_ID
```

---

### 7.2 — Create a MIG from Template

```bash
gcloud compute instance-groups managed create api-server-mig \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --template=api-server-template \
  --size=2
```

**Verify — list MIGs:**
```bash
gcloud compute instance-groups managed list --project=$PROJECT_ID
```
```
NAME             LOCATION       SCOPE  BASE_INSTANCE_NAME  SIZE  TARGET_SIZE
api-server-mig   us-central1-a  zone   api-server-mig      2     2
```

**Verify — list VMs created by MIG:**
```bash
gcloud compute instances list \
  --project=$PROJECT_ID \
  --filter="name~api-server-mig"
```
```
NAME               ZONE           MACHINE_TYPE  STATUS
api-server-mig-abc us-central1-a  e2-micro      RUNNING
api-server-mig-xyz us-central1-a  e2-micro      RUNNING
```

---

### 7.3 — Scale MIG (Resize)

```bash
# Scale up to 4 instances
gcloud compute instance-groups managed resize api-server-mig \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --size=4
```

**Verify:**
```bash
gcloud compute instance-groups managed describe api-server-mig \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --format="value(targetSize)"
```
```
4
```

**Scale down to 1:**
```bash
gcloud compute instance-groups managed resize api-server-mig \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --size=1
```

---

### 7.4 — Set Autoscaling

```bash
gcloud compute instance-groups managed set-autoscaling api-server-mig \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --min-num-replicas=1 \
  --max-num-replicas=10 \
  --target-cpu-utilization=0.6 \
  --cool-down-period=90
```

> 💡 This means: keep at least 1 VM, scale up to 10 max, targeting 60% CPU. If CPU spikes, GCP adds VMs automatically.

**Verify:**
```bash
gcloud compute instance-groups managed describe api-server-mig \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --format="value(autoscaler)"
```

---

### 7.5 — Rolling Update (new template → MIG)

Create a new template with updated config (e.g., new image version):

```bash
gcloud compute instance-templates create api-server-template-v2 \
  --project=$PROJECT_ID \
  --machine-type=e2-small \
  --image-family=api-server-base \
  --image-project=$PROJECT_ID \
  --tags=$TAG
```

Apply rolling update to the MIG:

```bash
gcloud compute instance-groups managed rolling-action start-update api-server-mig \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --version=template=api-server-template-v2 \
  --max-surge=1 \
  --max-unavailable=0
```

> 💡 `--max-surge=1` = add 1 extra VM during update. `--max-unavailable=0` = never take a VM offline before the new one is ready. This is a **zero-downtime rolling deploy**.

**Verify update status:**
```bash
gcloud compute instance-groups managed describe api-server-mig \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --format="value(status.versionTarget.isReached)"
```
```
True   ← update complete
```

---

### 7.6 — Delete MIG and Template

```bash
# Delete the MIG first (this terminates all VMs inside it)
gcloud compute instance-groups managed delete api-server-mig \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --quiet

# Then delete the template
gcloud compute instance-templates delete api-server-template \
  --project=$PROJECT_ID \
  --quiet

gcloud compute instance-templates delete api-server-template-v2 \
  --project=$PROJECT_ID \
  --quiet
```

**Verify:**
```bash
gcloud compute instance-groups managed list --project=$PROJECT_ID
# Listed 0 items.

gcloud compute instance-templates list --project=$PROJECT_ID
# Listed 0 items.
```

---

## 8. SSH & Remote Access

### 8.1 — SSH into a VM

```bash
gcloud compute ssh $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE
```

> 💡 `gcloud compute ssh` auto-generates SSH key pairs and adds them to the VM's metadata on first use. No manual key setup needed.

### 8.2 — Run a Single Command Remotely

```bash
gcloud compute ssh $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --command="systemctl status nginx"
```

### 8.3 — Copy Files to/from VM

```bash
# Upload local file to VM
gcloud compute scp ./config.json $VM_NAME:~/config.json \
  --project=$PROJECT_ID \
  --zone=$ZONE

# Download file from VM
gcloud compute scp $VM_NAME:/var/log/app.log ./app.log \
  --project=$PROJECT_ID \
  --zone=$ZONE
```

### 8.4 — SSH via IAP (No Public IP Required)

If your VM has no external IP, use **Identity-Aware Proxy (IAP)** tunneling:

```bash
gcloud compute ssh $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --tunnel-through-iap
```

> 💡 This tunnels SSH through Google's infrastructure — the VM never needs a public IP. More secure for production.

---

## 9. Real-World DevOps Scenario

**Goal:** Deploy a scalable Node.js API fleet that auto-heals and can be updated with zero downtime.

### Step 1 — Write the startup script
```bash
cat > api-startup.sh << 'EOF'
#!/bin/bash
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Pull app code (from GCS bucket in real life)
mkdir -p /app
cat > /app/server.js << 'JS'
const http = require('http');
http.createServer((req, res) => {
  res.end(JSON.stringify({ status: 'ok', host: require('os').hostname() }));
}).listen(3000);
console.log('API running on :3000');
JS

# Run as a service
node /app/server.js &
EOF
```

### Step 2 — Create instance template
```bash
gcloud compute instance-templates create api-fleet-template \
  --project=$PROJECT_ID \
  --machine-type=e2-small \
  --image-family=ubuntu-2004-lts \
  --image-project=ubuntu-os-cloud \
  --tags=api-server \
  --metadata-from-file=startup-script=api-startup.sh
```

### Step 3 — Add firewall rule for the API port
```bash
gcloud compute firewall-rules create allow-api-3000 \
  --project=$PROJECT_ID \
  --direction=INGRESS \
  --rules=tcp:3000 \
  --target-tags=api-server \
  --source-ranges=0.0.0.0/0
```

### Step 4 — Create auto-scaling MIG
```bash
gcloud compute instance-groups managed create api-fleet \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --template=api-fleet-template \
  --size=2

gcloud compute instance-groups managed set-autoscaling api-fleet \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --min-num-replicas=2 \
  --max-num-replicas=20 \
  --target-cpu-utilization=0.7
```

### Step 5 — Verify fleet is up
```bash
gcloud compute instances list \
  --project=$PROJECT_ID \
  --filter="name~api-fleet"
```

### Step 6 — Deploy new version (zero-downtime)
```bash
# Update template → v2
gcloud compute instance-templates create api-fleet-template-v2 \
  --project=$PROJECT_ID \
  --machine-type=e2-small \
  --image-family=ubuntu-2004-lts \
  --image-project=ubuntu-os-cloud \
  --tags=api-server \
  --metadata-from-file=startup-script=api-startup-v2.sh

# Roll out update
gcloud compute instance-groups managed rolling-action start-update api-fleet \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --version=template=api-fleet-template-v2 \
  --max-surge=2 \
  --max-unavailable=0
```

---

## 10. Floci Emulation Notes

| Command | Floci Support | Notes |
|---|---|---|
| `instances list` | ✅ Works | Returns empty list (no real VMs) |
| `instances create` | ⚠️ Partial | Returns success, but no actual VM boots |
| `instances describe` | ⚠️ Partial | May return stub data or error |
| `instances stop/start` | ⚠️ Partial | State changes recorded but no real effect |
| `firewall-rules create/list` | ✅ Works | Full CRUD supported |
| `compute images list` | ✅ Works | Returns empty; custom image creation may work |
| `instance-templates create/list` | ⚠️ Partial | May work for CRUD; no actual VMs launched |
| `instance-groups managed` | ❌ Limited | MIG management unlikely to work |
| `compute ssh` | ❌ Not supported | No real VMs → no SSH |
| `get-serial-port-output` | ❌ Not supported | No real boot process |

### Practice Strategy with Floci
1. **Use Floci for:** syntax practice, `create`/`list`/`describe`/`delete` flows, firewall rules
2. **Use real GCP free tier for:** SSH, startup scripts, MIGs, actual networking
3. **Free tier VM:** `e2-micro` in `us-central1`, `us-east1`, or `us-west1` — always free (1 per account)

> ⚠️ **For Floci compute commands:** Add `--quiet` to avoid interactive prompts that can hang. The `gcloud compute instances create` command may succeed in Floci but won't create a real VM.

---

## 11. Cheatsheet & Key Rules

### Machine Type Quick Reference

| Type | vCPU | RAM | Use Case | Cost |
|---|---|---|---|---|
| `e2-micro` | 0.25 | 1 GB | Dev/test, free tier | ~Free |
| `e2-small` | 0.5 | 2 GB | Light apps, small APIs | ~$13/mo |
| `e2-medium` | 1 | 4 GB | Medium workloads | ~$27/mo |
| `e2-standard-4` | 4 | 16 GB | Production API servers | ~$110/mo |
| `n1-standard-8` | 8 | 30 GB | High-CPU production | ~$300/mo |
| `n2-standard-16` | 16 | 64 GB | Heavy compute | ~$600/mo |

### Zone Cheatsheet

| Zone | Region | Notes |
|---|---|---|
| `us-central1-a` | Iowa | Default zone, free tier eligible |
| `us-east1-b` | S. Carolina | Free tier eligible |
| `us-west1-a` | Oregon | Free tier eligible |
| `europe-west1-b` | Belgium | EU data residency |
| `asia-east1-a` | Taiwan | APAC |

### Common Gotchas

| Gotcha | Fix |
|---|---|
| `imageFamilyViews/` not found | In Floci, public image projects (`ubuntu-os-cloud`) don't exist. Create a local image first: `gcloud compute images create ubuntu-2004 --project=$PROJECT_ID` or attach a pre-created disk with `--disk=name=boot-disk-1,boot=yes`. |
| Missing subnetwork | In custom/new projects, create VPC and subnet first: `gcloud compute networks create default --subnet-mode=custom` and `gcloud compute networks subnets create default --region=$REGION --range=10.128.0.0/20`. |
| Deleting a VM also deletes its boot disk | Use `--keep-disks=boot` |
| `TERMINATED` = stopped, not deleted | Use `instances delete` to actually delete |
| Startup script doesn't re-run after update | Use `instances reset` to trigger a reboot |
| SSH fails — firewall rule missing | Add `allow tcp:22` rule with your tag |
| VM has no external IP | Use `--tunnel-through-iap` for SSH |
| Serial console shows startup script errors | Check `/var/log/syslog` or `journalctl -u google-startup-scripts` |
| MIG won't delete — autoscaler attached | Delete autoscaler first or use `--quiet` |

### Quick-Reference Commands

```bash
# List all VMs
gcloud compute instances list --project=$PROJECT_ID

# Get external IP
gcloud compute instances describe $VM_NAME --zone=$ZONE --format="value(networkInterfaces[0].accessConfigs[0].natIP)"

# Check VM status
gcloud compute instances describe $VM_NAME --zone=$ZONE --format="value(status)"

# List firewall rules
gcloud compute firewall-rules list --project=$PROJECT_ID

# List images (custom only)
gcloud compute images list --project=$PROJECT_ID --no-standard-images

# List instance templates
gcloud compute instance-templates list --project=$PROJECT_ID

# List MIGs
gcloud compute instance-groups managed list --project=$PROJECT_ID

# View startup script boot logs
gcloud compute instances get-serial-port-output $VM_NAME --zone=$ZONE | tail -40
```
