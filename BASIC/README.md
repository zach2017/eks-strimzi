
# Standing Up a Simple 2-Node EKS Cluster (Beginner-Friendly Guide)

This guide walks you through building a tiny Amazon EKS (Elastic Kubernetes Service) cluster from scratch, one command at a time. Each command has a plain-language explanation of **what** it does, **how** it works, and **why** we do it this way.

The end goal: a **2-node cluster** running on small `t3.micro` machines, where you can **SSH into the nodes from the public internet** so that later you can use **Ansible** to configure them.

---

## Important Heads-Up Before You Start

**About `t3.micro` nodes:** You asked for `t.micro` (smallest) nodes. These have **1 CPU and 1 GB of RAM**. That is *very* small for Kubernetes. Here's the catch most beginners hit:

- Kubernetes runs "system pods" on every node (networking, DNS, etc.) that use up memory.
- AWS's networking plugin (the "VPC CNI") limits how many pods a node can run based on the size of the machine. A `t3.micro` can only run about **4 pods total**, and the system already uses several.

**Translation:** This cluster is perfect for *learning* and *practicing SSH/Ansible*, but it will struggle to run real applications. If you later want to run actual workloads, bump up to `t3.small` or `t3.medium`. I'm using `t3.micro` (not `t2.micro`) because it's a newer, cheaper generation with better baseline performance.

**Cost warning:** EKS charges **$0.10 per hour** for the control plane (~$73/month) *whether or not* you run anything on it, **plus** the cost of the 2 EC2 nodes. Remember to delete everything when you're done (teardown commands are at the bottom).

---

## The Big Picture: What Are We Building?

Think of Kubernetes like a shipping company:

- **The Control Plane** = the head office that makes decisions (what runs where, restarts crashed things). AWS manages this *for* you in EKS — you never log into it.
- **The Worker Nodes** = the delivery trucks that actually carry the cargo (your applications). These are EC2 virtual machines. *These* are what you'll SSH into.
- **Pods** = the individual packages inside the trucks (your running app containers).

In plain AWS terms, we need to create, in order:
1. A **network** (VPC) for everything to live in — *or reuse your default one*.
2. An **IAM role** for the control plane (permission slip so AWS can manage things on your behalf).
3. The **EKS cluster** itself (the head office).
4. An **IAM role** for the worker nodes (permission slip for the trucks).
5. A **node group** = the 2 worker trucks.
6. **Security group rules** to open the SSH door from the internet.
7. **kubectl access** so you can talk to the cluster from your laptop.

---

## Prerequisites (Set Up Once)

You need three tools installed on your computer:

```bash
# 1. AWS CLI - lets you control AWS from the command line
#    Verify it's installed:
aws --version

# 2. kubectl - lets you control Kubernetes (the "kube control" tool)
#    Verify it's installed:
kubectl version --client

# 3. Configure your AWS login credentials (you'll paste your access keys)
aws configure
```

**Why `aws configure`?** This stores your AWS "username and password" (called an Access Key) on your machine so every command knows it's really you. It also sets your default **region** (like `us-east-1`) and output format. Without this, AWS rejects everything you try.

Also, create an **EC2 Key Pair** if you don't have one. This is the cryptographic "house key" that lets you SSH into the nodes:

```bash
# Creates a key pair named "eks-ssh-key" and saves the private key to a file
aws ec2 create-key-pair \
  --key-name eks-ssh-key \
  --query 'KeyMaterial' \
  --output text > eks-ssh-key.pem

# Lock down the key file so only you can read it (SSH refuses loose permissions)
chmod 400 eks-ssh-key.pem
```

**What's happening here?** AWS generates a matched pair of keys: a *public* key (it keeps) and a *private* key (you keep, saved as `eks-ssh-key.pem`). When you SSH in, the two keys "shake hands" to prove your identity. The `chmod 400` is critical — SSH will *refuse* to use a key file that other users on your computer could read, as a safety measure. `--query 'KeyMaterial'` plucks just the key text out of AWS's response, and `> eks-ssh-key.pem` saves it to a file.

---

# PART 1: Create the ONE Cluster

This is the single thing we create from the "first cluster" step — the EKS control plane and its supporting pieces. We'll build the prerequisites it depends on, then the cluster itself.

---

## Command 1: Find Your Network (VPC) Info

```bash
# Grab the ID of your account's default VPC and save it to a variable
export VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query 'Vpcs[0].VpcId' \
  --output text)

echo "My VPC is: $VPC_ID"
```

**What it does:** Finds your AWS account's pre-made "default VPC" and stores its ID (looks like `vpc-0abc123`) in a shortcut variable called `$VPC_ID`.

**What's a VPC?** A **Virtual Private Cloud** is your own private, walled-off section of AWS's network — like renting a fenced lot in a giant industrial park. Everything you build lives inside it. AWS gives every account a "default VPC" so beginners don't have to build networking from scratch.

**How it works:** `describe-vpcs` lists your VPCs; the `--filters` part says "only the default one"; `--query` (using a language called JMESPath) digs into the response and pulls out *just* the VpcId; `export VAR=$(...)` saves that result so later commands can reuse it without you copy-pasting.

**Best practice note:** In real production, you'd build a *custom* VPC with carefully planned public and private subnets. For learning, the default VPC is fine and saves a lot of steps.

---

## Command 2: Get Your Subnet IDs

```bash
# List all subnet IDs inside your VPC, comma-separated, save to a variable
export SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].SubnetId' \
  --output text | tr '\t' ',')

echo "My subnets are: $SUBNET_IDS"
```

**What it does:** Collects the IDs of all the **subnets** in your VPC and stores them as a comma-separated list.

**What's a subnet?** If the VPC is your fenced lot, **subnets** are the individual parking spaces within it, each tied to a different **Availability Zone** (a physically separate AWS data center). EKS *requires* subnets in **at least two** different zones so your cluster survives one data center having a bad day.

**How it works:** `describe-subnets` filtered to your VPC returns all subnets; `--output text` gives them separated by tabs; `tr '\t' ','` translates those tabs into commas because the EKS command in the next step wants a comma-separated list.

---

## Command 3: Create the Control Plane IAM Role

```bash
# Create the trust policy file (says "EKS is allowed to wear this role")
cat > eks-cluster-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "eks.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the IAM role using that trust policy
aws iam create-role \
  --role-name eksClusterRole \
  --assume-role-policy-document file://eks-cluster-trust-policy.json
```

**What it does:** Creates an **IAM Role** named `eksClusterRole` — a permission slip that the EKS control plane "wears" to do its job.

**What's an IAM Role?** **IAM** (Identity and Access Management) is AWS's security guard. A **Role** is like a job badge with specific permissions attached. Instead of giving the EKS service your personal password, you create a badge it can temporarily wear that grants *exactly* the permissions it needs — no more.

**What's a "trust policy"?** It answers the question *"who is allowed to wear this badge?"* Our JSON says: "Only the AWS service `eks.amazonaws.com` may assume this role." This stops anyone/anything else from grabbing those permissions.

**How it works:** The `cat > file << 'EOF' ... EOF` trick writes everything between the markers into a JSON file. Then `create-role` registers the badge with AWS, pointing at that trust file via `file://`.

**Best practice (least privilege):** This is a core security principle — give each component *only* the permissions it absolutely needs. The trust policy locking the role to *only* the EKS service is a textbook example.

---

## Command 4: Attach Permissions to the Control Plane Role

```bash
# Attach AWS's official EKS cluster permission set to our role
aws iam attach-role-policy \
  --role-name eksClusterRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
```

**What it does:** Sticks AWS's pre-built `AmazonEKSClusterPolicy` onto our role, granting the actual abilities (managing load balancers, networking, etc.).

**Why a separate step?** Command 3 created an *empty* badge and said who can wear it. This command writes the *actual permissions* onto the badge. Roles and their permissions are deliberately separate so you can mix and match.

**What's an ARN?** **Amazon Resource Name** — a unique address for any AWS thing, like a postal address. `arn:aws:iam::aws:policy/AmazonEKSClusterPolicy` is the exact address of AWS's official, AWS-maintained policy. Using their managed policy means AWS keeps it updated for you.

---

## Command 5: CREATE THE CLUSTER (the main event)

```bash
# Save the role's ARN to a variable first
export CLUSTER_ROLE_ARN=$(aws iam get-role \
  --role-name eksClusterRole \
  --query 'Role.Arn' --output text)

# Create the EKS control plane
aws eks create-cluster \
  --name my-micro-cluster \
  --role-arn $CLUSTER_ROLE_ARN \
  --resources-vpc-config subnetIds=$SUBNET_IDS,endpointPublicAccess=true,endpointPrivateAccess=true
```

**What it does:** This is the headline command — it tells AWS to build the **Kubernetes control plane** (the head office). AWS provisions and manages this entirely; you never log into it directly.

**How it works, piece by piece:**
- `--name my-micro-cluster` — what we're calling our cluster.
- `--role-arn` — hands over the permission badge from Commands 3–4 so the control plane can act on your behalf.
- `subnetIds=$SUBNET_IDS` — tells it which parking spaces (across multiple zones) to spread across.
- `endpointPublicAccess=true` — lets you run `kubectl` from your laptop over the internet (needed for learning).
- `endpointPrivateAccess=true` — also allows access from *inside* the VPC, which the worker nodes use to talk to the control plane.

**This takes 10–15 minutes.** AWS is building a highly-available, multi-zone management system behind the scenes. Be patient. Check progress with:

```bash
# Watch the status until it says "ACTIVE"
aws eks describe-cluster --name my-micro-cluster \
  --query 'cluster.status' --output text
```

**Best practice note:** In production you'd often set `endpointPublicAccess=false` and only allow private access, reaching the cluster through a VPN or bastion host for tighter security. We keep public access on here for simplicity.

---

## Command 6: Connect kubectl to Your Cluster

```bash
# Update your local kubeconfig file so kubectl knows how to reach the cluster
aws eks update-kubeconfig --name my-micro-cluster
```

**What it does:** Writes the cluster's address and login details into a file on your computer (`~/.kube/config`) so the `kubectl` tool knows *which* cluster to talk to and *how* to authenticate.

**Why needed?** `kubectl` by itself doesn't know your cluster exists. This command fetches the connection info (server URL, security certificates) and saves it. After this, `kubectl` commands "just work" against your new cluster.

**How it works:** It uses your AWS credentials to ask EKS "how do I connect?", then merges that info into your local kube config. Authentication cleverly piggybacks on your AWS identity, so you don't manage a separate Kubernetes password.

```bash
# Test it — this talks to the control plane and lists nodes
kubectl get nodes
```

Right now this will say "No resources found" — **that's expected!** We have a head office but no delivery trucks yet. Let's add them.

---

# PART 2: Create the Resources One by One

Now we add the worker nodes and open up SSH access.

---

## Command 7: Create the Worker Node IAM Role

```bash
# Trust policy: this badge is worn by EC2 machines (the worker trucks)
cat > eks-node-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the worker node role
aws iam create-role \
  --role-name eksNodeRole \
  --assume-role-policy-document file://eks-node-trust-policy.json
```

**What it does:** Creates a *second* permission badge, this one named `eksNodeRole`, to be worn by the **worker node EC2 machines**.

**Why a different role from the cluster?** The control plane and the worker nodes do completely different jobs, so they need different permissions. The trust policy here says `ec2.amazonaws.com` (not `eks`) because the *EC2 virtual machines* are the ones wearing this badge. Keeping them separate follows least-privilege: neither has powers it doesn't need.

---

## Command 8: Attach the Three Required Node Policies

```bash
# Policy 1: lets nodes register with EKS and pull cluster info
aws iam attach-role-policy --role-name eksNodeRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

# Policy 2: lets nodes set up pod networking (the VPC CNI)
aws iam attach-role-policy --role-name eksNodeRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

# Policy 3: lets nodes download container images from ECR
aws iam attach-role-policy --role-name eksNodeRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
```

**What it does:** Worker nodes need **three** standard AWS permission sets to function. We attach all three to the node role.

**Why each one (in plain terms):**
1. **WorkerNodePolicy** — lets each node "phone home" to the control plane and join the cluster, like an employee badging into the building.
2. **CNI_Policy** — **CNI** = Container Network Interface. This lets the node hand out network addresses (IP addresses) to the pods running on it, so they can talk to each other and the internet.
3. **ECR ReadOnly** — **ECR** = Elastic Container Registry, AWS's storage for container images. This lets nodes *download* (but not change) the images they need to run your apps.

**Best practice note:** These are the three AWS-recommended baseline policies for every EKS node. Using AWS-managed policies means they stay current automatically — you don't have to hand-write permission lists.

---

## Command 9: CREATE THE 2-NODE NODE GROUP (with SSH enabled)

```bash
# Save the node role ARN to a variable
export NODE_ROLE_ARN=$(aws iam get-role \
  --role-name eksNodeRole \
  --query 'Role.Arn' --output text)

# Create the managed node group: 2x t3.micro, SSH key attached
aws eks create-nodegroup \
  --cluster-name my-micro-cluster \
  --nodegroup-name micro-nodes \
  --node-role $NODE_ROLE_ARN \
  --subnets $(echo $SUBNET_IDS | tr ',' ' ') \
  --instance-types t3.micro \
  --scaling-config minSize=2,maxSize=2,desiredSize=2 \
  --remote-access ec2SshKey=eks-ssh-key
```

**What it does:** This is the second headline command — it creates the **2 worker trucks** (EC2 machines) and joins them to your cluster automatically. It also attaches your SSH key so you can log in.

**How it works, piece by piece:**
- `--cluster-name` — which cluster these nodes belong to.
- `--node-role` — the permission badge from Commands 7–8.
- `--subnets` — where to place the nodes (we convert commas back to spaces because *this* command wants space-separated values — a common AWS CLI quirk).
- `--instance-types t3.micro` — the small machine size you requested.
- `--scaling-config minSize=2,maxSize=2,desiredSize=2` — **exactly 2 nodes**, never more, never fewer.
- `--remote-access ec2SshKey=eks-ssh-key` — **this is the SSH magic.** It attaches the key pair from the prerequisites so you can log into the nodes.

**What's a "managed node group"?** Instead of hand-creating EC2 machines and manually joining them to Kubernetes, EKS does it for you: it picks the right operating system image, installs the Kubernetes agent, and registers the nodes. If a node dies, it auto-replaces it. Much easier than the manual way.

**This takes another 3–5 minutes.** Then verify:

```bash
# Should now show 2 nodes in "Ready" status
kubectl get nodes
```

---

## Command 10: Open the SSH Door (Security Group Rule)

When you used `--remote-access`, EKS created a **security group** for SSH but, depending on settings, may have left it closed or open only to the VPC. Let's explicitly open port 22 to the internet.

```bash
# Find the security group EKS created for SSH remote access
export SSH_SG=$(aws eks describe-nodegroup \
  --cluster-name my-micro-cluster \
  --nodegroup-name micro-nodes \
  --query 'nodegroup.resources.remoteAccessSecurityGroup' \
  --output text)

# Open port 22 (SSH) to the whole internet
aws ec2 authorize-security-group-ingress \
  --group-id $SSH_SG \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

**What it does:** Adds a rule allowing **SSH (port 22)** traffic *into* your nodes from **any internet address**.

**What's a security group?** Think of it as a **firewall** — a bouncer at the door of your machines. By default it blocks almost everything coming *in*. You must explicitly add "allow" rules for the traffic you want. This is "deny by default," a security best practice.

**How it works:**
- `authorize-security-group-ingress` = "add an inbound allow rule."
- `--protocol tcp --port 22` = SSH specifically (SSH always uses port 22).
- `--cidr 0.0.0.0/0` = **"from anywhere on the internet."** The notation `0.0.0.0/0` means "all possible IP addresses."

**⚠️ BIG SECURITY WARNING:** Opening SSH to `0.0.0.0/0` (the entire internet) means *anyone in the world* can attempt to connect. Bots constantly scan for this. You requested public SSH for Ansible, so this matches your goal — but the **strong** best practice is to restrict it to **only your own IP address**:

```bash
# MUCH SAFER: replace the above --cidr with YOUR IP only
# Find your IP:
curl -s https://checkip.amazonaws.com
# Then use: --cidr YOUR.IP.ADDRESS.HERE/32
# The "/32" means "this one exact IP address only"
```

For a real setup, consider locking it to your IP, or your Ansible control machine's IP, rather than the whole world.

---

## Command 11: SSH Into a Node (the payoff!)

```bash
# Get the public IP address of your first worker node
aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=micro-nodes" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].PublicIpAddress' \
  --output text

# SSH in using your key (Amazon Linux's default user is "ec2-user")
ssh -i eks-ssh-key.pem ec2-user@<PUBLIC_IP_FROM_ABOVE>
```

**What it does:** First finds the public IP address of a node, then logs you into it over SSH.

**How it works:**
- The first command filters all EC2 instances down to ones tagged as belonging to our node group *and* currently running, then prints their public IPs.
- `ssh -i eks-ssh-key.pem` — the `-i` flag points SSH at your *private* key (the "house key") for the handshake.
- `ec2-user@...` — `ec2-user` is the default login username on Amazon Linux nodes; the part after `@` is the node's public IP.

**You're in!** From here, Ansible can take over: point your Ansible inventory at these public IPs, using `eks-ssh-key.pem` as the SSH key and `ec2-user` as the user. You now have a foundation for automated configuration.

---

## Quick Reference: Full Command Order

| # | Command | Creates |
|---|---------|---------|
| Prep | `create-key-pair` | SSH house key |
| 1 | `describe-vpcs` | Find network |
| 2 | `describe-subnets` | Find parking spaces |
| 3 | `iam create-role` (cluster) | Control plane badge |
| 4 | `iam attach-role-policy` | Control plane permissions |
| 5 | `eks create-cluster` | **The control plane** |
| 6 | `eks update-kubeconfig` | Connect kubectl |
| 7 | `iam create-role` (node) | Worker badge |
| 8 | `iam attach-role-policy` x3 | Worker permissions |
| 9 | `eks create-nodegroup` | **The 2 worker nodes + SSH** |
| 10 | `authorize-security-group-ingress` | Open SSH door |
| 11 | `ssh` | Log in |

---

## TEARDOWN: Delete Everything (Avoid Surprise Bills!)

Run these **in order** when you're done. Each waits implicitly — let node group deletion finish before deleting the cluster.

```bash
# 1. Delete the node group first (the trucks) — takes a few minutes
aws eks delete-nodegroup \
  --cluster-name my-micro-cluster \
  --nodegroup-name micro-nodes

# 2. Wait until it's gone, then delete the cluster (the head office)
aws eks delete-cluster --name my-micro-cluster

# 3. Detach and delete the IAM roles (clean up badges)
aws iam detach-role-policy --role-name eksNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam detach-role-policy --role-name eksNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam detach-role-policy --role-name eksNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
aws iam delete-role --role-name eksNodeRole

aws iam detach-role-policy --role-name eksClusterRole --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
aws iam delete-role --role-name eksClusterRole

# 4. Delete the SSH key pair
aws ec2 delete-key-pair --key-name eks-ssh-key
```

**Why order matters:** You can't delete the cluster while nodes still belong to it (like you can't close the office while trucks are still assigned). And you can't delete a role while policies are still attached. Delete from the "outside in."

**Double-check nothing lingers:** Visit the AWS Console for EKS, EC2, and IAM to confirm everything is gone. The control plane charge stops only when the cluster is fully deleted.

---

## Summary of Best Practices We Followed

- **Least privilege:** Separate, narrowly-scoped IAM roles for control plane vs. nodes.
- **AWS-managed policies:** Used AWS's maintained permission sets instead of hand-writing them.
- **Multi-zone subnets:** Spread across Availability Zones for resilience.
- **Managed node groups:** Let EKS handle node lifecycle instead of manual EC2 setup.
- **Deny-by-default firewall:** Security groups block everything until you open specific doors.
- **Variables over copy-paste:** Stored IDs in shell variables to reduce errors.

## Things to Improve for Production (Beyond This Learning Setup)

- Restrict SSH to your IP only (`/32`), not the whole internet.
- Use a **custom VPC** with dedicated public/private subnets.
- Put nodes in **private subnets** and reach them via a **bastion host** or **AWS Systems Manager Session Manager** (SSH with no open ports at all).
- Set `endpointPublicAccess=false` for the control plane.
- Use larger instances (`t3.small`+) so pods actually fit.
- Enable cluster logging and monitoring (CloudWatch).

**Create EKS cluster (2x t3.micro nodes, public subnets + SSH):**

```bash
# 1. Key pair
aws ec2 create-key-pair --key-name eks-key --query KeyMaterial --output text > eks-key.pem
chmod 400 eks-key.pem

# 2. Create cluster (eksctl - simplest)
eksctl create cluster \
  --name micro-eks \
  --region us-east-1 \
  --nodegroup-name micro-ng \
  --node-type t3.micro \
  --nodes 2 \
  --node-volume-size 20 \
  --ssh-access \
  --ssh-public-key eks-key \
  --managed
```

**SSH to nodes:**
```bash
ssh -i eks-key.pem ec2-user@<node-public-ip>
```

(eksctl auto-creates public subnets + allows SSH from 0.0.0.0/0 on port 22.)

aws eks update-kubeconfig --region us-east-1 --name micro-eks

kubectl get nodes
kubectl describe node <node-name>