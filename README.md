# DevOps Learning Journey

My hands-on DevOps learning path — building real infrastructure on AWS with Terraform.

## Labs Completed

### Lab 1 — AWS Fundamentals
- Linux foundation
- EC2, EBS, IAM (deep dives)
- VPC exploration (default VPC, subnets, IGW, route tables, security groups)

### Lab 2 — Amazon S3 Deep Dive
- Versioning + DeleteMarker recovery
- Public Access Block (4 flags)
- Bucket policies (deny non-TLS)
- Lifecycle rules (transitions + expiration)
- Encryption (SSE-S3, SSE-KMS)
- Pre-signed URLs
- Cross-region replication concepts

### Lab 3 — 3-Tier VPC with Terraform
- Custom VPC (10.0.0.0/16)
- 3 subnets: public, app (private), data (private)
- Internet Gateway + route tables
- 3 chained Security Groups (ALB → App → DB)

## Stack
- **Cloud:** AWS (ap-south-1)
- **IaC:** Terraform v1.16.4
- **CLI:** AWS CLI v2
- **Environment:** WSL2 Ubuntu 24.04

### Lab 4 — EC2 Web Server in VPC
- Deployed t3.micro Ubuntu 22.04 EC2 in public subnet
- SSH key pair via `aws_key_pair`
- Security group `hca-web-sg` — ports 22 (SSH) + 80 (HTTP)
- `user_data` bootstrap: installs nginx, creates landing page
- Elastic IP `hca-web-eip` for stable public addressing
- Verified: `curl http://<eip>` returns nginx page
- Tested SSH login + browser access
- Full lifecycle: init → validate → plan → apply → verify → destroy

## Author
Mahanthesha | Cloud Infra Engineer (in transition)
