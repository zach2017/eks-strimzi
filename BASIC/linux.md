# Linux / Red Hat System Administration Cheat Sheet

Covers system status, disk & LVM resize, general tasks, logs, systemd, package management, AWS checks (EC2/ECS/EKS), and debugging Kafka & Apache NiFi.

> **Path note:** Many commands below use representative default paths (`/opt/kafka/bin/...`, `/opt/nifi/...`, `/tmp/kafka-logs/`). These vary by install method and are frequently relocated in production. Always confirm against `server.properties` / `nifi.properties` rather than assuming defaults.

---

## System Status & Information

- `uptime` — how long the system has been running and load averages
- `hostnamectl` — display/set hostname and OS info
- `uname -a` — kernel version and system architecture
- `top` — real-time process and resource monitor
- `htop` — interactive process viewer (install separately)
- `free -h` — memory and swap usage (human-readable)
- `vmstat` — virtual memory statistics
- `lscpu` — CPU architecture details
- `whoami` — current logged-in user
- `who` — list users currently logged in

---

## Disk & Drive Management

- `df -h` — disk space usage by filesystem (human-readable)
- `du -sh /path` — total size of a directory
- `lsblk` — list block devices and partitions
- `fdisk -l` — list all disk partitions
- `blkid` — block device UUIDs and filesystem types
- `pvs` / `vgs` / `lvs` — LVM physical volumes, volume groups, logical volumes

### Drive Resize (LVM)

- `pvresize /dev/sdX` — resize physical volume after the underlying disk grows
- `lvextend -L +10G /dev/vg/lv` — extend logical volume by 10 GB
- `lvextend -l +100%FREE /dev/vg/lv` — extend logical volume using all free space
- `xfs_growfs /mountpoint` — grow an XFS filesystem (RHEL default)
- `resize2fs /dev/vg/lv` — grow an ext4 filesystem
- `growpart /dev/sda 1` — extend a partition to fill available disk space

---

## General File & Task Commands

- `ls -lah` — list files with details, hidden files, human-readable sizes
- `find /path -name "file"` — search for files by name
- `grep "pattern" file` — search for text within files
- `tar -czvf archive.tar.gz /dir` — create a compressed archive
- `tar -xzvf archive.tar.gz` — extract a compressed archive
- `chmod 755 file` — change file permissions
- `chown user:group file` — change file ownership
- `ps aux` — list all running processes
- `kill -9 PID` — forcefully terminate a process

---

## Logs

- `journalctl` — view systemd journal logs
- `journalctl -u servicename` — logs for a specific service
- `journalctl -f` — follow logs in real time
- `journalctl --since "1 hour ago"` — logs within a time window
- `journalctl -p err` — filter logs by priority (errors)
- `tail -f /var/log/messages` — follow the main system log
- `dmesg` — view kernel ring buffer messages

---

## Service Management (systemctl)

- `systemctl status servicename` — check service status
- `systemctl start servicename` — start a service
- `systemctl stop servicename` — stop a service
- `systemctl restart servicename` — restart a service
- `systemctl reload servicename` — reload config without full restart
- `systemctl enable servicename` — enable service at boot
- `systemctl disable servicename` — disable service at boot
- `systemctl list-units --type=service` — list all active services
- `systemctl daemon-reload` — reload systemd manager configuration

---

## Package Management (DNF / YUM)

- `dnf install packagename` — install a package
- `dnf remove packagename` — remove a package
- `dnf update` — update all installed packages
- `dnf search keyword` — search for a package
- `dnf info packagename` — show package details
- `dnf list installed` — list all installed packages
- `dnf repolist` — list enabled repositories
- `dnf provides /path/to/file` — find which package provides a file
- `rpm -qa` — query all installed RPM packages
- `rpm -ivh package.rpm` — install a local RPM file

---

## AWS Checks (Linux / Containers)

### Instance Metadata (IMDS — run from inside an EC2 instance)

IMDSv2 is token-based and the default on newer instances; older token-less calls may be disabled.

- Fetch an IMDSv2 token first:
  `TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")`
- `curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/` — list metadata fields
- `curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id` — get instance ID
- `curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/` — attached IAM role name
- `ec2-metadata --all` — convenience wrapper (Amazon Linux only; not always installed)

### AWS CLI — Identity & General

- `aws sts get-caller-identity` — confirm which IAM identity/credentials are in use (first check for permission issues)
- `aws configure list` — show configured region, profile, and credential source
- `aws ec2 describe-instances --instance-ids i-xxxx` — instance details and state
- `aws ec2 describe-instance-status --instance-ids i-xxxx` — health/status checks
- `aws ecr get-login-password | docker login --username AWS --password-stdin <acct>.dkr.ecr.<region>.amazonaws.com` — authenticate Docker to ECR

### ECS (containers on ECS / Fargate)

- `curl ${ECS_CONTAINER_METADATA_URI_V4}/task` — task metadata from inside a container
- `curl ${ECS_CONTAINER_METADATA_URI_V4}/stats` — container resource stats
- `aws ecs list-tasks --cluster <name>` — list running tasks in a cluster
- `aws ecs describe-tasks --cluster <name> --tasks <task-id>` — inspect task state and stop reasons
- `aws ecs execute-command --cluster <name> --task <id> --container <name> --interactive --command "/bin/bash"` — shell into a running container (requires ECS Exec enabled)

### EKS (Kubernetes on AWS)

- `aws eks update-kubeconfig --name <cluster> --region <region>` — configure kubectl for the cluster
- `kubectl get nodes` — check node readiness
- `kubectl get pods -A` — list pods across all namespaces
- `kubectl describe pod <pod>` — inspect events, restarts, and scheduling failures
- `kubectl logs <pod> -c <container>` — view container logs
- `kubectl top pods` — pod CPU/memory usage (requires metrics-server)

### CloudWatch Logs

- `aws logs describe-log-groups` — list log groups
- `aws logs tail <log-group> --follow` — stream logs in real time

---

## Kafka Debugging

### Where the binaries live (varies by install)

- **Apache Kafka (binary tarball):** `/opt/kafka/bin/` — scripts end in `.sh` (e.g. `/opt/kafka/bin/kafka-topics.sh`)
- **Confluent Platform (tarball):** `/opt/confluentinc/bin/` or `<confluent-home>/bin/`
- **Confluent Platform (RPM/DEB packages):** `/usr/bin/` — scripts have **no** `.sh` extension (e.g. `/usr/bin/kafka-topics`)
- **Homebrew (macOS):** `/opt/homebrew/bin/` or `/usr/local/bin/`

Examples below use `/opt/kafka/bin/...sh` (Apache tarball). On Confluent packages, drop `/opt/kafka/bin/` and the `.sh`.

### Cluster & Broker Health

- `/opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092` — connectivity test; confirms brokers are reachable
- `/opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server localhost:9092 describe --status` — KRaft quorum status
- `/opt/kafka/bin/zookeeper-shell.sh localhost:2181 ls /brokers/ids` — list live broker IDs (ZooKeeper mode)

### Topics

- `/opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list` — list all topics
- `/opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic <name>` — partitions, replicas, leader assignment
- `/opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --under-replicated-partitions` — under-replicated partitions (key health red flag)
- `/opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --unavailable-partitions` — partitions with no leader

### Consumer Groups & Lag

- `/opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list` — list consumer groups
- `/opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group <name>` — per-partition lag, offsets, assigned consumers
- `/opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --all-groups` — lag across every group
- `/opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group <name> --reset-offsets --to-earliest --topic <name> --execute` — reset offsets (use `--dry-run` first)

### Inspecting Messages

- `/opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic <name> --from-beginning` — read messages from the start
- `/opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic <name> --partition 0 --offset 100 --max-messages 10` — read specific messages
- `/opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic <name>` — produce test messages
- `/opt/kafka/bin/kafka-get-offsets.sh --bootstrap-server localhost:9092 --topic <name>` — earliest/latest offsets per partition (measure backlog)

### Config & ACLs

- `/opt/kafka/bin/kafka-configs.sh --bootstrap-server localhost:9092 --describe --entity-type brokers --entity-name 0` — broker runtime config
- `/opt/kafka/bin/kafka-configs.sh --bootstrap-server localhost:9092 --describe --entity-type topics --entity-name <name>` — topic-level config (retention, etc.)
- `/opt/kafka/bin/kafka-acls.sh --bootstrap-server localhost:9092 --list` — list ACLs (debugging authorization failures)

### Key Kafka Directories & Files

- `/opt/kafka/config/server.properties` — main broker config (Apache tarball)
- `/etc/kafka/server.properties` — main broker config (Confluent packages)
- `/opt/kafka/config/kraft/server.properties` — broker config in KRaft mode
- `/opt/kafka/config/consumer.properties` / `producer.properties` — client default configs
- `/tmp/kafka-logs/` — **default** log/data dir (`log.dirs`); common production gotcha — should be moved off `/tmp`
- `/var/lib/kafka/data/` — typical production data directory (Confluent default)
- `/var/log/kafka/server.log` — broker log
- `/var/log/kafka/controller.log` — controller log (check during leadership/election issues)
- `/opt/kafka/logs/` — log directory for Apache tarball installs

---

## Apache NiFi Debugging

NiFi is largely managed through its web UI and REST API; debugging leans on logs, diagnostics, and the toolkit.

### Where NiFi lives (varies by install)

- **Binary tarball / manual install:** `$NIFI_HOME` is wherever you unpacked it, commonly `/opt/nifi/` or `/opt/nifi/nifi-current/`
- **RPM install:** `/opt/nifi/` with config under `/etc/nifi/` on some packagings
- **HDF / Cloudera managed:** `/usr/hdf/current/nifi/`

Examples below assume `NIFI_HOME=/opt/nifi`. Substitute your actual path.

### Service & Process

- `/opt/nifi/bin/nifi.sh status` — running status and PID
- `/opt/nifi/bin/nifi.sh start` / `stop` / `restart` — control the process
- `/opt/nifi/bin/nifi.sh diagnostics /opt/nifi/logs/diagnostics.txt` — dump JVM/repo/thread diagnostics (useful for hangs and memory issues)
- `/opt/nifi/bin/nifi.sh dump /opt/nifi/logs/threaddump.txt` — thread dump for stuck flows

### Logs

- `/opt/nifi/logs/nifi-app.log` — primary application log (first stop for processor errors and stack traces)
- `/opt/nifi/logs/nifi-bootstrap.log` — startup/shutdown and JVM launch
- `/opt/nifi/logs/nifi-user.log` — authentication/authorization events
- `/opt/nifi/logs/nifi-request.log` — HTTP request log
- `grep -i "outofmemory\|gc overhead" /opt/nifi/logs/nifi-app.log` — scan for memory pressure

### Configuration Files

- `/opt/nifi/conf/nifi.properties` — main config (ports, repo locations, security, cluster settings)
- `/opt/nifi/conf/bootstrap.conf` — JVM heap settings (`java.arg.2`/`java.arg.3` for `-Xms`/`-Xmx`); first place for memory tuning
- `/opt/nifi/conf/flow.json.gz` — serialized flow definition (newer versions; older use `flow.xml.gz`)
- `/opt/nifi/conf/authorizers.xml` — authorization policy config
- `/opt/nifi/conf/login-identity-providers.xml` — login provider config
- `/opt/nifi/conf/state-management.xml` — state provider config

### Repositories (check disk usage here when flows stall)

- `/opt/nifi/content_repository/` — content repo (FlowFile payloads); filling up is a frequent cause of stalls
- `/opt/nifi/flowfile_repository/` — FlowFile metadata/attributes
- `/opt/nifi/provenance_repository/` — provenance/lineage data
- `/opt/nifi/database_repository/` — internal H2 database
- `df -h /opt/nifi/content_repository` — check repo disk usage

> In production these repositories are frequently relocated to dedicated mounts via `nifi.properties`. Verify actual paths there rather than assuming defaults.

### JVM Diagnostics (use the NiFi PID from `nifi.sh status`)

- `jstack <nifi-pid>` — thread dump for deadlocks/pinned threads
- `jstat -gcutil <nifi-pid> 1000` — watch GC in real time
- `jmap -heap <nifi-pid>` — heap summary

### REST API (adjust host/port/scheme to your `nifi.properties`)

- `curl -k https://localhost:8443/nifi-api/system-diagnostics` — heap, repo usage, thread counts
- `curl -k https://localhost:8443/nifi-api/controller/cluster` — cluster node connectivity

### NiFi Toolkit (CLI)

- `/opt/nifi-toolkit/bin/cli.sh nifi current-user` — verify CLI identity
- `/opt/nifi-toolkit/bin/cli.sh nifi get-root-id` — fetch root process group ID
- `/opt/nifi-toolkit/bin/cli.sh nifi pg-status -pgid <id>` — process group status with queue counts and active threads