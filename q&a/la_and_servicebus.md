# Logic Apps and Service Bus

Let's go through following demo integration:

![Logic Apps](https://user-images.githubusercontent.com/2357647/117446661-0f589580-af45-11eb-9437-55e4a7896d25.png)

Above Logic App reads messages from Service Bus queue and uses the incoming message
(in this case just posts it to echo service), and then based on the
success of the processing it either completes the message or abandons the
message from queue. 

In this demo, we'll use [CloudEvents](https://cloudevents.io/) format for sending
our data to the service. Here's example message payload:

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

Our processing starts from [Service Bus trigger](https://docs.microsoft.com/en-us/connectors/servicebus/#when-one-or-more-messages-arrive-in-a-queue-(peek-lock)):

![Service Bus trigger](https://user-images.githubusercontent.com/2357647/117443282-9c4d2000-af40-11eb-8363-07b4185fbb5f.png)

**Important**❗ Please read more detailed information about the Service Bus Connectors [here](https://docs.microsoft.com/en-us/azure/connectors/connectors-create-api-servicebus).

Especially these are important items to understand:

- Long-polling triggers
- Maximum message count setting
- Concurrency settings

Here's example configuration of the above trigger:

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

*Note*: You can use [Run](https://docs.microsoft.com/en-us/rest/api/logic/workflowtriggers/run)
API to invoke the trigger:

```powershell
$subscriptionId = (az account show --query id -o TSV)
$resourceGroup = "rg-servicebus-logicapp"
$logicApp = "la-sb1"
$triggerName = "When_one_or_more_messages_arrive_in_a_queue_(peek-lock)"
$accessToken = ConvertTo-SecureString -AsPlainText -String (az account get-access-token --resource https://management.azure.com --query accessToken -o TSV)
$uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Logic/workflows/$logicApp/triggers/$triggerName/run?api-version=2016-06-01"

Invoke-RestMethod `
    -Body $body `
    -Method "POST" `
    -Authentication Bearer `
    -Token $accessToken `
    -Uri $uri
```

In our demo scenario, our integration is just calling external echo service:

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

**Note**: We add extra header `SB-DeliveryCount` to the echo request,
just to make it easier to analyze the current delivery count of the message.

This is the data posted into the echo service:

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

Next we parse that message content:

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

In order to simulate the message re-processing logic, we'll
abanbon message if we haven't re-processed it as many times we have defined
in the actual payload (in this case in `appinfoB` property):

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

If `appinfoB < DeliveryCount`, then message is completed and removed from the queue.

Otherwise, message will be abandoned and it will be picked up again in by sub-sequent processing.

Example screenshot from echo service with single message
when `appinfoB` has been set to `10` and
Service Bus Queue `max delivery count` is also set to `10`:

![Echo](https://user-images.githubusercontent.com/2357647/117630995-731cd180-b184-11eb-9aea-df6963a51070.gif)

As you can see from above animation, Logic App continues to pick up the message again and again,
and tries to successfully process the integration. There is no delay in starting
the processing after previous processing has failed.

Above scenario means that test message will land into Dead-Letter Queue (DLQ).
Using [Service Bus Explorer](https://github.com/paolosalvatori/ServiceBusExplorer) you can
easily see that and purge or move messages back to your main queues:

![Service Bus Explorer](https://user-images.githubusercontent.com/2357647/117631393-dd357680-b184-11eb-9985-e640656073f5.png)
