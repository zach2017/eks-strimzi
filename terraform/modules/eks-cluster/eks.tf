resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.cluster.id]
  }

  enabled_cluster_log_types = var.enable_cluster_logging ? ["api", "audit", "authenticator", "controllerManager", "scheduler"] : []

  tags = merge(
    var.tags,
    { "Name" = var.cluster_name }
  )

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_security_group.cluster
  ]
}

resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  instance_types = each.value.instance_types
  disk_size      = each.value.disk_size

  labels = each.value.labels

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(
    var.tags,
    {
      "Name" = "${var.cluster_name}-${each.key}-ng"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_registry_policy
  ]
}

resource "aws_eks_addon" "cni" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "vpc-cni"
  addon_version            = data.aws_eks_addon_version.cni.version
  service_account_role_arn = aws_iam_role.cni.arn
  resolve_conflicts        = "OVERWRITE"

  tags = var.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name      = aws_eks_cluster.main.name
  addon_name        = "coredns"
  addon_version     = data.aws_eks_addon_version.coredns.version
  resolve_conflicts = "OVERWRITE"

  tags = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name      = aws_eks_cluster.main.name
  addon_name        = "kube-proxy"
  addon_version     = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts = "OVERWRITE"

  tags = var.tags
}

# Data sources for addon versions
data "aws_eks_addon_version" "cni" {
  addon_name             = "vpc-cni"
  kubernetes_version     = aws_eks_cluster.main.version
  most_recent            = true
}

data "aws_eks_addon_version" "coredns" {
  addon_name             = "coredns"
  kubernetes_version     = aws_eks_cluster.main.version
  most_recent            = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name             = "kube-proxy"
  kubernetes_version     = aws_eks_cluster.main.version
  most_recent            = true
}

# IAM role for CNI addon
resource "aws_iam_role" "cni" {
  name = "${var.cluster_name}-cni-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = var.enable_irsa ? aws_iam_openid_connect_provider.eks[0].arn : ""
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-node"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.cni.name
}
