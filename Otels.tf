# ======================================================
# OTel Collector IAM Role and Policies
# ======================================================

# IAM Role for OTel Collector (EKS Service Account)
resource "aws_iam_role" "otel_collector_role" {
  name = local.otel_collector_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = local.otel_oidc_provider_arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${local.otel_oidc_provider_arn}:sub" = "system:serviceaccount:${local.otel_namespace}:${local.otel_serviceaccount}"
        }
      }
    }]
  })

  tags = merge(local.common_tags, {
    Name    = local.otel_collector_role_name
    Purpose = "OTEL Collector IAM Role"
  })
}

# CloudWatch Policy for OTel Collector
resource "aws_iam_policy" "otel_collector_cloudwatch_policy" {
  name        = local.otel_collector_cloudwatch_policy_name
  description = "Grants OTel Collector access to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "logs:PutLogEvents",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups",
        "logs:PutRetentionPolicy"
      ],
      Resource = "*"
    }]
  })

  tags = merge(local.common_tags, {
    Name    = local.otel_collector_cloudwatch_policy_name
    Purpose = "OTEL Collector CloudWatch Access"
  })
}

# Attach CloudWatch Policy to OTel Role
resource "aws_iam_role_policy_attachment" "otel_cw_policy" {
  role       = aws_iam_role.otel_collector_role.name
  policy_arn = aws_iam_policy.otel_collector_cloudwatch_policy.arn
}

# Attach X-Ray Policy (Optional - for tracing)
resource "aws_iam_role_policy_attachment" "otel_xray" {
  role       = aws_iam_role.otel_collector_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# ======================================================
# Kubernetes Resources for OTel Collector
# ======================================================

# Kubernetes Service Account for OTel Collector
resource "kubernetes_service_account" "otel_collector" {
  metadata {
    name      = local.otel_serviceaccount
    namespace = local.otel_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.otel_collector_role.arn
    }
  }
}

# OTel Collector Deployment
resource "kubernetes_deployment" "otel_collector" {
  metadata {
    name      = "otel-collector"
    namespace = local.otel_namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "otel-collector"
      }
    }

    template {
      metadata {
        labels = {
          app = "otel-collector"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.otel_collector.metadata[0].name

        container {
          name  = "otel-collector"
          image = "public.ecr.aws/aws-observability/aws-otel-collector:latest"

          port {
            container_port = 4317  # OTLP gRPC port
          }

          env {
            name  = "AWS_REGION"
            value = "us-east-1"
          }
        }
      }
    }
  }
}

# OTel Collector Service (LoadBalancer)
resource "kubernetes_service" "otel_collector" {
  metadata {
    name      = "otel-collector"
    namespace = local.otel_namespace
  }

  spec {
    selector = {
      app = "otel-collector"
    }

    port {
      protocol    = "TCP"
      port        = 4317
      target_port = 4317
    }

    type = "LoadBalancer"  # Use "ClusterIP" for internal access
  }
}

# ======================================================
# Lambda IAM Role (For Instrumentation)
# ======================================================

# IAM Role for Lambda Function
resource "aws_iam_role" "lambda_otel_role" {
  name = "lambda-otel-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, {
    Name    = "lambda-otel-role"
    Purpose = "Lambda OTel Instrumentation"
  })
}

# Attach X-Ray Policy to Lambda Role
resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda_otel_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Attach Basic Lambda Execution Policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_otel_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
