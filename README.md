# bongo-dev-terraform01

A beginner-friendly Terraform project that provisions a small, self-contained
AWS environment: a VPC with two public and two private subnets (across two
AZs), an Application Load Balancer, an Auto Scaling Group of EC2 instances
running nginx behind it, and a private MySQL RDS database the instances can
reach but the internet can't.

This README explains not just *how* to run it, but *what* each piece is,
so it doubles as a learning guide if you're new to Terraform or AWS
networking.

---

## 1. What gets created

```
                                Internet
                                    │
                        ┌───────────┴───────────┐
                        │                        │
                ┌───────▼────────┐               │
                │ Internet       │               │
                │ Gateway (IGW)  │               │
                └───────┬────────┘               │
                        │                         │
   VPC  10.0.0.0/16     │                         │  HTTP :80
  ┌─────────────────────┼─────────────────────────┼────────────┐
  │                      │                         │            │
  │   ┌──────────────────▼─────────────────┐   ┌───▼─────────┐  │
  │   │  Public Route Table (0.0.0.0/0→IGW) │   │ ALB SG:     │  │
  │   └──────────────────┬──────────────────┘   │ 80 from any │  │
  │                       │                      └─────┬───────┘  │
  │        ┌──────────────┴──────────────┐              │          │
  │        │                              │      ┌───────▼───────┐  │
  │  ┌─────▼──────────┐          ┌────────▼────┐ │  Application   │  │
  │  │ Public Subnet 1│          │Public Subnet2│ │  Load Balancer │  │
  │  │ 10.0.1.0/24     │          │10.0.3.0/24  │ │  (2 AZs)       │  │
  │  │ AZ a            │          │AZ b         │ └───────┬───────┘  │
  │  └────────┬────────┘          └──────┬──────┘         │          │
  │           │                          │          Target Group     │
  │           │                          │        (health check "/") │
  │           └────────────┬─────────────┘                │          │
  │                        │                               │          │
  │              ┌─────────▼─────────────────────────────▼─┐        │
  │              │  Auto Scaling Group (min 1 / max 2)      │        │
  │              │  EC2 instances (t3.micro, AL2023 + nginx)│        │
  │              │  Instance SG:                            │        │
  │              │    - 22  from YOUR IP                    │        │
  │              │    - 80  from the ALB's security group   │        │
  │              └───────────────────────────────────────────┘        │
  │                        │                                          │
  │           ┌────────────┴─────────────┐                            │
  │           │ MySQL :3306, from the    │                            │
  │           │ instance SG only         │                            │
  │  ┌────────▼────────┐      ┌──────────▼───────┐                    │
  │  │Private Subnet 1  │      │Private Subnet 2  │                   │
  │  │10.0.2.0/24  AZ a │      │10.0.4.0/24  AZ b │                   │
  │  │                  │      │                  │                   │
  │  │   ┌──────────────▼──────────────┐          │                   │
  │  │   │  RDS MySQL (db.t4g.micro)   │          │                   │
  │  │   │  20GB gp3, single-AZ         │          │                   │
  │  │   │  password → Secrets Manager  │          │                   │
  │  │   └──────────────────────────────┘          │                   │
  │  └──────────────────┘      └──────────────────┘                   │
  │                                                                    │
  └────────────────────────────────────────────────────────────────────┘
```

In AWS terms, this project creates:

| Resource | Terraform type | Purpose |
|---|---|---|
| VPC | `aws_vpc` | An isolated network with its own private IP range |
| Internet Gateway | `aws_internet_gateway` | Connects the VPC to the public internet |
| Public subnets (×2) | `aws_subnet` | One per AZ; host the ALB and the ASG's instances |
| Private subnets (×2) | `aws_subnet` | One per AZ; host the RDS database, unreachable from the internet |
| Public route table | `aws_route_table` + `aws_route_table_association` | Sends both public subnets' outbound traffic to the Internet Gateway |
| ALB security group | `aws_security_group` | Allows HTTP (80) from anywhere |
| Instance security group | `aws_security_group` | Allows SSH (22) from your IP only, HTTP (80) only from the ALB's security group |
| AMI lookup | `aws_ami` (data source) | Finds the latest Amazon Linux 2023 image automatically |
| Launch template | `aws_launch_template` | Blueprint the ASG uses to launch each instance: `t3.micro`, 8 GB gp3 root disk, nginx user data |
| Auto Scaling Group | `aws_autoscaling_group` | Keeps 1–2 instances running across both public subnets, registered with the target group |
| Application Load Balancer | `aws_lb` | Public entry point, spread across both public subnets |
| Target group | `aws_lb_target_group` | Tracks which instances are healthy via HTTP health checks on `/` |
| Listener | `aws_lb_listener` | Forwards port 80 on the ALB to the target group |
| DB subnet group | `aws_db_subnet_group` | Tells RDS which (private) subnets it may use |
| RDS security group | `aws_security_group` | Allows MySQL (3306) only from the instance security group |
| Random password | `random_password` | Generates the RDS master password — never a plaintext variable |
| Secrets Manager secret | `aws_secretsmanager_secret` + `..._secret_version` | Stores the generated username/password |
| RDS instance | `aws_db_instance` | MySQL 8.0, `db.t4g.micro`, 20 GB gp3, single-AZ, in the private subnets |

---

## 2. Project structure

```
.
├── providers.tf              # Which cloud provider (AWS) and version to use
├── variables.tf               # All configurable inputs (region, CIDRs, your IP, etc.)
├── main.tf                     # Calls the vpc and ec2 modules and wires them together
├── outputs.tf                  # Values printed after apply (the instance's public IP)
├── modules/
│   ├── vpc/                    # Reusable module: VPC, 2 public + 2 private subnets, IGW, route tables
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── alb/                    # Reusable module: ALB, target group, listener, ALB security group
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── ec2/                    # Reusable module: launch template, Auto Scaling Group, instance security group
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── user_data.sh        # Installs & starts nginx on first boot
│   └── rds/                    # Reusable module: RDS MySQL, DB subnet group, RDS security group, Secrets Manager
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
├── .gitignore                  # Files Terraform generates locally that shouldn't be committed
└── .terraform.lock.hcl         # Records exact provider versions used (should be committed)
```

The root project doesn't create any AWS resources directly — `main.tf` just
calls the four modules under `modules/` and passes values between them
(e.g. the VPC's subnet IDs into the ALB/EC2/RDS modules, the ALB's security
group/target group into the EC2 module, and the EC2 module's security
group into the RDS module). Terraform reads every `.tf` file within a
single directory as one combined configuration, but a `module` block is a
deliberate boundary: each module in `modules/` is a self-contained,
reusable unit with its own inputs (`variables.tf`) and outputs
(`outputs.tf`), so any of them could be dropped into another project
as-is.

---

## 3. Prerequisites

Before you start, you need:

1. **An AWS account** with permission to create VPCs, EC2 instances, and
   security groups.
2. **AWS credentials configured locally.** The easiest way:
   ```bash
   aws configure
   ```
   This asks for your Access Key ID, Secret Access Key, and default region.
   Terraform's AWS provider automatically picks these up — you never put
   credentials inside `.tf` files.
3. **Terraform installed** (this project was built and tested with
   Terraform 1.16). Check your version:
   ```bash
   terraform -version
   ```
   If you don't have it, on macOS:
   ```bash
   brew tap hashicorp/tap
   brew install hashicorp/tap/terraform
   ```
4. **Your public IP address**, so SSH can be restricted to just you (see
   step 4 below).

---

## 4. Required input: `my_ip_cidr`

For security, SSH (port 22) is **not** open to the whole internet — you must
explicitly tell Terraform your own IP address. This is intentional: there's
no default value, so you can't accidentally deploy with SSH open to
`0.0.0.0/0`.

Find your public IP:
```bash
curl -s ifconfig.me
```

Then pass it as a `/32` CIDR (meaning "exactly this one address") when you
run any Terraform command that touches infrastructure, e.g.:
```bash
-var="my_ip_cidr=203.0.113.5/32"
```

If your home/office IP changes (common with most home internet), you'll
need to re-run `terraform apply` with the new value to keep SSH access
working.

---

## 5. The Terraform workflow

Terraform has a standard command lifecycle. Run these **in order**, from
inside this directory.

### 5.1 `terraform init`
Downloads the AWS provider plugin and sets up the local working directory.
Run this once, and again any time you change `providers.tf`.
```bash
terraform init
```

### 5.2 `terraform fmt`
Auto-formats all `.tf` files to the standard style (consistent spacing,
alignment). Safe to run anytime.
```bash
terraform fmt -recursive
```

### 5.3 `terraform validate`
Checks the configuration for syntax errors and internal consistency
(e.g. referencing a variable that doesn't exist). It does **not** check
against real AWS state — it can't tell you if your AWS credentials are
wrong, for example.
```bash
terraform validate
```

### 5.4 `terraform plan`
Shows you **exactly what Terraform intends to create, change, or destroy**,
without actually doing it. Always read the plan before applying — this is
your safety check.
```bash
terraform plan -var="my_ip_cidr=203.0.113.5/32"
```

### 5.5 `terraform apply`
Actually creates the resources in AWS. It shows the same plan as above and
asks you to type `yes` to confirm.
```bash
terraform apply -var="my_ip_cidr=203.0.113.5/32"
```
When it finishes, it prints the `alb_dns_name` output. Give the ASG a
minute or two afterward to finish booting its first instance and pass the
ALB's health check before traffic actually succeeds.

### 5.6 `terraform destroy`
Tears down **everything** this project created. Use this when you're done
experimenting, to avoid ongoing AWS charges.
```bash
terraform destroy -var="my_ip_cidr=203.0.113.5/32"
```

> **Tip for repeated commands:** instead of typing `-var=...` every time,
> create a file named `terraform.tfvars` (already excluded from git by
> `.gitignore`, since it can contain sensitive values):
> ```hcl
> my_ip_cidr = "203.0.113.5/32"
> ```
> Terraform loads `terraform.tfvars` automatically, so you can just run
> `terraform plan` / `terraform apply` / `terraform destroy` with no flags.

---

## 6. Verifying it worked

Once `terraform apply` finishes, copy the printed `alb_dns_name` and:

**Check nginx is reachable through the ALB (in a browser or via curl):**
```bash
curl http://<alb_dns_name>
```
You should see the default nginx welcome page HTML. If you get a "503
Service Temporarily Unavailable" from the ALB, the instance likely hasn't
passed its first health check yet — wait a minute and retry.

**Check the ASG and target health** (requires the AWS CLI):
```bash
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names bongo-dev-web-asg
aws elbv2 describe-target-health --target-group-arn <arn from `terraform output` or the AWS console>
```

**SSH into an instance** (only works if you set `key_name` to an existing
EC2 key pair — see section 7). Since instances are managed by the ASG and
no longer have a single fixed IP, look up a current instance's public IP
in the EC2 console (or via the AWS CLI) first:
```bash
ssh -i /path/to/your-key.pem ec2-user@<instance_public_ip>
```

---

## 7. Configuration reference (`variables.tf`)

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region to deploy into |
| `availability_zones` | `["us-east-1a", "us-east-1b"]` | Two AZs the public subnets, ALB, and ASG span |
| `vpc_cidr` | `10.0.0.0/16` | IP range for the whole VPC |
| `public_subnet_cidrs` | `["10.0.1.0/24", "10.0.3.0/24"]` | IP ranges for the two public subnets, one per AZ |
| `private_subnet_cidrs` | `["10.0.2.0/24", "10.0.4.0/24"]` | IP ranges for the two private subnets, one per AZ |
| `instance_type` | `t3.micro` | EC2 instance size used by the launch template |
| `root_volume_size` | `8` | Root disk size in GB |
| `asg_min_size` | `1` | Minimum instances in the Auto Scaling Group |
| `asg_max_size` | `2` | Maximum instances in the Auto Scaling Group |
| `asg_desired_capacity` | `1` | Instances the ASG tries to keep running |
| `health_check_path` | `/` | Path the ALB target group checks for instance health |
| `my_ip_cidr` | *(required, no default)* | Your IP, e.g. `203.0.113.5/32` — allowed to SSH into instances |
| `key_name` | `null` | Name of an existing EC2 key pair, for SSH access. Leave unset to launch without one (you won't be able to SSH in, but HTTP still works) |
| `db_instance_class` | `db.t4g.micro` | RDS instance class |
| `db_allocated_storage` | `20` | RDS storage size in GB (gp3) |
| `db_engine_version` | `8.0` | MySQL engine version |
| `db_name` | `appdb` | Initial database created on the RDS instance |
| `db_username` | `dbadmin` | RDS master username (the password is generated randomly — see § 8) |
| `db_backup_retention_days` | `0` | Days of automated RDS backups to keep; `0` disables them |

To use an existing key pair, pass it the same way as `my_ip_cidr`:
```bash
-var="key_name=my-existing-keypair"
```

---

## 8. Accessing the database

There's no `db_password` variable anywhere in this project — on purpose.
`modules/rds` generates the master password randomly with a
`random_password` resource and stores it in AWS Secrets Manager, alongside
the username, as a JSON secret. The only thing about the database this
project ever prints is its non-secret connection endpoint
(`rds_endpoint`).

**To retrieve the password** (requires the AWS CLI and `jq`):
```bash
SECRET_ARN=$(terraform output -raw rds_secret_arn)
aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text | jq .
```
This prints `{"username": "...", "password": "..."}`.

**To connect with the MySQL client**, from something that's actually
inside the VPC and covered by the instance security group — e.g. SSH into
an EC2 instance first, since the RDS security group rejects connections
from anywhere else, including your own machine:
```bash
mysql -h <rds_endpoint host, no port> -u <username> -p
```

A couple of things worth understanding about how this is wired:
- **Why generate the password instead of asking for it in a variable?** A
  variable's value is easy to leak by accident — committed in a
  `terraform.tfvars` file, left in shell history, printed in a CI log.
  Generating it and only ever handling it as a Terraform-managed secret
  avoids all of that.
- **The password still ends up in `terraform.tfstate`, in plaintext.**
  This is unavoidable — Terraform has to know the value to set it on the
  RDS instance and write it to Secrets Manager. It's exactly why state
  should live in an encrypted backend rather than as a local file — see
  the remote state section below.
- **Why not read the password back out of Secrets Manager into
  `aws_db_instance`?** That would create a circular dependency: the secret
  can't contain the RDS endpoint until the instance exists, but the
  instance needs a password before it can be created. Generating the
  password once and feeding it to both the RDS instance and the secret
  avoids the cycle.

---

## 9. Terraform concepts used in this project (glossary)

If you're new to Terraform, here's what each building block means:

- **Provider** — a plugin that lets Terraform talk to a specific API (here,
  AWS). Declared in `providers.tf`.
- **Resource** — something Terraform creates and manages, e.g.
  `resource "aws_vpc" "main" { ... }`. The type is `aws_vpc`; `main` is a
  local name you choose to refer to it elsewhere in the code (like
  `aws_vpc.main.id`).
- **Data source** — a read-only lookup of something that already exists,
  e.g. `data "aws_ami" "amazon_linux_2023" { ... }` looks up an AMI ID
  instead of creating one.
- **Variable** — a named input, declared in `variables.tf` and referenced
  as `var.<name>`. Lets you reuse the same code with different values.
- **Output** — a named value Terraform prints after `apply`, declared in
  `outputs.tf` and referenced as `output.<name>` from other configurations.
- **State** — Terraform keeps track of what it created in a file called
  `terraform.tfstate` (created automatically, and excluded from git by
  `.gitignore` since it can contain sensitive data and shouldn't be shared
  via version control without a proper remote backend).
- **Plan / Apply** — Terraform's two-step safety model: `plan` shows you
  the changes *before* anything happens, `apply` executes them.
- **Module** — a self-contained, reusable group of resources with its own
  inputs and outputs, called from elsewhere with a `module` block, e.g.
  `module "vpc" { source = "./modules/vpc" vpc_cidr = var.vpc_cidr }`. The
  calling code (the root project, in this case) is itself sometimes called
  the "root module." Referencing a value a module produced looks like
  `module.vpc.vpc_id`, the same pattern as `var.` or `aws_vpc.main.id`.
- **Launch template** — a saved "recipe" (AMI, instance type, security
  groups, user data, etc.) an Auto Scaling Group uses every time it needs
  to launch a new instance. It replaces hand-launching a single
  `aws_instance`.
- **Auto Scaling Group (ASG)** — keeps a target number of instances
  running, launching replacements from the launch template if one is
  terminated or fails a health check, spread across the subnets you give it.
- **Load balancer / target group / listener** — a Load Balancer (`aws_lb`)
  is the public entry point; a **listener** tells it what to do with
  incoming connections on a port; a **target group** is the list of
  backend instances it forwards them to, tracked via health checks.
- **`random_password` / Secrets Manager** — `random_password` is a
  Terraform-only resource (no AWS API call) that generates a random value
  entirely within Terraform, used here so the RDS master password is never
  typed into a variable. Secrets Manager is a separate AWS service for
  actually *storing* secrets like that password, so applications (or you)
  can look them up by name/ARN instead of it living in a config file.

---

## 10. Cost warning

A `t3.micro` instance, an 8 GB gp3 volume, and a `db.t4g.micro` RDS
instance all fit within the AWS Free Tier for a new account (RDS's free
tier covers 750 hours/month of a `db.t2/t3/t4g.micro` instance), and the
Application Load Balancer has its own separate (smaller) free-tier
allowance for the first 12 months. **Outside the free tier, or after it
expires, the ALB, RDS instance, and any running EC2 instances all incur
charges for as long as they exist** — the ALB and RDS both bill hourly even
if the ASG has scaled down to a single small instance. Run
`terraform destroy` when you're done to avoid unexpected costs.

---

## 11. Remote state (`bootstrap/`)

By default, Terraform stores its state (`terraform.tfstate`) as a local
file. That's fine solo, but breaks down the moment more than one person or
machine runs `apply` — there's no locking and nothing shared. The
`bootstrap/` folder sets up **remote state**: an S3 bucket to hold the
state file, and a DynamoDB table Terraform uses to lock it during
`plan`/`apply` so two runs can't collide.

### Why a separate folder?

A backend config tells Terraform *where* to store its state — but Terraform
has to know that before it can do anything else. A config can't create the
S3 bucket and DynamoDB table it also uses as its own backend (that's a
chicken-and-egg problem). So `bootstrap/` is a small, independent Terraform
project with its own local state, whose only job is to create those two
resources once.

### What's in `bootstrap/`

| File | Purpose |
|---|---|
| `bootstrap/providers.tf` | Same AWS provider setup as the root project |
| `bootstrap/variables.tf` | `aws_region`, `project_name` (used to name the bucket/table) |
| `bootstrap/main.tf` | The S3 bucket (versioned + encrypted + public access blocked) and the DynamoDB lock table |
| `bootstrap/outputs.tf` | Prints the bucket name and table name you'll need next |

### Step-by-step: setting up remote state

**Step 1 — apply the bootstrap config** (creates the bucket and table; its
own state stays local, inside `bootstrap/`):
```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

**Step 2 — copy the output values:**
```bash
terraform output state_bucket_name
terraform output dynamodb_table_name
```

**Step 3 — add `backend.tf` to the root project.** A template is provided
at `backend.tf.example` — copy it and fill in the real values:
```bash
cd ..
cp backend.tf.example backend.tf
```
Then edit `backend.tf` and replace the bucket/table placeholders with the
values from Step 2. Backend blocks **cannot** use variables or outputs —
every value must be a literal string, because Terraform needs to know
where the state lives before it can evaluate anything else in the config.

**Step 4 — re-initialize the root project.** Terraform detects that a
backend was just added and offers to migrate your existing local state
into it:
```bash
terraform init
```
You'll see a prompt like:
```
Initializing the backend...
Do you want to copy existing state to the new backend?
  Enter "yes" to copy...
```
Type `yes`. From this point on, `terraform plan`/`apply`/`destroy` in the
root project read and write state in S3, locked via DynamoDB, instead of
the local `terraform.tfstate` file.

### Order of operations, summarized

1. `bootstrap/` — `init` → `plan` → `apply` (creates the bucket + table)
2. Root project — add `backend.tf` using the bootstrap outputs
3. Root project — `terraform init` (migrates local state into S3)
4. Root project — continue using `plan`/`apply`/`destroy` as normal

### Tearing down (reverse order matters)

If you ever want to remove everything, destroy in the **opposite** order:
first `terraform destroy` in the root project (while it can still reach its
state in S3), *then* `terraform destroy` in `bootstrap/`. If you destroy
the S3 bucket/DynamoDB table first, the root project loses access to its
own state and can no longer cleanly plan or destroy its resources.

---

## 12. Troubleshooting

- **`terraform validate` fails** — usually a typo or missing required
  variable. Read the error message; it names the exact file and line.
- **`terraform apply` fails with a credentials error** — re-run
  `aws configure`, or check `aws sts get-caller-identity` works.
- **ALB returns 503 Service Temporarily Unavailable** — normal for the
  first minute or two after apply, while the ASG's instance boots and runs
  `user_data.sh`. Check target health with
  `aws elbv2 describe-target-health --target-group-arn <arn>`; if a target
  stays `unhealthy` past the `health_check_grace_period` (300s), SSH in and
  check `sudo systemctl status nginx` and `sudo cat /var/log/cloud-init-output.log`.
- **Can't SSH into an instance** — confirm you passed the correct
  `my_ip_cidr` (your IP may have changed since your last apply), that you
  passed a valid `key_name` for a key pair you actually have the private
  key for, and that you're using a *current* instance's public IP (the ASG
  can replace instances, so an old IP will no longer answer).
- **ASG shows 0 healthy instances but `desired_capacity` is 1** — give it
  a few minutes; a fresh instance needs to boot, run user data, and pass at
  least 2 consecutive health checks (roughly a minute apart) before the
  target group marks it healthy.
- **Can't connect to MySQL** — the RDS security group only allows port
  3306 from the EC2/ASG security group, so you can only connect from
  inside the VPC (e.g. after SSHing into an instance) — not from your own
  machine directly, even with the right password.
- **`terraform apply` (or `destroy` then `apply` again) fails on the
  Secrets Manager secret** ("already scheduled for deletion" or similar) —
  this shouldn't happen here since `recovery_window_in_days = 0` deletes
  the secret immediately on destroy, but if you changed that, AWS keeps a
  deleted secret's name reserved for up to 30 days by default.
