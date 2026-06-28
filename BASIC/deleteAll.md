Here's the complete teardown, in order. Order matters: you delete from the **outside in** — workloads first, then nodes, then the cluster, then the leftover IAM and network bits. You can't delete a cluster while a node group still belongs to it, and you can't delete an IAM role while policies are still attached.

## Step 1 — (Optional) Remove the autoscaling/test stuff you added

If you stood up the autoscaler, HPA, or test deployments, clean those first. Skip any you didn't create:

```bash
# Remove test workloads and HPA
kubectl delete deployment web scaletest scaletest 2>/dev/null
kubectl delete hpa web 2>/dev/null
kubectl delete pod loadgen 2>/dev/null

# Remove the cluster autoscaler and metrics server
kubectl delete -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml 2>/dev/null
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml 2>/dev/null
```

## Step 2 — Delete any LoadBalancer services FIRST (important)

If you created a `type: LoadBalancer` service (or NLB), delete it through `kubectl` **before** deleting the cluster. Otherwise the AWS load balancer it created gets orphaned — it keeps running and billing with nothing managing it:

```bash
# Deletes the service AND the AWS load balancer it provisioned
kubectl delete service web-lb 2>/dev/null

# If you made a standalone NLB via the CLI (the SSH bastion), delete it too:
# aws elbv2 delete-load-balancer --load-balancer-arn $NLB_ARN
# aws elbv2 delete-target-group --target-group-arn $TG_ARN
```

This is the #1 source of surprise charges after a teardown — kill LB services through Kubernetes so it cleans up the AWS side for you.

## Step 3 — Delete the node group (the nodes)

There's no separate "delete nodes" command — **deleting the node group deletes its nodes.** The 2 EC2 machines are torn down as part of this:

```bash
aws eks delete-nodegroup \
  --cluster-name my-micro-cluster \
  --nodegroup-name micro-nodes
```

This takes a few minutes. **Wait for it to fully finish before Step 4** — the cluster won't delete while the node group exists. Watch it:

```bash
# Wait until this command errors with "ResourceNotFoundException" = fully deleted
aws eks describe-nodegroup \
  --cluster-name my-micro-cluster \
  --nodegroup-name micro-nodes \
  --query 'nodegroup.status' --output text

# Or block until done automatically:
aws eks wait nodegroup-deleted \
  --cluster-name my-micro-cluster \
  --nodegroup-name micro-nodes
```

The `wait` command just sits there and returns when deletion is complete — convenient so you don't have to keep checking.

## Step 4 — Delete the cluster (the control plane)

Once the node group is gone, delete the cluster itself. **This is what stops the ~$0.10/hour control plane charge:**

```bash
aws eks delete-cluster --name my-micro-cluster

# Optional: block until fully gone
aws eks wait cluster-deleted --name my-micro-cluster
```

## Step 5 — Clean up the IAM roles

Roles need their policies **detached** before the role can be deleted. Node role first:

```bash
# Detach the three managed policies + the autoscaler inline policy
aws iam detach-role-policy --role-name eksNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam detach-role-policy --role-name eksNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam detach-role-policy --role-name eksNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
aws iam detach-role-policy --role-name eksNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore 2>/dev/null

# Remove the inline autoscaler policy (if you added it)
aws iam delete-role-policy --role-name eksNodeRole --policy-name ClusterAutoscalerPolicy 2>/dev/null

# Now the node role can be deleted
aws iam delete-role --role-name eksNodeRole
```

Then the cluster role:

```bash
aws iam detach-role-policy --role-name eksClusterRole --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
aws iam delete-role --role-name eksClusterRole
```

## Step 6 — Clean up network and SSH leftovers

These don't cost much (or anything) but leave your account tidy:

```bash
# Delete the SSH key pair
aws ec2 delete-key-pair --key-name eks-ssh-key

# Delete the local private key file
rm -f eks-ssh-key.pem

# If you allocated an Elastic IP or NAT gateway, release them — these DO bill:
# aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID
# aws ec2 release-address --allocation-id $EIP_ALLOC
```

The NAT gateway and Elastic IP lines are commented because you may not have created them — but **if you did, release them**, since a NAT gateway bills ~$32/mo and an unattached Elastic IP also incurs a small charge.

---

## The order, and why

| Step | Delete | Why this order |
|---|---|---|
| 1–2 | Workloads + LB services | LB services must go via kubectl or the AWS LB orphans and keeps billing |
| 3 | Node group | Deletes the nodes; must finish before the cluster |
| 4 | Cluster | Can't delete while node group exists; **stops the hourly charge** |
| 5 | IAM roles | Detach policies before deleting each role |
| 6 | Key pair, NAT, EIP | Final tidy-up of billable/leftover bits |

## Verify nothing lingers (and nothing keeps billing)

```bash
# All three should return empty or "not found"
aws eks list-clusters --query 'clusters' --output text
aws eks list-nodegroups --cluster-name my-micro-cluster 2>/dev/null
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerName' --output text
```

If those come back empty, you're fully torn down and the charges have stopped.

Two honest reminders: the **control plane charge only stops at Step 4**, so don't stop halfway and assume you're done — a deleted node group with a live cluster still bills. And **double-check the LoadBalancer cleanup in Step 2** — orphaned load balancers are the most common "why am I still being charged?" culprit after people think they've deleted everything. A quick look at the EC2 → Load Balancers console page confirms none survived.