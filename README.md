# bongo-dev-terraform01

A beginner-friendly Terraform project that provisions a small, self-contained
AWS environment: a VPC with a public and private subnet, an EC2 instance
running nginx in the public subnet, and the networking/security needed to
reach it over HTTP and SSH.

This README explains not just *how* to run it, but *what* each piece is,
so it doubles as a learning guide if you're new to Terraform or AWS
networking.

---

## 1. What gets created

```
                         Internet
                             │
                             │
                     ┌───────▼────────┐
                     │ Internet       │
                     │ Gateway (IGW)  │
                     └───────┬────────┘
                             │
   VPC  10.0.0.0/16          │
  ┌──────────────────────────┼───────────────────────────┐
  │                          │                            │
  │   ┌──────────────────────▼─────────────────────┐      │
  │   │  Public Route Table (0.0.0.0/0 → IGW)       │      │
  │   └──────────────────────┬─────────────────────┘      │
  │                          │                             │
  │   ┌──────────────────────▼─────────────────────┐       │
  │   │  Public Subnet   10.0.1.0/24                │       │
  │   │                                              │       │
  │   │   ┌────────────────────────────────────┐    │       │
  │   │   │  EC2 instance (t3.micro)            │    │       │
  │   │   │  Amazon Linux 2023 + nginx          │    │       │
  │   │   │  Security Group:                    │    │       │
  │   │   │    - allow TCP 22  from YOUR IP     │    │       │
  │   │   │    - allow TCP 80  from anywhere    │    │       │
  │   │   └────────────────────────────────────┘    │       │
  │   └──────────────────────────────────────────────┘      │
  │                                                          │
  │   ┌──────────────────────────────────────────────┐      │
  │   │  Private Subnet  10.0.2.0/24                  │      │
  │   │  (no route to the internet — empty for now,   │      │
  │   │   scaffolding for things like a database)     │      │
  │   └────────────────────────────────────────────────┘    │
  │                                                          │
  └──────────────────────────────────────────────────────────┘
```

In AWS terms, this project creates:

| Resource | Terraform type | Purpose |
|---|---|---|
| VPC | `aws_vpc` | An isolated network with its own private IP range |
| Internet Gateway | `aws_internet_gateway` | Connects the VPC to the public internet |
| Public subnet | `aws_subnet` | Where the EC2 instance lives; can reach/be reached from the internet |
| Private subnet | `aws_subnet` | Isolated subnet with no internet route (not used by anything yet) |
| Public route table | `aws_route_table` + `aws_route_table_association` | Sends the public subnet's outbound traffic to the Internet Gateway |
| Security group | `aws_security_group` | Firewall rules: SSH (22) from your IP only, HTTP (80) from anywhere |
| AMI lookup | `aws_ami` (data source) | Finds the latest Amazon Linux 2023 image automatically |
| EC2 instance | `aws_instance` | A `t3.micro` VM with an 8 GB gp3 root disk, running nginx |

---

## 2. Project structure

```
.
├── providers.tf        # Which cloud provider (AWS) and version to use
├── variables.tf         # All configurable inputs (region, CIDRs, your IP, etc.)
├── main.tf               # The actual resources: VPC, subnets, security group, EC2 instance
├── outputs.tf            # Values printed after apply (the instance's public IP)
├── user_data.sh          # Shell script that installs & starts nginx on first boot
├── .gitignore            # Files Terraform generates locally that shouldn't be committed
└── .terraform.lock.hcl   # Records exact provider versions used (should be committed)
```

Terraform doesn't care how you split files — it reads every `.tf` file in
the directory as one combined configuration. They're split by purpose here
purely for readability.

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
When it finishes, it prints the `instance_public_ip` output.

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

Once `terraform apply` finishes, copy the printed `instance_public_ip` and:

**Check nginx is running (in a browser or via curl):**
```bash
curl http://<instance_public_ip>
```
You should see the default nginx welcome page HTML.

**SSH into the instance** (only works if you set `key_name` to an existing
EC2 key pair — see section 7):
```bash
ssh -i /path/to/your-key.pem ec2-user@<instance_public_ip>
```

---

## 7. Configuration reference (`variables.tf`)

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region to deploy into |
| `availability_zone` | `us-east-1a` | AZ for both subnets and the instance |
| `vpc_cidr` | `10.0.0.0/16` | IP range for the whole VPC |
| `public_subnet_cidr` | `10.0.1.0/24` | IP range for the public subnet |
| `private_subnet_cidr` | `10.0.2.0/24` | IP range for the private subnet |
| `instance_type` | `t3.micro` | EC2 instance size |
| `root_volume_size` | `8` | Root disk size in GB |
| `my_ip_cidr` | *(required, no default)* | Your IP, e.g. `203.0.113.5/32` — allowed to SSH in |
| `key_name` | `null` | Name of an existing EC2 key pair, for SSH access. Leave unset to launch without one (you won't be able to SSH in, but HTTP still works) |

To use an existing key pair, pass it the same way as `my_ip_cidr`:
```bash
-var="key_name=my-existing-keypair"
```

---

## 8. Terraform concepts used in this project (glossary)

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

---

## 9. Cost warning

Everything here (`t3.micro`, an 8 GB gp3 volume, one VPC) fits within the
AWS Free Tier for a new account, but **outside the free tier, or after your
free tier expires, this will incur charges** for as long as it's running.
Run `terraform destroy` when you're done to avoid unexpected costs.

---

## 10. Troubleshooting

- **`terraform validate` fails** — usually a typo or missing required
  variable. Read the error message; it names the exact file and line.
- **`terraform apply` fails with a credentials error** — re-run
  `aws configure`, or check `aws sts get-caller-identity` works.
- **Can't reach the instance over HTTP** — wait 1–2 minutes after apply;
  `user_data.sh` needs a little time to run on first boot. Check the
  security group allows port 80 from your location.
- **Can't SSH in** — confirm you passed the correct `my_ip_cidr` (your IP
  may have changed since your last apply) and that you passed a valid
  `key_name` for a key pair you actually have the private key for.
