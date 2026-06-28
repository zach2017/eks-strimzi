# Terraform + AWS EKS — A Beginner's Guide

*Building a Kubernetes cluster on AWS with Terraform, explained line by line.*

This guide walks through a real Terraform file. Every line gets a plain-English explanation of **what** it does, **why** it's there, **how** it works, and what your **options** are. Expand any "ℹ️ More info" section to dig deeper or jump to the official docs.

> Reference links point to the official HashiCorp, Terraform Registry, and AWS documentation, which are updated regularly — always confirm exact version numbers and argument names there before a production deployment. This guide is for learning and is not affiliated with or endorsed by IBM, HashiCorp, or Amazon.

---

## Contents

0. [The big picture (read this first)](#0--the-big-picture-read-this-first)
1. [First-time setup: install tools & add AWS keys](#1--first-time-setup)
2. [The `terraform` block — versions & providers](#2--the-terraform-block)
3. [The `provider` block — picking your region](#3--the-provider-block)
4. [The `vpc` module — building the network](#4--the-vpc-module--your-private-network)
5. [The `eks` module — building the cluster](#5--the-eks-module--your-kubernetes-cluster)
6. [Running it: the four commands](#6--running-it-the-four-commands)
7. [Cleaning up so you don't get charged](#7--cleaning-up-so-you-dont-get-charged)
8. [Quick recap](#8--quick-recap)

---

## 0 · The big picture (read this first)

Imagine you want to set up a bunch of computers in the cloud. You *could* click around the Amazon website for an hour, creating each piece by hand. But if you ever need to do it again — or undo it — you'd have to remember every click.

**Terraform** solves this. You write down what you want in a text file, and Terraform builds it for you. Change the file, and it updates things. Delete the file's resources, and it cleans everything up. This idea is called **Infrastructure as Code**: your cloud setup lives in a file you can save, share, and track.

| Term | Plain-English meaning |
|------|----------------------|
| **AWS** | Amazon Web Services. A company that rents you computers, storage, and networking over the internet. |
| **Terraform** | A free tool (made by HashiCorp) that reads your text file and builds cloud stuff to match. |
| **Kubernetes (K8s)** | A system that runs and manages lots of small app containers across many computers. A traffic controller for your apps. |
| **EKS** | Elastic Kubernetes Service. Amazon's ready-made version of Kubernetes, so you don't build the hard parts yourself. |
| **VPC** | Virtual Private Cloud. Your own private network inside AWS where your computers live and talk safely. |
| **Module** | A reusable bundle of Terraform code someone already wrote, so you don't start from zero. |

> **What this file builds:** a private network (VPC), and inside it a small Kubernetes cluster (EKS) with one worker computer. By the end you'll have a place to run container apps on AWS.

---

## 1 · First-time setup

Before Terraform can build anything, two things need to be true: the tools are installed, and Terraform is allowed to log in to your AWS account. Let's do both.

### Step 1a — Install Terraform and the AWS CLI

You need two free programs on your computer:

- **Terraform** — the tool that reads your file and builds things.
- **AWS CLI** — a helper that stores your AWS login and lets tools talk to Amazon.

<details>
<summary>ℹ️ More info: how to install them</summary>

Follow the official instructions for your operating system (Windows, Mac, or Linux):

- Install Terraform: <https://developer.hashicorp.com/terraform/install>
- Install the AWS CLI: <https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html>

After installing, open a terminal and check they work:

```bash
# should print a version number like 1.x.x
terraform -version

# should also print a version number
aws --version
```

As of this writing the newest Terraform is in the 1.x series, and your file only requires version 1.5 or higher, so any recent install is fine.

</details>

### Step 1b — Give Terraform your AWS keys (credentials)

Terraform needs permission to act in your AWS account. The cleanest way is to store your keys with the AWS CLI **once**, and let Terraform borrow them automatically. Run this:

```bash
aws configure
```

It will ask you four questions. Type your answers:

```text
AWS Access Key ID      # like a username (from the AWS Console)
AWS Secret Access Key  # like a password — keep it secret!
Default region name    # for this guide type: us-east-1
Default output format  # just press Enter, or type: json
```

That's it. Terraform automatically reads these saved keys, so you never put passwords inside your `.tf` files.

> ⚠️ **Heads up — never put keys in your code.** Don't paste your Access Key or Secret Key into the Terraform file. Anyone who sees the file (or your GitHub) could take over your account. The `aws configure` method keeps them in a safe, separate place.

<details>
<summary>ℹ️ More info: where do I get the keys, and what are the safer options?</summary>

**Where keys come from:** in the AWS Console, your account's security page (IAM) lets you create an access key. Official guide: [Configuration & credential file settings](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).

**The four ways to give Terraform credentials** (it checks them in order):

- **Shared credentials file** — what `aws configure` creates. Easiest for learning.
- **Environment variables** — set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in your terminal. Popular for automated pipelines (CI/CD).
- **Named profiles** — keep several accounts side by side and pick one with `AWS_PROFILE=work`.
- **IAM roles / SSO** — the most secure for companies; no long-lived keys at all. Start with `aws configure sso`.

Full provider auth reference: [AWS provider — Authentication and Configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration).

</details>

### Step 1c — Put the code in a file

Make a new folder, and inside it create a file named `main.tf`. Paste the whole configuration (shown section by section below) into that file. The `.tf` ending tells Terraform "this is for you."

---

## 2 · The `terraform` block

This first block is like the **settings page** for the whole project. It doesn't build anything in AWS. Instead it says: "Which version of Terraform do I need, and which plugins (called *providers*) should I download?"

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

**Line 1 — `terraform {`**
**What:** opens the settings block. **Why:** every project needs one place to declare its requirements. **How:** the `{ }` braces hold everything that belongs to these settings. **Options:** there's only one `terraform` block per project.

**Line 2 — `required_version = ">= 1.5"`**
**What:** says you need Terraform version 1.5 or newer. **Why:** older versions might not understand newer features, so this prevents confusing errors. **How:** `>=` means "greater than or equal to." **Options:** you could pin tighter, e.g. `~> 1.5` (allow 1.5.x but not 2.0).

<details>
<summary>ℹ️ More info: what do the version symbols mean?</summary>

- `>= 1.5` — this version or anything higher.
- `~> 1.5` — "pessimistic" constraint: allow 1.5, 1.6, 1.7… but *not* 2.0. It lets in small updates but blocks big, possibly-breaking ones.
- `= 1.5.7` — exactly that version, nothing else.

Docs: [Version Constraints](https://developer.hashicorp.com/terraform/language/expressions/version-constraints).

</details>

**Line 3 — `required_providers {`**
**What:** opens the list of plugins to download. **Why:** Terraform itself doesn't know how to talk to AWS — it needs the AWS *provider* plugin. **How:** each plugin gets a nickname and details inside this block. **Options:** you can list many providers here (AWS, Google Cloud, GitHub, etc.).

**Line 4 — `aws = {`**
**What:** gives the AWS provider the local nickname `aws`. **Why:** later code refers to it by this short name. **How:** the nickname is what you'll type in the `provider "aws"` block. **Options:** the nickname is usually left as `aws` by convention.

**Line 5 — `source = "hashicorp/aws"`**
**What:** the official address of the plugin in Terraform's online registry. **Why:** tells Terraform exactly which plugin to fetch (there are many). **How:** it reads as `publisher/name`. **Options:** almost always `hashicorp/aws` for AWS.

<details>
<summary>ℹ️ More info: see the AWS provider page</summary>

The provider is published here, with full documentation of every resource it can build:

<https://registry.terraform.io/providers/hashicorp/aws/latest>

It's maintained by HashiCorp together with AWS and is one of the most-used providers in the world.

</details>

**Line 6 — `version = "~> 6.0"`**
**What:** asks for AWS provider version 6.x. **Why:** version 6 has features and fixes the modules below expect. **How:** `~> 6.0` allows 6.1, 6.2… but blocks 7.0. **Options:** you could widen or tighten this, but pinning protects you from surprise breaking changes.

<details>
<summary>ℹ️ More info: why version 6 specifically?</summary>

AWS provider 6.0 was a **major** release with breaking changes (some old settings were removed or renamed). Pinning to `~> 6.0` means you stay on the 6 line and won't accidentally jump to a future 7.0 that could break your file.

Upgrade notes: [AWS Provider Version 6 Upgrade Guide](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/version-6-upgrade).

</details>

**Lines 7–9 — `}` `}` `}`**
**What:** three closing braces. **Why:** every `{` must be matched by a `}` — these close the `aws` block, the `required_providers` block, and the `terraform` block, in that order. **How:** indentation helps you see which brace closes which block. **Options:** none — the braces are required.

---

## 3 · The `provider` block

Now we *configure* the AWS plugin we just downloaded. The main thing it needs is a **region** — which part of the world your computers should live in.

```hcl
provider "aws" {
  region = "us-east-1"
}
```

**Line 1 — `provider "aws" {`**
**What:** starts configuring the provider nicknamed `aws`. **Why:** the plugin needs to know *how* to behave (which region, which account). **How:** the name in quotes matches the nickname from the `terraform` block. **Options:** you can have more than one AWS provider for different regions using `alias`.

**Line 2 — `region = "us-east-1"`**
**What:** builds everything in the US East (Northern Virginia) region. **Why:** AWS is split into regions worldwide; you must pick one. `us-east-1` is the biggest and a common default. **How:** AWS resources are tied to a region. **Options:** any region code, e.g. `us-west-2` (Oregon), `eu-west-1` (Ireland), `ap-south-1` (Mumbai).

<details>
<summary>ℹ️ More info: how do I choose a region?</summary>

Pick the region **closest to your users** for speed, or one that's cheaper for your budget. Prices and available services differ slightly by region.

- List of all regions & codes: [AWS Regions and Availability Zones](https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html)
- Provider config reference: [hashicorp/aws — Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

Note: you don't write your secret keys here. The provider quietly uses the keys you saved with `aws configure` in Step 1b.

</details>

**Line 3 — `}`**
**What:** closes the provider block. **Why & how:** matches the opening brace on line 1. **Options:** none.

---

## 4 · The `vpc` module — your private network

Before computers can run, they need a **network** to live in. Building a network by hand means creating subnets, route tables, gateways, and more — dozens of pieces. Instead, we use a ready-made **module** that does all of it from a few simple settings.

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
```

**Line 1 — `module "vpc" {`**
**What:** starts using a module and names this copy `vpc`. **Why:** the name lets other code grab its results later (you'll see `module.vpc.vpc_id` in the EKS section). **How:** `module` is the keyword; the quoted text is your label. **Options:** you can name it anything, e.g. `network`.

**Line 2 — `source = "terraform-aws-modules/vpc/aws"`**
**What:** where to download the module from. **Why:** this is the most popular community VPC module — well-tested and saves ~200 lines of code. **How:** Terraform fetches it from the public registry. **Options:** you could write your own VPC from scratch, or use a different module.

<details>
<summary>ℹ️ More info: see the VPC module</summary>

This is the most-downloaded module on the registry. It builds the VPC, subnets, route tables, internet gateway, and (optionally) NAT gateways for you.

<https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest>

</details>

**Line 3 — `version = "~> 5.0"`**
**What:** use version 5.x of the VPC module. **Why:** pinning keeps your build repeatable — the same version always behaves the same way. **How:** `~> 5.0` allows 5.1, 5.2… but not 6.0. **Options:** a newer 6.x line exists; see the note below.

> 📝 **Good to know:** the VPC module now has a **6.x** series available too. `~> 5.0` is still perfectly fine and stable for learning. If you later move to 6.x, read its changelog first, because major version jumps can rename settings.

**Line 4 — `name = "eks-vpc"`**
**What:** names your network "eks-vpc." **Why:** makes it easy to spot in the AWS Console among other resources. **How:** the module uses this name as a prefix on the things it creates. **Options:** any short, descriptive name.

**Line 5 — `cidr = "10.0.0.0/16"`**
**What:** the range of private IP addresses your network owns. **Why:** every device needs an address; this reserves a big pool. **How:** `/16` gives you ~65,000 addresses (10.0.0.0 through 10.0.255.255). **Options:** common private ranges are `10.0.0.0/16`, `172.16.0.0/16`, or `192.168.0.0/16`.

<details>
<summary>ℹ️ More info: what is CIDR / what does "/16" mean?</summary>

CIDR is just a compact way to describe a block of IP addresses. The number after the slash says how many addresses are in the block — **smaller number = bigger block**.

- `/16` → ~65,536 addresses (a large network)
- `/24` → 256 addresses (a small slice, used for subnets below)

Background reading: [VPC CIDR blocks (AWS docs)](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-cidr-blocks.html).

</details>

**Line 6 — `azs = ["us-east-1a", "us-east-1b"]`**
**What:** picks two *Availability Zones* (separate data centers) in the region. **Why:** spreading across two means if one building has a problem, your cluster can keep running. **How:** the square brackets `[ ]` make a *list*. **Options:** you can list more zones, like adding `"us-east-1c"`.

<details>
<summary>ℹ️ More info: what's an Availability Zone?</summary>

A region (like `us-east-1`) is made of several Availability Zones — physically separate data centers a few miles apart. Using two or more is how you make things **fault-tolerant**: a fire, flood, or power loss in one zone won't take down everything.

Docs: [Regions and Availability Zones](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html).

</details>

**Line 7 — `public_subnets = ["10.0.101.0/24", "10.0.102.0/24"]`**
**What:** two small address slices, one per zone, that can reach the internet. **Why:** "public" subnets let your cluster be reached from outside (handy for learning). **How:** each `/24` is 256 addresses carved out of the big `/16`. **Options:** you'd usually also add `private_subnets` for things that should stay hidden.

<details>
<summary>ℹ️ More info: public vs private subnets</summary>

- **Public subnet** — has a route to the internet through an Internet Gateway. Good for things people connect to.
- **Private subnet** — no direct internet route. Good for databases and back-end servers you want to keep hidden.

For real production clusters, worker nodes usually go in **private** subnets for safety. This guide uses public subnets to keep the setup simple and cheap.

</details>

**Line 8 — `enable_nat_gateway = false`**
**What:** turns *off* the NAT gateway. **Why:** a NAT gateway lets private subnets reach the internet — but it costs money every hour. We skip it to stay (almost) free. **How:** `false` means "don't create it." **Options:** set to `true` if you add private subnets that need outbound internet.

<details>
<summary>ℹ️ More info: what is a NAT gateway and why does it cost money?</summary>

A **NAT gateway** is like a one-way door: machines in a *private* subnet can reach out to the internet (to download updates, say), but the internet can't start a connection back in. It's great for security, but AWS charges an hourly fee *plus* data fees.

Since this guide only uses public subnets, we don't need one — so we set it to `false` and save money.

Pricing detail: [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/).

</details>

**Lines 9–12 — the `tags` block**
**What:** sticky labels attached to everything the module makes. **Why:** tags help you sort, find, and track costs later. **How:** each line is a `Key = "Value"` pair. **Options:** add any tags you like, e.g. `Owner = "Sam"` or `Team = "platform"`.

<details>
<summary>ℹ️ More info: why tagging matters</summary>

Tags are free metadata. Teams use them to answer questions like "which resources belong to the dev environment?" or "how much is the marketing project costing us?" The AWS billing tools can group costs by tag.

Best practices: [AWS Tagging Best Practices](https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/tagging-best-practices.html).

</details>

**Line 13 — `}`**
**What:** closes the VPC module block. **Why & how:** matches the opening brace on line 1.

---

## 5 · The `eks` module — your Kubernetes cluster

This is the main event. Building a Kubernetes cluster by hand is genuinely hard — there's a control plane, worker computers, security roles, networking add-ons, and more. The EKS module wires it all together from a handful of settings, and plugs straight into the VPC you just built.

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  cluster_name    = "basic-eks"
  cluster_version = "1.33"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1
    }
  }

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
```

> ⚠️ **Important version heads-up.** You pinned the EKS module to `~> 21.0`, which is the newest line. In version 21, several setting names were **renamed** from older guides you might see online. The notes below flag each one. If `terraform plan` complains that an argument is "unsupported," this is almost always why. A copy-ready, fully-corrected v21 block is at the [end of this section](#-copy-the-v21-correct-version-of-the-eks-block).

**Line 1 — `module "eks" {`**
**What:** starts the EKS module and names it `eks`. **Why:** groups all cluster settings together. **How:** same `module` keyword as before. **Options:** rename the label if you like.

**Line 2 — `source = "terraform-aws-modules/eks/aws"`**
**What:** download the popular community EKS module. **Why:** it handles the genuinely hard parts of EKS for you. **How:** fetched from the public registry. **Options:** other EKS modules exist, but this is the standard choice.

<details>
<summary>ℹ️ More info: see the EKS module & examples</summary>

Full documentation, inputs, outputs, and ready-to-copy examples:

<https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest>

Source & changelog: <https://github.com/terraform-aws-modules/terraform-aws-eks>

</details>

**Line 3 — `version = "~> 21.0"`**
**What:** use version 21.x of the EKS module. **Why:** 21 is the current major line with the latest features. **How:** allows 21.1, 21.2… not 22.0. **Options:** older lines (18, 19, 20) used different setting names — don't mix examples across versions.

**Line 4 — `cluster_name = "basic-eks"`**
**What:** names the cluster "basic-eks." **Why:** you'll use this name to connect to it later. **How:** shows up in the AWS Console and in your `kubectl` config. **Options:** any name you like.

> ⚠️ **v21 rename:** in module version 21 this input is now called `name` (not `cluster_name`). The old name may still work for now but can warn or break. The safe v21 line is:
> ```hcl
> name = "basic-eks"
> ```

**Line 5 — `cluster_version = "1.33"`**
**What:** the Kubernetes version to run. **Why:** Kubernetes releases new versions a few times a year; you pick one AWS supports. **How:** EKS installs that version of the control plane. **Options:** AWS supports a rolling window of versions; 1.33 is a current one.

> ⚠️ **v21 rename:** in module version 21 this input is now `kubernetes_version` (not `cluster_version`). The safe v21 line is:
> ```hcl
> kubernetes_version = "1.33"
> ```

<details>
<summary>ℹ️ More info: which Kubernetes versions can I pick?</summary>

AWS supports several versions at once and retires old ones on a schedule. Check what's currently supported before choosing:

- [EKS Kubernetes version lifecycle](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)
- [EKS version release notes](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html)

Tip: don't pick a version that's about to lose support, or you'll have to upgrade again soon.

</details>

**Line 6 — `vpc_id = module.vpc.vpc_id`**
**What:** tells the cluster which network to use — the one the VPC module built. **Why:** the cluster must live inside a VPC. **How:** `module.vpc.vpc_id` reads the `vpc_id` *output* from your VPC module. This is how modules connect. **Options:** you could point at an existing VPC's ID instead.

<details>
<summary>ℹ️ More info: how does one module use another's result?</summary>

Modules can **output** values — facts about what they built. The VPC module outputs things like `vpc_id` and `public_subnets`. You read them with the pattern `module.<name>.<output>`.

Terraform also notices this link and automatically builds the VPC *before* the cluster, since the cluster depends on it. That automatic ordering is one of Terraform's best features.

</details>

**Line 7 — `subnet_ids = module.vpc.public_subnets`**
**What:** which subnets the cluster's computers go in. **Why:** the worker computers need somewhere to live inside the VPC. **How:** reads the list of public subnet IDs the VPC module made. **Options:** in production you'd usually pass `private_subnets` here instead, for safety.

**Line 8 — `cluster_endpoint_public_access = true`**
**What:** lets you reach the cluster's control panel (API) from the internet. **Why:** makes it easy to run `kubectl` from your laptop while learning. **How:** `true` opens a public address for the API. **Options:** set to `false` for private-only access (more secure, but harder to reach).

> ⚠️ **v21 rename:** in module version 21 this is now `endpoint_public_access` (the `cluster_` prefix was dropped). The safe v21 line is:
> ```hcl
> endpoint_public_access = true
> ```

**Line 9 — `enable_cluster_creator_admin_permissions = true`**
**What:** makes *you* (the person running Terraform) a full admin of the cluster. **Why:** without this you'd build a cluster you can't actually manage. **How:** it adds your AWS identity as an administrator automatically. **Options:** set to `false` if you'll grant access another way.

<details>
<summary>ℹ️ More info: why would this ever be off?</summary>

In bigger teams, access is often managed centrally with a fixed list of users and roles (called *access entries*) rather than "whoever ran Terraform." For a solo learner, `true` is exactly what you want — it saves a frustrating "you are not authorized" error.

</details>

**Line 10 — `eks_managed_node_groups = {`**
**What:** starts describing your *worker computers*. **Why:** the control plane is the brain, but you need actual machines to run apps — these are them. **How:** "managed" means AWS handles patching and replacing them. **Options:** you can define several groups with different machine types.

<details>
<summary>ℹ️ More info: control plane vs worker nodes</summary>

- **Control plane** — the "brain" that schedules and tracks everything. EKS runs and maintains this for you.
- **Worker nodes** — the actual computers (EC2 instances) where your containers run. You choose how many and how powerful.

A **managed node group** means AWS does the boring upkeep (security patches, replacing broken machines). Docs: [Managed node groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html).

</details>

**Line 11 — `default = {`**
**What:** names this group of workers "default." **Why:** a label so you can have more than one group. **How:** the settings inside `{ }` describe this group. **Options:** name it anything, e.g. `general` or `spot-workers`.

**Line 12 — `instance_types = ["t3.small"]`**
**What:** the size/power of each worker computer. **Why:** `t3.small` is small and cheap — fine for testing. **How:** AWS launches EC2 machines of this type. **Options:** bigger types like `t3.medium` or `m5.large` for more power (and more cost).

<details>
<summary>ℹ️ More info: how do I read "t3.small"?</summary>

AWS instance types follow a pattern: a **family** letter (t, m, c, r…), a **generation** number, and a **size** (nano, micro, small, medium, large…). The `t` family is "burstable" — cheap, good for light or bursty work.

Full list & specs: [Amazon EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/).

</details>

**Line 13 — `min_size = 1`**
**What:** never run fewer than 1 worker. **Why:** a floor so your cluster always has at least one machine. **How:** autoscaling won't shrink below this. **Options:** any whole number; `0` would allow scaling all the way down.

**Line 14 — `max_size = 2`**
**What:** never run more than 2 workers. **Why:** a ceiling that protects you from runaway costs. **How:** autoscaling won't grow past this. **Options:** raise it if your apps need to scale out more.

**Line 15 — `desired_size = 1`**
**What:** start with exactly 1 worker. **Why:** the normal "target" number to run right now. **How:** EKS launches this many at first, between the min and max. **Options:** set higher to start with more capacity.

<details>
<summary>ℹ️ More info: how do min / desired / max work together?</summary>

Think of a thermostat. **Desired** is the temperature you set right now. **Min** and **max** are the limits it's never allowed to go past. If you later turn on autoscaling, the cluster can add or remove workers automatically — but always staying between min and max.

</details>

**Lines 16–17 — `}` `}`**
**What:** closes the `default` group, then the `eks_managed_node_groups` block. **Why & how:** matching braces for the two blocks opened on lines 11 and 10.

**Line 18 — `cluster_addons = {`**
**What:** starts a list of official EKS "add-ons" to install. **Why:** a cluster needs a few core helpers to actually function. **How:** EKS installs and maintains each one for you. **Options:** there are more add-ons (like the EBS storage driver) you can add.

**Line 19 — `coredns = {}`**
**What:** installs CoreDNS. **Why:** it's the cluster's internal phone book — it lets apps find each other by name. **How:** empty `{}` means "use the default settings." **Options:** you can pin a specific add-on version inside the braces.

**Line 20 — `kube-proxy = {}`**
**What:** installs kube-proxy. **Why:** it handles networking rules so traffic reaches the right container. **How:** defaults again via `{}`. **Options:** same — can pin a version.

**Line 21 — `vpc-cni = {}`**
**What:** installs the VPC CNI plugin. **Why:** it gives each container a real address from your VPC so it fits into your network. **How:** defaults via `{}`. **Options:** advanced networking settings can go inside.

<details>
<summary>ℹ️ More info: what are these three add-ons, simply?</summary>

- **CoreDNS** — the cluster's name lookup. "Where is the database service?" → it answers with an address.
- **kube-proxy** — sets up the routing rules so requests land on the right container.
- **VPC CNI** — hands out network addresses to containers from your VPC's pool.

These three are the standard baseline for a working EKS cluster. Docs: [Amazon EKS add-ons](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html).

</details>

**Line 22 — `}`**
**What:** closes the `cluster_addons` block. **Why & how:** matches the brace opened on line 18.

**Lines 23–26 — the `tags` block**
**What:** labels for the cluster's resources. **Why:** same reason as the VPC tags — sorting and cost tracking. **How:** `Key = "Value"` pairs. **Options:** add any tags your team uses.

**Line 27 — `}`**
**What:** closes the EKS module block — the end of the file. **Why & how:** matches the opening brace on line 1.

<details>
<summary>📋 Copy the v21-correct version of the EKS block</summary>

Here's the same block with the three renamed inputs updated for module version 21, so it won't throw "unsupported argument" errors:

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "basic-eks"   # was cluster_name
  kubernetes_version = "1.33"         # was cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  endpoint_public_access = true       # was cluster_endpoint_public_access
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1
    }
  }

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
```

Always confirm the exact current input names on the module's registry page before a real deployment: [EKS module — latest docs](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest).

</details>

---

## 6 · Running it: the four commands

With the file saved and your keys configured, open a terminal **in the folder that holds `main.tf`** and run these in order.

### 1. Initialize

```bash
terraform init
```

**What it does:** downloads the AWS provider and the two modules. **When:** run it once at the start, and again any time you change versions. **Think of it as:** "get all the parts I'm going to need."

### 2. Preview the plan

```bash
terraform plan
```

**What it does:** shows you exactly what Terraform *would* create, change, or destroy — without doing anything yet. **Why it's great:** you catch mistakes before they happen. **Look for:** a summary like `Plan: 50 to add, 0 to change, 0 to destroy.`

### 3. Build it

```bash
terraform apply
```

**What it does:** actually creates everything. It shows the plan again and asks you to type `yes` to confirm. **Heads up:** a cluster can take **10–20 minutes** to finish — that's normal.

> 💡 **Then connect with kubectl.** After it finishes, point your Kubernetes tool at the new cluster:
> ```bash
> aws eks update-kubeconfig --region us-east-1 --name basic-eks
> kubectl get nodes
> ```
> If you see your worker node listed, congratulations — your cluster is live! (Guide: [Connecting kubectl to EKS](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html).)

<details>
<summary>ℹ️ More info: useful extra commands</summary>

- `terraform fmt` — auto-tidies the spacing in your file.
- `terraform validate` — checks for typos and errors without contacting AWS.
- `terraform plan -out=plan.tfplan` — saves the plan so `apply` uses exactly that.
- `terraform show` — displays the current state of what you've built.

Full CLI reference: [Terraform CLI commands](https://developer.hashicorp.com/terraform/cli/commands).

</details>

---

## 7 · Cleaning up (so you don't get charged)

A running EKS cluster costs money every hour — both for the control plane and the worker computers. When you're done experimenting, tear it all down with one command:

```bash
terraform destroy
```

**What it does:** deletes everything this file created, in the right order. It asks you to type `yes` first. Because Terraform remembers what it built, cleanup is one command instead of dozens of manual clicks.

> ⚠️ **Don't skip this while learning.** Forgetting a cluster running overnight is the classic way to get a surprise bill. When you stop for the day, run `terraform destroy`. You can always rebuild with `terraform apply` later — that's the whole point of Infrastructure as Code.

<details>
<summary>ℹ️ More info: roughly what does this cost?</summary>

Two main charges while it runs:

- **EKS control plane** — a flat hourly fee per cluster (it runs whether or not you have apps on it).
- **Worker nodes** — the EC2 hourly price for your `t3.small` machine(s).

We set `enable_nat_gateway = false` earlier specifically to avoid an extra hourly charge. Always check current prices for your region:

- [Amazon EKS pricing](https://aws.amazon.com/eks/pricing/)
- [Amazon EC2 on-demand pricing](https://aws.amazon.com/ec2/pricing/on-demand/)

</details>

---

## 8 · Quick recap

You learned that Terraform turns a text file into real cloud infrastructure. You installed the tools, stored your AWS keys safely, and read a real config line by line: the **terraform** block sets versions, the **provider** block picks a region, the **vpc** module builds a private network, and the **eks** module builds a Kubernetes cluster that plugs into that network. Finally, four commands — `init`, `plan`, `apply`, and `destroy` — build and tear it all down.

---

### Official documentation

- Terraform install — <https://developer.hashicorp.com/terraform/install>
- Terraform CLI commands — <https://developer.hashicorp.com/terraform/cli/commands>
- Version constraints — <https://developer.hashicorp.com/terraform/language/expressions/version-constraints>
- AWS provider — <https://registry.terraform.io/providers/hashicorp/aws/latest>
- AWS provider v6 upgrade guide — <https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/version-6-upgrade>
- VPC module — <https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest>
- EKS module — <https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest>
- AWS CLI install — <https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html>
- AWS credentials file — <https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html>
- EKS version lifecycle — <https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html>
- EKS add-ons — <https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html>
- Connect kubectl to EKS — <https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html>
- EKS pricing — <https://aws.amazon.com/eks/pricing/>