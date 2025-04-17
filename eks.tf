  # Node Group Configuration (Add this if missing)
  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 2
      instance_types = ["t3.medium"]
    }
  }

  # Authentication Configuration
  enable_cluster_creator_admin_permissions = true
  access_entries = local.access_entries




  resource "aws_security_group_rule" "otel_collector_ingress" {
  type              = "ingress"
  from_port         = 4317
  to_port           = 4317
  protocol          = "tcp"
  security_group_id = aws_security_group.node_secondary_sg.id
  cidr_blocks       = local.allowed_cidrs
  description       = "Allow OTel Collector traffic"
}
