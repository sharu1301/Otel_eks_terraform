from opentelemetry import trace
from opentelemetry.instrumentation.aws_lambda import AwsLambdaInstrumentor

AwsLambdaInstrumentor().instrument()

def handler(event, context):
    tracer = trace.get_tracer(__name__)
    with tracer.start_as_current_span("lambda-handler"):
        return {"statusCode": 200, "body": "Hello, OTel!"}
