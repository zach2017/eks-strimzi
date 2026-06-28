Yep — that's expected, and it's the core reason node IPs make a bad SSH target. When an EC2 instance stops and starts (or the node group replaces a node), it gets a **brand-new public IP**. The managed node group also swaps in entirely new instances during updates, so even the instance IDs can change. Anything you hardcoded to yesterday's IP is now pointing at nothing.

This is exactly the problem the previous message was about. A raw node IP is ephemeral by design. You need an address that *survives* restarts. Three ways, depending on what changed:

## If it was a single node restart (IP changed, same instance)

Just re-fetch the current IP. Don't memorize it — look it up each time:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=micro-nodes" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress]' \
  --output table
```

Workable, but you're back to chasing IPs every restart. Fine for one-off pokes, painful for Ansible.

## The actual fix: stop using IPs that change

**SSM Session Manager** — the address never changes because there *is* no address. You connect by instance ID, and even when the ID changes you query for the current one. Nothing to hardcode, nothing to chase:

```bash
# One-liner: connect to whatever node is live, no IP involved
aws ssm start-session --target $(aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=micro-nodes" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
```

For Ansible, you point the inventory at instance IDs (or better, generate it dynamically with the `aws_ec2` inventory plugin so it self-updates when nodes change). Restarts stop mattering entirely. This is the genuinely correct answer for your use case and I'd push you toward it.

## If you want a fixed SSH hostname through restarts

Two options that give you a stable address:

**Elastic IP** — a permanent IP you own and re-attach. Cheap, simple, but pins to *one* specific node (and managed node groups replacing that node will detach it, so it's fragile on EKS nodes specifically):

```bash
# Allocate a permanent IP
aws ec2 allocate-address --query 'AllocationId' --output text
# Then associate it with a node's instance ID (re-associate after replacement)
aws ec2 associate-address --instance-id <INSTANCE_ID> --allocation-id <ALLOC_ID>
```

**NLB** (from the last message) — one stable DNS name that health-checks and routes to live nodes. Survives restarts because it tracks the targets, not a fixed IP.

---

Here's the honest through-line from the last few messages: you keep hitting the same wall — **node IPs are not stable, and SSH-to-node-IP fights that fact every time.** SSM removes the wall instead of climbing it. For "SSH in for Ansible configuration," it's the right tool, it's free, and restarts become a non-event.

Quick question so I aim correctly: was this a **single node** you manually stopped/started, or did the **whole node group get replaced** (e.g. after an update or scaling change)? If it's the latter, your instance IDs changed too, and that nudges even harder toward SSM + a dynamic inventory — I'll give you the exact Ansible config for it.