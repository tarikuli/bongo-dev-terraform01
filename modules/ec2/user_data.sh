#!/bin/bash
# "User data" is a script AWS runs once, automatically, the first time the
# instance boots (as root) — it's how we install/configure software without
# logging in by hand.
set -euxo pipefail
# -e: stop on first error   -u: error on unset variables
# -x: print each command as it runs (visible in the instance's boot log)
# -o pipefail: a pipeline fails if any command in it fails, not just the last

dnf update -y          # refresh package metadata and apply updates
dnf install -y nginx   # install the nginx web server (dnf is AL2023's package manager)
systemctl enable nginx # start nginx automatically on every future boot
systemctl start nginx  # start nginx right now
