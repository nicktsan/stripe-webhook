{
    "openapi" : "3.0.1",
    "info" : {
      "title" : "Stripe Webhook APIGW SQS",
      "version" : "${apigwVersion}"
    },
    "servers" : [{
      "variables" : {
        "basePath" : {
          "default" : "/default"
        }
      }
    }],
    "paths" : {
      "/webhook" : {
        "post" : {
          "responses" : {
            "200" : {
              "description" : "200 response",
              "content" : {
                "application/json" : {
                  "schema" : {
                    "$ref" : "#/components/schemas/Empty"
                  }
                }
              }
            }
          },
          "x-amazon-apigateway-integration" : {
            "type" : "aws",
            "credentials" : "${APIGWRole}",
            "httpMethod" : "POST",
            "uri" : "arn:aws:apigateway:${region}:sqs:path/${account_id}/${sqsname}",
            "responses" : {
              "default" : {
                "statusCode" : "200"
              }
            },
            "requestParameters" : {
              "integration.request.header.Content-Type" : "'application/x-www-form-urlencoded'"
            },
            "requestTemplates" : {
              "application/json" : "Action=SendMessage&MessageBody=$input.json('$')"
            },
            "passthroughBehavior" : "never"
          }
        }
      }
    },
    "components" : {
      "schemas" : {
        "Empty" : {
          "title" : "Empty Schema",
          "type" : "object"
        }
      }
    }
}