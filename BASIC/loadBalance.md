Good choice — autoscaling is the cost-effective answer because nodes only exist when work needs them. You set a floor and a ceiling, and the cluster adds or removes nodes between those bounds based on demand. When load drops, nodes get removed and you stop paying for them. That's the win.

First, a clear-eyed framing so the steps make sense. There are **two halves** to autoscaling, and people often confuse them:

1. **Pod autoscaling** (HPA) — adds more *copies of your app* when it's busy.
2. **Node autoscaling** — adds more *machines* when there's no room to place those pods.

You asked about nodes, so we're doing #2. But here's the mechanism that ties them together: **node autoscaling is triggered by pods that can't fit.** When a pod has nowhere to schedule (every node is full), the autoscaler sees it stuck in `Pending` and launches a node to make room. When nodes sit underused, it removes them. So the trigger is always "are there homeless pods?"

There are two tools that do node autoscaling on EKS. I'll tell you which to pick, then give you the steps.

## Which tool: Karpenter vs Cluster Autoscaler

| | Cluster Autoscaler | Karpenter |
|---|---|---|
| How it adds nodes | Resizes your existing node group | Launches right-sized nodes on demand |
| Cost efficiency | Good | **Better** — picks cheapest instance that fits |
| Setup complexity | Simpler, fewer moving parts | More powerful, more setup |
| Best for | Learning, simple clusters | Production, varied workloads |

**For your simple, cost-conscious learning cluster, I recommend Cluster Autoscaler.** It works *with* the managed node group you already built, so it's the smaller change. Karpenter is the modern production favorite, but it's more to stand up than you need right now. Steps below are for Cluster Autoscaler.

One honest caveat up front about your `t3.micro` nodes: autoscaling adds *whole machines*, and a `t3.micro` holds only ~4 pods. So scaling here means "a 3rd tiny node appears when pods won't fit on 2." It works and demonstrates the concept perfectly, but each node adds little capacity. The mechanism is identical on bigger nodes — you'd just get more headroom per node.

---

## Step 1 — Let your node group resize

Your node group is currently locked at exactly 2 (`minSize=2, maxSize=2`). The autoscaler can't add nodes if the ceiling is 2. Raise the ceiling so there's room to grow:

```bash
aws eks update-nodegroup-config \
  --cluster-name my-micro-cluster \
  --nodegroup-name micro-nodes \
  --scaling-config minSize=2,maxSize=4,desiredSize=2
```

**What this does:** keeps your floor at 2 (always-on), but allows growth up to 4. `desiredSize=2` is where it starts; the autoscaler adjusts that number between 2 and 4 as needed. **Cost stays the same right now** — you only pay for more when load actually forces a scale-up, and it drops back to 2 when idle. This is the cost-effective heart of it: the ceiling is *permission* to scale, not a commitment to run 4.

## Step 2 — Give the autoscaler permission to change node counts

The autoscaler is software running *inside* your cluster, and it needs AWS permission to add/remove EC2 nodes. We attach a policy to the node role allowing exactly that:

```bash
cat > asg-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeInstanceTypes"
    ],
    "Resource": "*"
  }]
}
EOF

aws iam put-role-policy \
  --role-name eksNodeRole \
  --policy-name ClusterAutoscalerPolicy \
  --policy-document file://asg-policy.json
```

**What this does:** grants the autoscaler the specific abilities to *see* the autoscaling group and *change its size* (`SetDesiredCapacity`) — and nothing more. That's least-privilege again: it can resize nodes but can't, say, touch your databases. The "autoscaling group" is the behind-the-scenes AWS object that your managed node group sits on top of; it's the thing that actually launches and terminates machines.

> Quick honesty note: attaching this to the node role is the *simple* path and fine for learning. The more secure production method is **IRSA** (a dedicated identity for just the autoscaler pod), but it's several extra steps. I'm keeping it simple per your ask; say the word if you want the IRSA version.

## Step 3 — Deploy the Cluster Autoscaler

Now install the autoscaler itself into the cluster. This one command pulls AWS's official manifest:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```

**What this does:** deploys the autoscaler as a pod in your cluster's `kube-system` namespace. "Autodiscover" means it automatically finds your node group by reading AWS tags — no hardcoding names. It now sits there watching for `Pending` pods.

## Step 4 — Tell it which cluster to watch

The manifest is generic; point it at *your* cluster name:

```bash
kubectl -n kube-system set env deployment/cluster-autoscaler \
  CLUSTER_NAME=my-micro-cluster
```

Then add two settings that make it behave well and save money:

```bash
kubectl -n kube-system patch deployment cluster-autoscaler \
  --type='json' -p='[
    {"op":"add","path":"/spec/template/spec/containers/0/command/-","value":"--balance-similar-node-groups"},
    {"op":"add","path":"/spec/template/spec/containers/0/command/-","value":"--scale-down-unneeded-time=2m"}
  ]'
```

**What these do:** `--scale-down-unneeded-time=2m` is the cost lever — it removes a node after just 2 minutes of being underused (default is 10), so you stop paying faster when load drops. `--balance-similar-node-groups` keeps nodes evenly spread across zones.

## Step 5 — Confirm it's running

```bash
# The autoscaler pod should be "Running"
kubectl -n kube-system get pods | grep cluster-autoscaler

# Watch its decisions in real time
kubectl -n kube-system logs -f deployment/cluster-autoscaler
```

The logs are worth watching — you'll literally see it reason "pod X is unschedulable, scaling up" and later "node Y unneeded, scaling down."

## Step 6 — Test that it actually works

Create deliberate demand and watch a node appear. Deploy something that asks for more than your 2 nodes can hold:

```bash
# Deploy 10 pods, each reserving 256Mi — too much for 2x t3.micro
kubectl create deployment scaletest --image=nginx --replicas=10
kubectl set resources deployment scaletest --requests=memory=256Mi

# Watch pods — several go "Pending" (no room)
kubectl get pods -w
```

Within ~30 seconds the autoscaler notices the `Pending` pods and adds a node; within a couple minutes you'll see a 3rd node in `kubectl get nodes`. Then clean up and watch it scale back down:

```bash
kubectl delete deployment scaletest
# After ~2 min, the extra node is removed automatically — back to 2
kubectl get nodes
```

That round-trip — pods stuck → node added → load gone → node removed — *is* autoscaling, and watching it once makes the whole thing click.

---

## How the pieces fit (the mental model)

```
Busy app → pods can't fit → pods go "Pending"
   → autoscaler sees Pending pods → tells AWS "add a node"
   → AWS launches node → pods schedule → app served
   ... load drops → node sits idle 2 min → autoscaler removes it → you stop paying
```

The floor (`minSize=2`) is your always-on baseline; the ceiling (`maxSize=4`) caps both your spend and your scale. Cost-effectiveness comes from three things: you only pay above the floor when genuinely busy, the aggressive 2-minute scale-down returns you to baseline fast, and the ceiling guarantees you can never be surprised by a runaway bill — at most 4 `t3.micro` nodes.

## Cost summary

- **At rest:** same as now — 2 nodes. No added cost for *having* autoscaling.
- **Under load:** up to 4 nodes, billed only while they run.
- **The autoscaler pod itself:** free (it's just a small pod on your existing nodes).
- **Hard cap:** `maxSize=4` is your spending guardrail. Want it cheaper? Set `maxSize=3`.

Two genuine caveats. First, the `t3.micro` reality: because each node is tiny, you may need to scale nodes sooner and the per-node gain is small — the demo works, but real apps want bigger nodes where one scale-up adds meaningful room. Second, I gave you the simple node-role permission method; if this is heading toward production, switch to IRSA for the autoscaler's permissions. Both are deliberate simplifications for cost and clarity, not the production-hardened path.

I'll add HPA (pod scaling), since that's the natural pair — and the part that makes node autoscaling actually *do* something. Let me first explain why you need both, then the steps.

## Why HPA completes the picture

Node autoscaling alone is half a system. Think about it: the autoscaler only adds nodes when pods can't fit. But if your app is locked at 2 replicas, it *never asks for more room* — those 2 pods just get slower under load, and no new nodes appear. Nothing is "Pending," so nothing scales.

**HPA (Horizontal Pod Autoscaler) is the trigger.** It watches how hard your pods are working and adds *copies* when they're busy. Those new copies need somewhere to run → eventually they don't fit → *that's* what wakes the node autoscaler. So the chain is:

```
Traffic rises → pods work harder → HPA adds pod copies
   → copies need room → some go "Pending"
   → Cluster Autoscaler adds a node → copies schedule → traffic handled
   ... traffic drops → HPA removes copies → node goes idle → autoscaler removes node
```

HPA scales the *app*, the node autoscaler scales the *machines*, and they hand off to each other. You built the machine half last message; this is the app half.

## Step 1 — Install the Metrics Server

HPA decides based on CPU/memory usage, but it can't see those numbers without a component called **Metrics Server**. It's the "thermometer" — it reads how much CPU each pod is using and reports it. EKS doesn't include it by default, so install it:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**What this does:** deploys a small pod that continuously measures resource usage across the cluster. HPA reads from it. Without this, HPA has no thermometer and just shows `<unknown>` for usage. Confirm it's working:

```bash
# Wait ~1 min, then this should show CPU/memory per node — proof the thermometer works
kubectl top nodes
```

If `kubectl top nodes` returns numbers, you're good. If it errors, the Metrics Server hasn't finished starting — wait another minute.

## Step 2 — Your app must declare what it needs

HPA scales based on usage *relative to a request*. If a pod requests 100m CPU and uses 80m, that's 80% — HPA can act on that. But a pod with **no CPU request has no baseline**, and HPA can't compute a percentage. So your deployment must set resource requests (the app from the failover message already did this; if yours doesn't, add it):

```bash
# Example: ensure your deployment requests CPU so HPA has a baseline
kubectl set resources deployment web --requests=cpu=100m,memory=64Mi
```

**Why this matters:** the request is the denominator in HPA's math. "Target 50% CPU" only means something if Kubernetes knows what 100% *is* for that pod. No request → HPA can't function.

## Step 3 — Create the HPA

Now the autoscaler for pods. This one command says "keep `web` between 2 and 6 copies, targeting 50% CPU":

```bash
kubectl autoscale deployment web \
  --cpu-percent=50 \
  --min=2 \
  --max=6
```

**What this does, in plain terms:** HPA watches the average CPU across all `web` pods. If it climbs above 50%, HPA adds pods (up to 6). If it drops below, HPA removes them (down to 2). The `--min=2` keeps your baseline always-on; `--max=6` caps both pod count and — indirectly — how many nodes you might need.

**Why 50%?** It's headroom. You scale *before* pods are maxed out, so new copies are ready before users feel slowness. Targeting 90% would mean scaling only when already struggling. 50% is a sane, common starting point.

## Step 4 — Watch it live

```bash
# Shows current CPU % vs target, and current replica count
kubectl get hpa web --watch
```

You'll see columns like `TARGETS: 12%/50%` and `REPLICAS: 2`. When you generate load, watch the TARGETS climb and REPLICAS follow.

## Step 5 — Test the full chain (the satisfying part)

Generate real CPU load and watch *both* autoscalers fire in sequence:

```bash
# Open a load generator that hammers your service
kubectl run loadgen --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://web; done"
```

Now watch three things in separate terminals (or check in turn):

```bash
# 1. HPA adds pods as CPU rises
kubectl get hpa web --watch

# 2. Pods appear; some may go Pending if nodes fill
kubectl get pods --watch

# 3. The node autoscaler adds a node to fit the Pending pods
kubectl get nodes --watch
```

The sequence you'll witness: CPU climbs past 50% → HPA bumps replicas → new pods schedule → on tiny `t3.micro` nodes they fill up fast → a pod goes `Pending` → Cluster Autoscaler adds a node → the pod lands. **That's both systems handing off, exactly as designed.** Then tear down the load and watch it all unwind:

```bash
kubectl delete pod loadgen
# CPU drops → HPA scales pods back to 2 → idle node removed after ~2 min → back to baseline
```

---

## The complete two-layer system

Here's everything from the last two messages as one mental model:

| Layer | Tool | Scales | Triggered by | Bounds |
|---|---|---|---|---|
| **Pods** | HPA | App copies | CPU/memory usage | min=2, max=6 |
| **Nodes** | Cluster Autoscaler | Machines | Pending pods | min=2, max=4 |

```
   Traffic ↑
      │
   [HPA] sees high CPU → adds pod copies (2→6)
      │
   pods need room → some go Pending
      │
   [Cluster Autoscaler] sees Pending → adds node (2→4)
      │
   capacity matches demand
      │
   Traffic ↓ → HPA removes pods → node idle → CA removes node → baseline
```

**Why this is cost-effective:** at rest you run the bare minimum (2 pods, 2 nodes). Capacity only materializes — and only bills — when traffic genuinely demands it, and both layers shrink back fast when it's gone. The two ceilings (6 pods, 4 nodes) are your spending guardrails: you literally cannot exceed them.

## The honest caveats (same theme as before)

1. **`t3.micro` is the weak link.** With ~4 pods per node, you'll hit node scaling quickly and each node adds little. The *behavior* is correct and worth seeing once, but real apps want `t3.small`+ so HPA can add several pods before a node is even needed. On tiny nodes the two layers fire almost together; on proper nodes HPA absorbs most spikes and nodes scale only for big ones — which is the smoother, intended rhythm.

2. **CPU isn't always the right signal.** I used CPU because it's the simplest to demo. Memory-bound or queue-driven apps need different metrics (memory target, or custom metrics via KEDA). Start with CPU, refine later.

3. **Metrics Server on some setups** needs a `--kubelet-insecure-tls` flag to talk to nodes. If `kubectl top nodes` keeps erroring after a few minutes, that's usually why — tell me and I'll give you the patched install.

That's the full picture: HPA scales pods on load, the Cluster Autoscaler scales nodes to fit them, both bounded for cost. Want me to roll all of this — the node autoscaling from last message plus this HPA layer — into the original README as a complete "Autoscaling" section you can keep?