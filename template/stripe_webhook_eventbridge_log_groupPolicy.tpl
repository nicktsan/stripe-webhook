{
  "Version": "2012-10-17",
  "Id": "CWLogsPolicy",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [ 
          "events.amazonaws.com",
          "delivery.logs.amazonaws.com"
          ]
      },
      "Action": [
        "logs:CreateLogStream"
        ],
      "Resource": "${logGroup}:*"
    }
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [ 
          "events.amazonaws.com",
          "delivery.logs.amazonaws.com"
          ]
      },
      "Action": [
        "logs:PutLogEvents"
        ],
      "Resource": "${logGroup}:*:*",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${eventRuleArn}"
        }
      }
    }
  ]
}