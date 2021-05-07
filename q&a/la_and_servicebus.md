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
