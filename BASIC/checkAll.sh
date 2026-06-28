
aws eks list-clusters --query 'clusters' --output text
aws eks list-nodegroups --cluster-name my-micro-cluster 2>/dev/null
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerName' --output text