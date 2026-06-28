aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=micro-nodes" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress]' \
  --output table