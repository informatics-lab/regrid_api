resource "aws_api_gateway_rest_api" "api" {
# API Gateway
  name = "erdc_api"
}


# All the 'depends on' and 'sleeps' are trying to work around this errors caused by deploying before things
# are fully created. Sometimes this is a terraform error but often it's a API Gateway error once deployed.
# Timings can almost certainly be teaked, or maybe even got rid off....


resource "aws_api_gateway_method" "post" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  http_method   = "POST"
  authorization = "NONE"
  provisioner "local-exec" { 
    command = "sleep 30"
  }
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_rest_api.api.root_resource_id}"
  http_method             = "${aws_api_gateway_method.post.http_method}"
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.erdic_api.arn}/invocations"
  provisioner "local-exec" { 
    command = "sleep 30"
  }
}


resource "aws_api_gateway_method_response" "200" {
  depends_on = ["aws_api_gateway_integration.integration"]
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
  http_method = "${aws_api_gateway_method.post.http_method}"
  status_code = "200"
  provisioner "local-exec" { 
    command = "sleep 10"
  }
}



resource "aws_api_gateway_integration_response" "integrationResponse" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
  http_method = "${aws_api_gateway_method.post.http_method}"
  status_code = "${aws_api_gateway_method_response.200.status_code}"
  provisioner "local-exec" { 
    command = "sleep 30"
  }
}



resource "aws_api_gateway_deployment" "deployment" {
  depends_on = ["aws_api_gateway_method.post", 
                "aws_api_gateway_integration.integration",
                 "aws_api_gateway_integration_response.integrationResponse",
                  "aws_api_gateway_method_response.200" ]
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name  = "test"
  stage_description = "${timestamp()}" // forces to 'create' a new deployment each run
  description = "Deployed at ${timestamp()}" // just some comment field which can be seen in deployment history

}


# Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.erdic_api.arn}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${var.accountId}:${aws_api_gateway_rest_api.api.id}/*/${aws_api_gateway_method.post.http_method}/"
}

resource "aws_lambda_function" "erdic_api" {
  filename         = "${var.lambda_zip}"
  function_name    = "erdic_api"
  role             = "${var.iam_role["arn"]}"
  handler          = "api.aws_lambda_handeler"
  source_code_hash = "${base64sha256(file("${var.lambda_zip}"))}"
  runtime          = "python3.6"

  environment {
    variables = {
      QUEUE_NAME = "${var.queue_name}"
      BUCKET_NAME = "${var.bucket}"
    }
  }
}