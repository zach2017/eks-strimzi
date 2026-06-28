Quick but important caution before any commands: **if you used the default VPC (which the original guide did), do not delete those subnets.** They're the account's default networking that lots of other things rely on, and deleting them causes more problems than it solves. So the first real question is *which* subnets you mean.

There are two very different situations:

## Situation A — You used the default VPC (most likely, per the guide)

Then you have **nothing to clean up.** EKS didn't *create* any subnets — it borrowed the existing default ones. Deleting EKS (which you just did) leaves those subnets exactly as they were, available for anything else. Leaving them costs **$0** — subnets themselves are free; only things *inside* them (NAT gateways, load balancers, running instances) bill. So in this case the honest answer is: don't delete anything, you're already clean.

Confirm this is your situation:

```bash
# Were your cluster's subnets in the DEFAULT VPC?
aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" \
  --query 'Vpcs[0].VpcId' --output text
```

If that VPC ID matches the one your cluster used, **stop here** — leave the subnets alone.

## Situation B — You created a dedicated VPC for this cluster

If you went off-script and built a custom VPC (e.g. via `eksctl` or `create-default-vpc` you no longer want), then the clean move is to **delete the whole VPC**, not pick off subnets one by one. Here's why that matters: AWS *won't let you* delete a subnet while anything still uses it (leftover ENIs, security groups, gateways), and it won't let you delete the VPC until its contents are gone. So there's an order.

**First, find what's actually in the VPC:**

```bash
export VPC_ID=vpc-PUT_YOURS_HERE

# List the subnets you're considering deleting
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' --output table

# CRITICAL: check for leftover network interfaces (ENIs).
# EKS/load balancers leave these behind and they BLOCK subnet deletion.
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,Description]' --output table
```

If that second command shows ENIs, **that's why a subnet delete would fail** — something still lives there. Usually it's an orphaned load balancer or NAT gateway. Delete *those* first (the LB/NAT cleanup from the teardown message), and the ENIs disappear with them.

**Then delete the subnets:**

```bash
# Delete each subnet by ID (repeat per subnet, or loop):
for SUBNET in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].SubnetId' --output text); do
    echo "Deleting $SUBNET..."
    aws ec2 delete-subnet --subnet-id $SUBNET
done
```

If any fail with "DependencyViolation," something is still using that subnet — go back and find it with the ENI command above.

**Honestly, though — delete the whole VPC instead.** Picking off subnets leaves the VPC, route tables, internet gateway, and security groups behind. If the VPC was *only* for this cluster, tear the whole thing down. The clean teardown order for a dedicated VPC is:

```bash
# 1. NAT gateways (these BILL — do first)
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" \
  --query 'NatGateways[*].NatGatewayId' --output text
# aws ec2 delete-nat-gateway --nat-gateway-id <ID>   (wait for it to finish)

# 2. Detach + delete the internet gateway
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --query 'InternetGateways[*].InternetGatewayId' --output text
# aws ec2 detach-internet-gateway --internet-gateway-id <IGW> --vpc-id $VPC_ID
# aws ec2 delete-internet-gateway --internet-gateway-id <IGW>

# 3. Delete subnets (the loop above)

# 4. Finally, delete the VPC itself
# aws ec2 delete-vpc --vpc-id $VPC_ID
```

I left the destructive lines commented so you don't run them by accident — uncomment as you confirm each one.

---

## Which situation are you in?

| You used... | Do this |
|---|---|
| **Default VPC** (the original guide) | **Nothing** — leave subnets, they're free and shared. Deleting them risks breaking other things. |
| **A dedicated VPC** just for this cluster | Clear NAT/LB/ENIs → delete subnets → delete the whole VPC |

My genuine recommendation: run the `isDefault` check at the top first. If your cluster used the default VPC — which it did if you followed the original guide — the right answer is **don't delete the subnets at all**. They cost nothing, and they're the networking other AWS resources fall back on. The only time subnet cleanup is worth doing is when you built a throwaway VPC specifically for this, in which case deleting the entire VPC (not individual subnets) is the clean move.

Do you know whether your cluster used the default VPC or a custom one? If you paste the output of the `isDefault` check plus the VPC ID your cluster used, I'll tell you definitively whether there's anything to clean up.