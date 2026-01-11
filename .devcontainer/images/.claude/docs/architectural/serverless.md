# Serverless Architecture

> Architecture où l'infrastructure est gérée par le cloud provider, facturée à l'usage.

**Aussi appelé :** FaaS (Function as a Service), Event-driven Serverless

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                   SERVERLESS ARCHITECTURE                        │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                      EVENT SOURCES                       │    │
│  │                                                          │    │
│  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐      │    │
│  │  │ HTTP │  │ Queue│  │  S3  │  │ Cron │  │Stream│      │    │
│  │  │  API │  │ SQS  │  │Event │  │      │  │Kinesis│     │    │
│  │  └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘      │    │
│  └─────┼─────────┼────────┼────────┼─────────┼───────────┘    │
│        │         │        │        │         │                  │
│        ▼         ▼        ▼        ▼         ▼                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    FUNCTIONS (Lambda)                    │    │
│  │                                                          │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │    │
│  │  │ getUser  │  │processOrder │ │resizeImage│            │    │
│  │  │          │  │          │  │          │              │    │
│  │  │  Auto-   │  │  Auto-   │  │  Auto-   │              │    │
│  │  │  scale   │  │  scale   │  │  scale   │              │    │
│  │  └──────────┘  └──────────┘  └──────────┘              │    │
│  └─────────────────────────────────────────────────────────┘    │
│        │                   │              │                      │
│        ▼                   ▼              ▼                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    MANAGED SERVICES                      │    │
│  │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐        │    │
│  │  │DynamoDB│  │   S3   │  │  SQS   │  │Cognito │        │    │
│  │  └────────┘  └────────┘  └────────┘  └────────┘        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ❌ No servers to manage    ✅ Pay per invocation               │
│  ❌ No scaling config       ✅ Auto-scale to zero               │
└─────────────────────────────────────────────────────────────────┘
```

## Architecture typique AWS

```
┌─────────────────────────────────────────────────────────────────┐
│                     API + COMPUTE + DATA                         │
│                                                                  │
│  Client                                                          │
│    │                                                             │
│    ▼                                                             │
│  ┌──────────────┐                                               │
│  │ API Gateway  │  (REST/HTTP/WebSocket)                        │
│  └──────┬───────┘                                               │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────┐     ┌──────────────┐                          │
│  │    Lambda    │────▶│   DynamoDB   │                          │
│  │   (handler)  │     │   (NoSQL)    │                          │
│  └──────────────┘     └──────────────┘                          │
│         │                                                        │
│         │ async                                                  │
│         ▼                                                        │
│  ┌──────────────┐     ┌──────────────┐                          │
│  │ EventBridge  │────▶│    Lambda    │                          │
│  │   (events)   │     │  (processor) │                          │
│  └──────────────┘     └──────────────┘                          │
│                              │                                   │
│                              ▼                                   │
│                       ┌──────────────┐                          │
│                       │     SES      │                          │
│                       │   (email)    │                          │
│                       └──────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

## Implémentation AWS Lambda

### Handler basique

```typescript
// handler.ts
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

export const getUser = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  const userId = event.pathParameters?.id;

  if (!userId) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: 'Missing user ID' }),
    };
  }

  try {
    const user = await userService.getById(userId);

    if (!user) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'User not found' }),
      };
    }

    return {
      statusCode: 200,
      body: JSON.stringify(user),
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
};
```

### Event-driven handler

```typescript
// processOrder.ts
import { SQSEvent, SQSRecord } from 'aws-lambda';

export const processOrder = async (event: SQSEvent): Promise<void> => {
  const promises = event.Records.map(async (record: SQSRecord) => {
    const order = JSON.parse(record.body);

    // Process order
    await orderService.process(order);

    // Emit event for other functions
    await eventBridge.putEvents({
      Entries: [{
        Source: 'orders',
        DetailType: 'OrderProcessed',
        Detail: JSON.stringify({ orderId: order.id }),
      }],
    });
  });

  await Promise.all(promises);
};
```

## Infrastructure as Code (SAM)

```yaml
# template.yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Globals:
  Function:
    Runtime: nodejs20.x
    Timeout: 30
    MemorySize: 256
    Environment:
      Variables:
        TABLE_NAME: !Ref UsersTable

Resources:
  # API Gateway
  ApiGateway:
    Type: AWS::Serverless::Api
    Properties:
      StageName: prod
      Cors:
        AllowOrigin: "'*'"

  # Lambda Functions
  GetUserFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: src/handlers/getUser.handler
      Events:
        GetUser:
          Type: Api
          Properties:
            RestApiId: !Ref ApiGateway
            Path: /users/{id}
            Method: GET
      Policies:
        - DynamoDBReadPolicy:
            TableName: !Ref UsersTable

  CreateUserFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: src/handlers/createUser.handler
      Events:
        CreateUser:
          Type: Api
          Properties:
            RestApiId: !Ref ApiGateway
            Path: /users
            Method: POST
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref UsersTable

  # DynamoDB Table
  UsersTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: users
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: id
          AttributeType: S
      KeySchema:
        - AttributeName: id
          KeyType: HASH
```

## Patterns Serverless

### API Pattern

```
Client → API Gateway → Lambda → DynamoDB
```

### Fan-out Pattern

```
                    ┌─── Lambda A → Service A
Event → Lambda ────┼─── Lambda B → Service B
                    └─── Lambda C → Service C
```

### Saga Pattern (Step Functions)

```yaml
# step-functions.yaml
OrderProcessingSaga:
  Type: AWS::Serverless::StateMachine
  Properties:
    Definition:
      StartAt: ReserveInventory
      States:
        ReserveInventory:
          Type: Task
          Resource: !GetAtt ReserveInventoryFunction.Arn
          Next: ProcessPayment
          Catch:
            - ErrorEquals: ["InventoryError"]
              Next: ReleaseInventory

        ProcessPayment:
          Type: Task
          Resource: !GetAtt ProcessPaymentFunction.Arn
          Next: CompleteOrder
          Catch:
            - ErrorEquals: ["PaymentError"]
              Next: ReleaseInventory

        ReleaseInventory:
          Type: Task
          Resource: !GetAtt ReleaseInventoryFunction.Arn
          Next: Fail

        CompleteOrder:
          Type: Task
          Resource: !GetAtt CompleteOrderFunction.Arn
          End: true

        Fail:
          Type: Fail
```

## Quand utiliser

| Utiliser | Eviter |
|----------|--------|
| Trafic variable | Trafic constant élevé |
| APIs simples | Calculs longs (>15min) |
| Event processing | Stateful applications |
| Startups (faible coût initial) | Latence ultra-faible requise |
| Prototypes | Vendor lock-in problématique |

## Avantages

- **No ops** : Pas de serveurs à gérer
- **Auto-scale** : Scale automatique (y compris à 0)
- **Pay-per-use** : Facturation à l'invocation
- **Focus code** : Business logic seulement
- **Haute disponibilité** : Built-in
- **Intégrations** : Écosystème cloud riche

## Inconvénients

- **Cold starts** : Latence au démarrage
- **Timeout** : Limites d'exécution (15min max)
- **Vendor lock-in** : Dépendance au provider
- **Debugging** : Plus complexe
- **Stateless** : État externe requis
- **Coût** : Peut exploser à fort trafic

## Cold Start Mitigation

```typescript
// Provisioned Concurrency (SAM)
Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      AutoPublishAlias: live
      ProvisionedConcurrencyConfig:
        ProvisionedConcurrentExecutions: 10

// SnapStart (Java)
Properties:
  SnapStart:
    ApplyOn: PublishedVersions
```

## Exemples réels

| Entreprise | Usage |
|------------|-------|
| **Netflix** | Data processing |
| **Coca-Cola** | Vending machines IoT |
| **iRobot** | Robot communications |
| **Nordstrom** | E-commerce backend |
| **Financial Times** | Content delivery |

## Migration path

### Vers Serverless

```
Phase 1: Identifier workloads événementiels
Phase 2: Containeriser les fonctions
Phase 3: Déployer sur Lambda/Cloud Functions
Phase 4: Migrer data vers services managés
Phase 5: Implémenter observabilité
```

### Depuis Serverless (scale out)

```
1. Containeriser les Lambdas
2. Déployer sur ECS/EKS
3. Remplacer par Fargate/Kubernetes
```

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Event-Driven | Architecture sous-jacente |
| CQRS | Lecture/Écriture séparées |
| Saga | Transactions distribuées |
| Circuit Breaker | Résilience |

## Sources

- [AWS Lambda](https://aws.amazon.com/lambda/)
- [Serverless Framework](https://www.serverless.com/)
- [AWS SAM](https://aws.amazon.com/serverless/sam/)
- [Martin Fowler - Serverless](https://martinfowler.com/articles/serverless.html)
