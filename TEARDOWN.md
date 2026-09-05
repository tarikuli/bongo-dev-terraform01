# Teardown

Every resource in this project costs something once it's outside the AWS
Free Tier (the ALB and RDS instance bill hourly regardless). Follow these
steps **in order** to remove everything and stop being billed. Don't skip
the ordering — destroying things out of order can leave you unable to
cleanly destroy what's left.

---

## Step 1 — Destroy the main project

From the repository root (not `bootstrap/`):

```bash
terraform destroy -var="my_ip_cidr=203.0.113.5/32" -var="alert_email=you@example.com"
```

Use the same `my_ip_cidr` and `alert_email` values you originally applied
with — Terraform needs them to evaluate the config, even though it's
tearing things down, not creating them. If you saved them in a
`terraform.tfvars` file, you can omit the flags entirely.

This removes, in dependency order (Terraform figures this out
automatically): the CloudWatch alarms and SNS topic, the RDS instance and
its Secrets Manager secret, the ALB and target group, the Auto Scaling
Group and launch template, both security groups, and finally the VPC and
all its subnets/route tables/Internet Gateway.

**This takes a while — expect 10–15 minutes**, mostly waiting on the RDS
instance to finish deleting. Let it run to completion. When it's done, you
should see:

```
Destroy complete! Resources: N destroyed.
```

If it fails partway through, re-run the same command — `terraform destroy`
is safe to re-run and will pick up wherever it left off.

---

## Step 2 — Spot-check that nothing's left (recommended)

Terraform's own state is the source of truth, but it's worth a quick
sanity check directly against AWS, in case something was created outside
Terraform or a destroy step silently failed:

```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=bongo-dev-web" --query "Reservations[].Instances[].State.Name"
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names bongo-dev-web-asg
aws elbv2 describe-load-balancers --names bongo-dev-web-alb
aws rds describe-db-instances --db-instance-identifier bongo-dev-mysql
aws cloudwatch describe-alarms --alarm-names bongo-dev-asg-cpu-high bongo-dev-alb-unhealthy-hosts
aws sns list-topics --query "Topics[?contains(TopicArn, 'bongo-dev-alerts')]"
```

Each of these should return empty or a "not found" error once Step 1 has
fully completed. If any still show something, don't proceed to Step 3
until you've resolved it (re-run `terraform destroy`, or delete the
leftover resource manually and investigate why Terraform didn't catch it).

---

## Step 3 — Did you ever set up remote state?

This project's `backend.tf.example` shows the remote-state setup, but it
only takes effect once you've copied it to `backend.tf` with real bucket
and table names (see the README's "Remote state" section).

- **If you never created `backend.tf`** — your state has been local the
  whole time. Skip to Step 5.
- **If `backend.tf` exists and points at a real S3 bucket/DynamoDB
  table** — continue to Step 4. Do this only *after* Step 1 has
  succeeded, since the root project's state (which Step 1 needs to know
  what to destroy) lives in that very bucket.

---

## Step 4 — Destroy the remote state backend (S3 + DynamoDB)

```bash
cd bootstrap
terraform destroy
```

The state bucket has `force_destroy = true` set specifically so this
works cleanly even though it's been holding your state file (and, since
versioning is enabled, every previous version of it) — without that
setting, this step would fail with `BucketNotEmpty`.

This removes the S3 bucket (and everything ever stored in it) and the
DynamoDB lock table. There is no remote state left after this — if you
`terraform init` the root project again, it starts over with fresh local
state.

---

## Step 5 — Clean up local files (optional, no AWS cost)

These don't cost anything to leave around, but if you want a clean slate:

```bash
cd ..   # back to the repo root, if you're still in bootstrap/
rm -rf .terraform .terraform.lock.hcl* terraform.tfstate terraform.tfstate.backup
rm -rf bootstrap/.terraform bootstrap/terraform.tfstate bootstrap/terraform.tfstate.backup
```

(Don't delete `.terraform.lock.hcl` — the one *without* a wildcard — if
you intend to `terraform init` this project again later; it's meant to be
committed. The command above only removes the generated `.terraform/`
cache directories and local state files.)

---

## Step 6 — Optional: non-AWS-billing cleanup

Nothing here costs money, but if you're fully done with this project:

- **Rotate or delete the IAM access key** you put in the
  `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` GitHub secrets, if you
  created it solely for this project's CI workflow. Terraform never
  created this key, so destroying the project doesn't remove it.
- **Remove the GitHub Actions secrets** (`AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY`, `MY_IP_CIDR`) from the repo, or delete the
  repository itself, if you don't plan to revisit this project.

---

## Full checklist

After Steps 1 and (if applicable) 4, none of the following should exist
in your AWS account:

- [ ] EC2 instance(s) tagged `bongo-dev-web`
- [ ] Auto Scaling Group `bongo-dev-web-asg` and launch template `bongo-dev-web-*`
- [ ] Application Load Balancer `bongo-dev-web-alb` and target group `bongo-dev-web-tg`
- [ ] RDS instance `bongo-dev-mysql`
- [ ] Secrets Manager secret `bongo-dev-rds-master-credentials`
- [ ] CloudWatch alarms `bongo-dev-asg-cpu-high`, `bongo-dev-alb-unhealthy-hosts`
- [ ] SNS topic `bongo-dev-alerts`
- [ ] Security groups `bongo-dev-web-sg`, `bongo-dev-alb-sg`, `bongo-dev-rds-sg`
- [ ] VPC `bongo-dev-vpc` and its subnets/route tables/Internet Gateway
- [ ] (if you set up remote state) S3 bucket `bongo-dev-tfstate-<account-id>` and DynamoDB table `bongo-dev-terraform-locks`

As a final check, look at **AWS Cost Explorer** a day or two after
teardown to confirm charges have actually stopped — billing data lags by
several hours, so an immediate $0 isn't proof, but a persistent charge a
day later is a sign something above was missed.
