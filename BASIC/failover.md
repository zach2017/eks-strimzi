Good question, and it's worth being precise about what "failover" means here, because there are **three different layers** that can fail, and they're protected differently. Let me map them out, then give you the commands for the part you actually control.

## The three layers

**1. The control plane** — already failover-protected, free, automatic. AWS runs it across multiple Availability Zones for you. Nothing to configure. When `endpointPublicAccess=true`, that public API endpoint is already load-balanced behind the scenes. This is the one piece you *don't* touch.

**2. Your application pods** — this is where most "one node is down" resilience actually lives. If a node dies, Kubernetes notices and reschedules its pods onto the surviving node. A **load balancer** then spreads incoming traffic across whatever pods are healthy. This is the layer your question is really about.

**3. The nodes themselves** — the managed node group already auto-replaces a dead node (it'll launch a fresh one to get back to your `desiredSize`). But replacement takes a few minutes, which is exactly why layers 1 and 2 matter: they keep you serving during the gap.

## The hard truth about your 2× `t3.micro` setup

Before the commands, the thing I have to flag: **real failover needs your app running on *both* nodes at once.** If node A dies, traffic shifts to the copy on node B — but only if a copy *exists* on node B. That means at least 2 replicas of your app.

On `t3.micro`, each node holds only ~4 pods *total*, and system pods eat most of that. You can *probably* fit a tiny app with 2 replicas (one per node), but you're at the ragged edge. If pods won't schedule, this is why. For anything beyond a demo, `t3.small`+ is the honest answer. With that said, here's how it works.

## Step 1: Run your app with 2 replicas, one per node

Spreading replicas across nodes is what makes failover real. This manifest uses `topologySpreadConstraints` to force one pod per node:

```bash
cat > app.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      # Force the 2 pods onto DIFFERENT nodes so one node dying
      # never takes out both copies at once
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: web
      containers:
        - name: web
          image: nginx:alpine
          ports:
            - containerPort: 80
          # Health check: if a pod stops answering, the LB stops
          # sending it traffic and Kubernetes restarts it
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 3
            periodSeconds: 5
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
EOF

kubectl apply -f app.yaml
```

The `topologySpreadConstraints` block is the failover backbone — `topologyKey: kubernetes.io/hostname` means "spread across hostnames (nodes)," and `maxSkew: 1` means the two nodes can differ by at most one pod, so you get one on each. The `readinessProbe` is what lets the load balancer know which pods are actually healthy.

## Step 2: Add the load balancer

You have two routes. **Route A is what I'd recommend for your learning setup** because it needs nothing extra installed.

### Route A — Service of type LoadBalancer (simple, works today)

```bash
cat > lb.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web-lb
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
EOF

kubectl apply -f lb.yaml
```

This tells EKS to provision an AWS **Classic Load Balancer** automatically and point it at your healthy `web` pods. Get its public address:

```bash
# Wait ~2 min, then this prints the LB's public DNS name
kubectl get service web-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo
```

Hit that URL in a browser. **To test failover:** delete a pod (`kubectl delete pod <name>`) or even stop a whole EC2 node — the LB keeps serving from the surviving pod while Kubernetes rebuilds the rest. That's your failover, working.

### Route B — AWS Load Balancer Controller (production-grade)

This installs an add-on that gives you real **Application Load Balancers** (ALBs) with smarter routing, host/path rules, and lower cost per service. It's the modern best practice — but it's genuinely more involved: you install an IAM policy, create an IRSA service account, and deploy the controller via Helm. It's overkill for a 2-node `t3.micro` demo, so I won't dump 40 lines here unless you want it. Say the word and I'll lay it out step by step.

## What actually happens when a node dies (the full picture)

1. **0–10 sec:** The load balancer's health check fails for pods on the dead node. It stops routing there. *Users still being served by the surviving node's pod — no outage.*
2. **~40 sec–5 min:** Kubernetes marks the node `NotReady` and reschedules its pods onto the healthy node (if there's room — the `t3.micro` constraint again).
3. **~3–5 min:** The managed node group launches a replacement node to restore your count of 2. New pods spread back out.

The load balancer + 2 spread replicas is what carries you through steps 2 and 3 without downtime. That's the whole game.

---

One caveat on cost and honesty: a `LoadBalancer` service spins up a real AWS load balancer that bills hourly (~$18/mo for a CLB) on top of your existing cluster charges — delete it (`kubectl delete -f lb.yaml`) when you're done testing. And I'll repeat the `t3.micro` warning one last time: if `kubectl get pods` shows pods stuck in `Pending`, it's almost certainly the pod-per-node cap, and the fix is bigger instances, not more config.

Want Route B (the ALB controller), or want me to bundle Steps 1–2 into the README from earlier?