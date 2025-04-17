# Add these new variables:
  otel_collector_endpoint                = "http://${kubernetes_service.otel_collector.status[0].load_balancer[0].ingress[0].hostname}:4317"
  allowed_cidrs                          = ["10.0.0.0/16"]  # Adjust to your CIDR ranges
  common_tags = {
    Environment = "dev"
    Project     = "digital-discovery"
  }
}
