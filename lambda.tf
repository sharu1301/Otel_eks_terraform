resource "aws_iam_role" "lambda_otel_role" {
  name = "lambda-otel-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda_otel_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_otel_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_security_group" "lambda_sg" {
  name        = "lambda-sg"
  description = "Security group for Lambda accessing OTel Collector"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "lambda-otel-sg"
  })
}

Resource "aws_security_group_rule" "lambda_to_otel" {
  type              = "ingress"
  from_port         = 4317
  to_port           = 4317
  protocol          = "tcp"
  source_security_group_id = aws_security_group.lambda_sg.id
  security_group_id = aws_security_group.node_secondary_sg.id
}

resource "aws_lambda_function" "otel_instrumented_lambda" {
  function_name = "otel-lambda-demo"
  role          = aws_iam_role.lambda_otel_role.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.8"
  filename      = "lambda_function_payload.zip"
  timeout       = 30

  layers = ["arn:aws:lambda:us-east-1:901920570463:layer:aws-otel-python38-ver-1-17-0:1"]

  environment {
    variables = {
      OTEL_EXPORTER_OTLP_ENDPOINT = "http://${kubernetes_service.otel_collector.status[0].load_balancer[0].ingress[0].hostname}:4317"
      OTEL_SERVICE_NAME           = "lambda-service"
    }
  }

  vpc_config {
    subnet_ids = [
      "subnet-00425cfe4a8aad96a", 
      "subnet-055edfbc1b8d65539",
      "subnet-02d319660e5ce170f"
    ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}
