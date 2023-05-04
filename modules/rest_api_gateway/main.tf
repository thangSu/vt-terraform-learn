# Define the API Gateway
resource "aws_api_gateway_rest_api" "students" {
  name = var.name_api
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  }
resource "aws_api_gateway_resource" "create_api_resource" {
  count       = length(var.endpoint_path)
  parent_id   = aws_api_gateway_rest_api.students.root_resource_id
  path_part   = var.endpoint_path[count.index]
  rest_api_id = aws_api_gateway_rest_api.students.id
}

#tạo phương thức GET, DELETE, UPDATE, POST
resource "aws_api_gateway_method" "student_method" {
  count         = length(var.endpoint_path)
  authorization = "NONE"
  rest_api_id   = aws_api_gateway_rest_api.students.id
  resource_id   = aws_api_gateway_resource.create_api_resource[count.index].id
  http_method   = "${var.api_method[count.index]}"
}
resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.students.id
  stage_name    = var.example
}
//fix lại
resource "aws_api_gateway_integration" "integration" {
  count                   = length(var.api_method)
  resource_id             = aws_api_gateway_resource.create_api_resource[count.index].id
  rest_api_id             = aws_api_gateway_rest_api.students.id // b1: cần trỏ đến api gw mà ta vừa tạo
  uri                     = aws_lambda_function.lambda[count.index].invoke_arn
  type                    = "AWS_PROXY"
  http_method             = aws_api_gateway_method.student_method[count.index].http_method
  integration_http_method = "POST"
  //http_method is the method to use when calling the API Gateway endpoint
  //integration_http_method is the method used by API Gateway to call the backend, i.e. Lambda in this case (it should always be POST for Lambda)
}

resource "aws_api_gateway_method_response" "response_200" {
  count = length(var.endpoint_path)
  rest_api_id = aws_api_gateway_rest_api.students.id
  resource_id = aws_api_gateway_resource.create_api_resource[count.index].id
  http_method = aws_api_gateway_method.student_method[count.index].http_method
  status_code = "200"
  response_models  ={
    "application/json" = "Empty"
  }
}



resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.students.id

  triggers = {
    // nếu body có gì thay đổi thì nó sẽ redeploy lại api
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.students.body))
  }

  depends_on = [
    # aws_api_gateway_method.student_method,
    # aws_api_gateway_integration.integration,
    aws_api_gateway_resource.create_api_resource
  ]
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_lambda_permission" "apigw_invoke_lambda" {
  count         = length(var.lambda_name_function)
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda[count.index].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = format("%s*/%s/%s",aws_api_gateway_deployment.deployment.execution_arn, var.api_method[count.index], var.endpoint_path[count.index])
}


# output API Gateway endpoint
output "endpoint" {
  value = aws_api_gateway_deployment.deployment.invoke_url
}