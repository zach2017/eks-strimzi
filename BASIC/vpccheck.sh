

export OLD_VPC=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" \
  --query 'Vpcs[0].VpcId' --output text)
echo "Old default VPC: $OLD_VPC"

export VPC_ID=vpc-PUT_YOURS_HERE   # the one that won't delete

echo "=== 1. ENIs — including ones 'in-use' that basic checks hide ==="
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,InterfaceType,Description]' \
  --output table

echo "=== 2. VPC Endpoints (invisible to instance/ENI checks) ==="
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'VpcEndpoints[*].[VpcEndpointId,ServiceName,State]' --output table

echo "=== 3. Classic ELBs (different API from the v2 check earlier!) ==="
aws elb describe-load-balancers \
  --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output table

echo "=== 4. NAT gateways still 'deleting' (not yet 'deleted') ==="
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" \
  --query 'NatGateways[*].[NatGatewayId,State]' --output table

echo "=== 5. VPC Peering connections ==="
aws ec2 describe-vpc-peering-connections \
  --filters "Name=requester-vpc-info.vpc-id,Values=$VPC_ID" \
  --query 'VpcPeeringConnections[*].[VpcPeeringConnectionId,Status.Code]' --output table

echo "=== 6. VPN / Transit gateway attachments ==="
aws ec2 describe-vpn-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --query 'VpnGateways[*].[VpnGatewayId,State]' --output table
  
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$OLD_VPC" \
  --query 'NetworkInterfaces[*].[NetworkInterfaceId,Description]' --output table


aws ec2 describe-instances --filters "Name=vpc-id,Values=$OLD_VPC" \
  "Name=instance-state-name,Values=running,stopped,pending" \
  --query 'Reservations[*].Instances[*].InstanceId' --output table