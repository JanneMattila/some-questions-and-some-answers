# Logic Apps and Service Bus

Example message payload:

```json
{
  "type": "ERP.Sales.Order.Created",     
  "specversion": "1.0",
  "source": "/mycontext",
  "subject": null,
  "id": "C1234-1234-1234",
  "datacontenttype": "application/json", 
  "time": "2021-05-07T10:15:51.1165304Z",
  "data": {
    "appinfoC": true,
    "appinfoA": "abc",
    "appinfoB": 1
  }
}
```

![Service Bus trigger](https://user-images.githubusercontent.com/2357647/117443282-9c4d2000-af40-11eb-8363-07b4185fbb5f.png)

```json
{
  "inputs": {
    "host": {
      "connection": {
        "name": "@parameters('$connections')['servicebus']['connectionId']"
      }
    },
    "method": "get",
    "path": "/@{encodeURIComponent(encodeURIComponent(parameters('queueName')))}/messages/batch/head/peek",
    "queries": {
      "maxMessageCount": 20,
      "queueType": "Main"
    }
  },
  "recurrence": {
    "frequency": "Minute",
    "interval": 1
  },
  "splitOn": "@triggerBody()"
}
```

![Post message echo service](https://user-images.githubusercontent.com/2357647/117443515-e930f680-af40-11eb-97ec-f5a3b880d812.png)

```json
{
  "inputs": {
    "method": "POST",
    "uri": "https://echo-service-of-your-choice/api/echo",
    "headers": {
      "SB-DeliveryCount": "@{triggerBody()['Properties']['DeliveryCount']}"
    },
    "body": "@triggerBody()"
  },
  "operationOptions": "SuppressWorkflowHeaders"
}
```

```json
{
  "ContentData": "ew0KICAidHlwZSI6ICJFUlAuU2FsZXMuT3JkZXIuQ3JlYXRlZCIsDQogICJzcGVjdmVyc2lvbiI6ICIxLjAiLA0KICAic291cmNlIjogIi9teWNvbnRleHQiLA0KICAic3ViamVjdCI6IG51bGwsDQogICJpZCI6ICJDMTIzNC0xMjM0LTEyMzQiLA0KICAiZGF0YWNvbnRlbnR0eXBlIjogImFwcGxpY2F0aW9uL2pzb24iLA0KICAidGltZSI6ICIyMDIxLTA1LTA3VDEwOjE1OjUxLjExNjUzMDRaIiwNCiAgImRhdGEiOiB7DQogICAgImFwcGluZm9DIjogdHJ1ZSwNCiAgICAiYXBwaW5mb0EiOiAiYWJjIiwNCiAgICAiYXBwaW5mb0IiOiAxDQogIH0NCn0=",
  "ContentType": "application/atom+xml; type=entry; charset=utf-8",
  "ContentTransferEncoding": "Base64",
  "Properties": {
    "DeliveryCount": "2",
    "EnqueuedSequenceNumber": "0",
    "EnqueuedTimeUtc": "2021-05-07T11:39:35Z",
    "ExpiresAtUtc": "2021-05-08T11:39:35Z",
    "LockedUntilUtc": "2021-05-07T11:40:50Z",
    "LockToken": "a0d68bc0-6df2-4780-a2f1-0ab37369b7ae",
    "MessageId": "5a0eca6c8f2349e0a2f8d756249e3d92",
    "ScheduledEnqueueTimeUtc": "0001-01-01T00:00:00Z",
    "SequenceNumber": "242",
    "Size": "496",
    "State": "Active",
    "TimeToLive": "864000000000"
  },
  "MessageId": "5a0eca6c8f2349e0a2f8d756249e3d92",
  "To": null,
  "ReplyTo": null,
  "ReplyToSessionId": null,
  "Label": null,
  "ScheduledEnqueueTimeUtc": "0001-01-01T00:00:00Z",
  "SessionId": null,
  "CorrelationId": null,
  "SequenceNumber": 242,
  "LockToken": "a0d68bc0-6df2-4780-a2f1-0ab37369b7ae",
  "TimeToLive": "864000000000"
}
```

![Parse message content](https://user-images.githubusercontent.com/2357647/117443653-24cbc080-af41-11eb-8d2c-dca61d6629fc.png)

```json
{
  "inputs": {
    "content": "@base64ToString(triggerBody()?['ContentData'])",
    "schema": {
      "properties": {
        "data": {
          "properties": {
              "appinfoA": {
                "type": "string"
              },
              "appinfoB": {
                "type": "integer"
              },
              "appinfoC": {
                "type": "boolean"
              }
            },
          "type": "object"
        },
        "datacontenttype": {
          "type": "string"
        },
        "id": {
          "type": "string"
        },
        "source": {
          "type": "string"
        },
        "specversion": {
          "type": "string"
        },
        "subject": {},
        "time": {
          "type": "string"
        },
        "type": {
          "type": "string"
        }
      },
      "type": "object"
    }
  }
}
```

![Has message been processed successfully](https://user-images.githubusercontent.com/2357647/117443822-5775b900-af41-11eb-8d2f-d93cc51318dc.png)

```json
{
  "actions": {
    "Complete_the_message_in_a_queue": {
      "inputs": {
        "host": {
          "connection": {
            "name": "@parameters('$connections')['servicebus']['connectionId']"
          }
        },
        "method": "delete",
        "path": "/@{encodeURIComponent(encodeURIComponent(parameters('queueName')))}/messages/complete",
        "queries": {
          "lockToken": "@triggerBody()?['LockToken']",
          "queueType": "Main",
          "sessionId": ""
        }
      },
      "runAfter": {},
      "type": "ApiConnection"
    }
  },
  "else": {
    "actions": {
      "Abandon_the_message_in_a_queue": {
        "inputs": {
          "host": {
            "connection": {
              "name": "@parameters('$connections')['servicebus']['connectionId']"
            }
          },
          "method": "post",
          "path": "/@{encodeURIComponent(encodeURIComponent(parameters('queueName')))}/messages/abandon",
          "queries": {
            "lockToken": "@triggerBody()?['LockToken']",
            "queueType": "Main",
            "sessionId": ""
          }
        },
        "runAfter": {},
        "type": "ApiConnection"
      }
    }
  },
  "expression": {
    "and": [
      {
        "less": [
          "@int(body('Parse_message_content_as_CloudEvents_message')?['data']['appinfoB'])",
          "@int(triggerBody()?['Properties']['DeliveryCount'])"
        ]
      }
    ]
  }
}
```
