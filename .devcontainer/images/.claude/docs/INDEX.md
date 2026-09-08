# Knowledge base index

Generated 2026-09-08 · 155 documents · 134 fresh, 21 stale, 0 expired.

`status` is `verified` age against the category TTL. **stale** and **expired** documents are hypotheses, not validated sources: `/search` must confirm them against the web before citing them, and `/search --refresh <topic>` restamps them.

## architectural (9)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`cqrs`](architectural/cqrs.md) | Separate read and write models. | 2026-02-14 | fresh |
| [`event-driven`](architectural/event-driven.md) | Architecture where components communicate via asynchronous events. | 2026-02-14 | fresh |
| [`event-sourcing`](architectural/event-sourcing.md) | Persist state as a sequence of events instead of a snapshot. | 2026-02-14 | fresh |
| [`hexagonal`](architectural/hexagonal.md) | Isolate the business core from technical details. | 2026-02-14 | fresh |
| [`layered`](architectural/layered.md) | Organize code into horizontal layers with distinct responsibilities. | 2026-02-14 | fresh |
| [`microservices`](architectural/microservices.md) | Decompose an application into independent, separately deployable services. | 2026-02-14 | fresh |
| [`modular-monolith`](architectural/modular-monolith.md) | A monolith structured into independent modules with clear boundaries. | 2026-02-14 | fresh |
| [`monolith`](architectural/monolith.md) | A single application containing all the business logic. | 2026-02-14 | fresh |
| [`serverless`](architectural/serverless.md) | Architecture where infrastructure is managed by the cloud provider, billed per usage. | 2026-02-14 | fresh |

## behavioral (11)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`chain-of-responsibility`](behavioral/chain-of-responsibility.md) | Pass a request along a chain of handlers. | 2026-02-14 | fresh |
| [`command`](behavioral/command.md) | Encapsulate a request as an object to parameterize, log, or undo. | 2026-02-14 | fresh |
| [`interpreter`](behavioral/interpreter.md) | Define a grammar and an interpreter to evaluate expressions. | 2026-02-14 | fresh |
| [`iterator`](behavioral/iterator.md) | Access elements of a collection without exposing its internal structure. | 2026-02-14 | fresh |
| [`mediator`](behavioral/mediator.md) | Encapsulate interactions between objects for loose coupling. | 2026-02-14 | fresh |
| [`memento`](behavioral/memento.md) | Capture and externalize an object's internal state to be able to restore it later. | 2026-02-14 | fresh |
| [`observer`](behavioral/observer.md) | Define a one-to-many dependency between objects to notify changes. | 2026-02-14 | fresh |
| [`state`](behavioral/state.md) | Allow an object to change its behavior when its state changes. | 2026-02-14 | fresh |
| [`strategy`](behavioral/strategy.md) | Define a family of interchangeable algorithms. | 2026-02-14 | fresh |
| [`template-method`](behavioral/template-method.md) | Define the skeleton of an algorithm, delegating steps to subclasses. | 2026-02-14 | fresh |
| [`visitor`](behavioral/visitor.md) | Separate an algorithm from objects, allowing new operations to be added. | 2026-02-14 | fresh |

## cloud (21)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`ambassador`](cloud/ambassador.md) | Create proxy services to manage communications between clients and services. | 2026-02-14 | fresh |
| [`cache-aside`](cloud/cache-aside.md) | Load data into the cache on demand from the data store. | 2026-02-14 | fresh |
| [`circuit-breaker`](cloud/circuit-breaker.md) | Prevent cascade failures in distributed systems. | 2026-02-14 | fresh |
| [`claim-check`](cloud/claim-check.md) | Separate the message from its large payload via a reference. | 2026-02-14 | fresh |
| [`compensating-transaction`](cloud/compensating-transaction.md) | Undo the effects of already-executed operations in a distributed workflow. | 2026-02-14 | fresh |
| [`compute-resource-consolidation`](cloud/compute-resource-consolidation.md) | Optimize resource utilization by consolidating workloads. | 2026-02-14 | fresh |
| [`external-configuration`](cloud/external-configuration.md) | Externalize configuration outside of deployed code. | 2026-02-14 | fresh |
| [`gateway-aggregation`](cloud/gateway-aggregation.md) | Aggregate multiple backend requests into a single client request. | 2026-02-14 | fresh |
| [`gateway-offloading`](cloud/gateway-offloading.md) | Offload shared functionality from services to the gateway. | 2026-02-14 | fresh |
| [`gateway-routing`](cloud/gateway-routing.md) | Route requests to the appropriate backend services. | 2026-02-14 | fresh |
| [`geode`](cloud/geode.md) | Deploy identical units across multiple geographic regions. | 2026-02-14 | fresh |
| [`leader-election`](cloud/leader-election.md) | Coordinate actions by electing a leader among distributed instances. | 2026-02-14 | fresh |
| [`materialized-view`](cloud/materialized-view.md) | Pre-compute and store optimized views for frequent queries. | 2026-02-14 | fresh |
| [`priority-queue`](cloud/priority-queue.md) | Process messages according to their priority rather than their arrival order. | 2026-02-14 | fresh |
| [`queue-load-leveling`](cloud/queue-load-leveling.md) | Use a queue as a buffer to smooth out traffic spikes. | 2026-02-14 | fresh |
| [`saga`](cloud/saga.md) | Manage distributed transactions without 2PC. | 2026-02-14 | fresh |
| [`scheduler-agent-supervisor`](cloud/scheduler-agent-supervisor.md) | Coordinate distributed tasks with a centralized supervisor. | 2026-02-14 | fresh |
| [`sharding`](cloud/sharding.md) | Horizontally partition data for scalability and performance. | 2026-02-14 | fresh |
| [`static-content-hosting`](cloud/static-content-hosting.md) | Serve static assets from a CDN or dedicated storage for performance and scalability. | 2026-02-14 | fresh |
| [`strangler-fig`](cloud/strangler-fig.md) | Progressively migrate a legacy system by replacing it incrementally. | 2026-02-14 | fresh |
| [`valet-key`](cloud/valet-key.md) | Provide a temporary token for direct access to resources without going through the applica | 2026-02-14 | fresh |

## concurrency (8)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`actor-model`](concurrency/actor-model.md) | Each actor is an independent unit with its own private state, processing messages sequenti | 2026-02-14 | fresh |
| [`copy-on-write`](concurrency/copy-on-write.md) | Lazy copy strategy: share data for reads, copy only on write. | 2026-02-14 | fresh |
| [`future-promise`](concurrency/future-promise.md) | Placeholder for an asynchronous result, enabling operation composition. | 2026-02-14 | fresh |
| [`mutex-semaphore`](concurrency/mutex-semaphore.md) | Ensures that only one task can access a resource at a time. | 2026-02-14 | fresh |
| [`pipeline`](concurrency/pipeline.md) | Chain of processing stages where each stage transforms data for the next. | 2026-02-14 | fresh |
| [`producer-consumer`](concurrency/producer-consumer.md) | Decouple producers from consumers with an intermediate queue. | 2026-02-14 | fresh |
| [`read-write-lock`](concurrency/read-write-lock.md) | Optimizes concurrent access by allowing parallel reads while guaranteeing exclusive writes | 2026-02-14 | fresh |
| [`thread-pool`](concurrency/thread-pool.md) | Maintain a set of pre-created workers to process tasks without creation overhead. | 2026-02-14 | fresh |

## conventions (1)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`dto-tags`](conventions/dto-tags.md) | `dto:` tag for grouping DTO structs in the same file (exception to KTN-STRUCT-ONEFILE). | 2026-02-14 | fresh |

## creational (4)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`builder`](creational/builder.md) | Build complex objects step by step with a fluent interface. | 2026-02-14 | fresh |
| [`factory`](creational/factory.md) | Delegate object creation to specialized methods or classes. | 2026-02-14 | fresh |
| [`prototype`](creational/prototype.md) | Create new objects by cloning an existing instance rather than instantiating it. | 2026-02-14 | fresh |
| [`singleton`](creational/singleton.md) | Guarantee a unique instance of a class with a global access point. | 2026-02-14 | fresh |

## ddd (8)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`aggregate`](ddd/aggregate.md) | Cluster of domain objects treated as a unit for data modifications, with a root Entity tha | 2026-02-14 | fresh |
| [`bounded-context`](ddd/bounded-context.md) | Semantic boundary within which a domain model is defined and applicable, representing a li | 2026-02-14 | fresh |
| [`domain-event`](ddd/domain-event.md) | Captures something significant that happened in the domain - an immutable record of a past | 2026-02-14 | fresh |
| [`domain-service`](ddd/domain-service.md) | Encapsulates domain logic that doesn't naturally fit within an Entity or Value Object, rep | 2026-02-14 | fresh |
| [`entity`](ddd/entity.md) | Domain object with a distinct identity that persists through time and different representa | 2026-02-14 | fresh |
| [`repository`](ddd/repository.md) | Mediator between the domain and data mapping layers, acting as an in-memory collection of  | 2026-02-14 | fresh |
| [`specification`](ddd/specification.md) | Encapsulates composable and reusable business rules, separating the matching logic from th | 2026-02-14 | fresh |
| [`value-object`](ddd/value-object.md) | Immutable domain object defined entirely by its attributes, with no conceptual identity. | 2026-02-14 | fresh |

## devops (14)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`ab-testing`](devops/ab-testing.md) | Controlled experimentation to validate hypotheses with metrics. | 2026-02-14 | **stale** |
| [`ansible-roles-structure`](devops/ansible-roles-structure.md) | A standardized Ansible role structure that emphasizes validation-first execution, clear ta | 2026-02-04 | **stale** |
| [`blue-green`](devops/blue-green.md) | Two identical environments enabling instant switchover. | 2026-02-14 | **stale** |
| [`canary`](devops/canary.md) | Progressive deployment to a subset of users for validation. | 2026-02-14 | **stale** |
| [`cilium-l2-loadbalancer`](devops/cilium-l2-loadbalancer.md) | Cilium L2 announcements enable LoadBalancer services to work without cloud provider integr | 2026-02-04 | **stale** |
| [`feature-toggles`](devops/feature-toggles.md) | A mechanism to modify system behavior without changing its code. | 2026-02-14 | **stale** |
| [`gitops`](devops/gitops.md) | Git as source of truth for infrastructure and applications. | 2026-02-14 | **stale** |
| [`iac`](devops/iac.md) | Manage infrastructure through versioned code. | 2026-02-14 | **stale** |
| [`immutable-infrastructure`](devops/immutable-infrastructure.md) | Replace servers instead of modifying them. | 2026-02-14 | **stale** |
| [`mcp-optimization`](devops/mcp-optimization.md) | Each MCP tool definition consumes **400-800 tokens**. With multiple servers exposing | 2026-04-24 | fresh |
| [`rolling-update`](devops/rolling-update.md) | Progressive update of instances without service interruption. | 2026-02-14 | **stale** |
| [`terraform-documentation`](devops/terraform-documentation.md) | Structured documentation patterns for Terraform modules that ensure maintainability, clari | 2026-02-04 | **stale** |
| [`terragrunt-patterns`](devops/terragrunt-patterns.md) | Terragrunt is a thin wrapper for Terraform that provides extra tools for working with mult | 2026-02-04 | **stale** |
| [`vault-patterns`](devops/vault-patterns.md) | HashiCorp Vault patterns for secrets management, PKI infrastructure, and Kubernetes integr | 2026-02-14 | **stale** |

## enterprise (12)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`active-record`](enterprise/active-record.md) | "An object that wraps a row in a database table or view, encapsulates the database access, | 2026-02-14 | fresh |
| [`data-mapper`](enterprise/data-mapper.md) | "A layer of Mappers that moves data between objects and a database while keeping them inde | 2026-02-14 | fresh |
| [`domain-model`](enterprise/domain-model.md) | "An object model of the domain that incorporates both behavior and data." - Martin Fowler, | 2026-02-14 | fresh |
| [`dto`](enterprise/dto.md) | "An object that carries data between processes in order to reduce the number of method cal | 2026-02-14 | fresh |
| [`gateway`](enterprise/gateway.md) | "An object that encapsulates access to an external system or resource." - Martin Fowler, P | 2026-02-14 | fresh |
| [`identity-map`](enterprise/identity-map.md) | "Ensures that each object gets loaded only once by keeping every loaded object in a map. L | 2026-02-14 | fresh |
| [`lazy-load`](enterprise/lazy-load.md) | "An object that doesn't contain all of the data you need but knows how to get it." - Marti | 2026-02-14 | fresh |
| [`remote-facade`](enterprise/remote-facade.md) | "Provides a coarse-grained facade on fine-grained objects to improve efficiency over a net | 2026-02-14 | fresh |
| [`repository`](enterprise/repository.md) | "Mediates between the domain and data mapping layers using a collection-like interface for | 2026-02-14 | fresh |
| [`service-layer`](enterprise/service-layer.md) | "Defines an application's boundary with a layer of services that establishes a set of avai | 2026-02-14 | fresh |
| [`transaction-script`](enterprise/transaction-script.md) | "Organizes business logic by procedures where each procedure handles a single request from | 2026-02-14 | fresh |
| [`unit-of-work`](enterprise/unit-of-work.md) | "Maintains a list of objects affected by a business transaction and coordinates the writin | 2026-02-14 | fresh |

## functional (5)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`composition`](functional/composition.md) | Combining simple functions to build more complex functions - the output of one function be | 2026-02-14 | fresh |
| [`either`](functional/either.md) | Type representing a success value (Right) or an error value (Left), providing type-safe er | 2026-02-14 | fresh |
| [`lens`](functional/lens.md) | Composable getter/setter pair for manipulating nested data structures in a functional and  | 2026-02-14 | fresh |
| [`monad`](functional/monad.md) | Design pattern for structuring programs generically while chaining operations with context | 2026-02-14 | fresh |
| [`option`](functional/option.md) | Type representing an optional value - either a value exists (Some) or it does not (None),  | 2026-02-14 | fresh |

## integration (5)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`anti-corruption-layer`](integration/anti-corruption-layer.md) | Isolate the business domain from legacy or external systems to prevent model pollution. | 2026-02-14 | fresh |
| [`api-gateway`](integration/api-gateway.md) | Single entry point for all clients, centralizing authentication, routing, and policies. | 2026-02-14 | fresh |
| [`bff`](integration/bff.md) | A dedicated backend API for each client type (web, mobile, IoT). | 2026-02-14 | fresh |
| [`service-mesh`](integration/service-mesh.md) | Dedicated infrastructure for inter-service communication with observability, security, and | 2026-02-14 | fresh |
| [`sidecar`](integration/sidecar.md) | Deploy auxiliary components in a separate container to provide cross-cutting features. | 2026-02-14 | fresh |

## learned (2)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`agent-git-stash-destruction`](learned/agent-git-stash-destruction.md) | Quand des agents `general-purpose` (avec `Bash` complet) travaillent en parallèle sur un r | 2026-04-26 | fresh |
| [`super-claude-auto-mode-fallback`](learned/super-claude-auto-mode-fallback.md) | Claude Code `--dangerously-skip-permissions` (and `defaultMode: "bypassPermissions"` in se | 2026-04-26 | fresh |

## messaging (10)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`dead-letter`](messaging/dead-letter.md) | Handle unprocessable messages via a dedicated queue to capture messages that fail after mu | 2026-02-14 | fresh |
| [`idempotent-receiver`](messaging/idempotent-receiver.md) | Guarantee unique processing despite duplicate messages by storing identifiers of already p | 2026-02-14 | fresh |
| [`message-channel`](messaging/message-channel.md) | A message is consumed by exactly one consumer. | 2026-02-14 | fresh |
| [`message-router`](messaging/message-router.md) | Routes messages based on their content. | 2026-02-14 | fresh |
| [`message-translator`](messaging/message-translator.md) | Converts a message from one format to another. | 2026-02-14 | fresh |
| [`pipes-filters`](messaging/pipes-filters.md) | Composable message processing pipeline where each filter performs an independent transform | 2026-02-14 | fresh |
| [`process-manager`](messaging/process-manager.md) | Coordinates the execution of a multi-step workflow. | 2026-02-14 | fresh |
| [`scatter-gather`](messaging/scatter-gather.md) | Distribute a request to multiple services in parallel and aggregate their responses accord | 2026-02-14 | fresh |
| [`splitter-aggregator`](messaging/splitter-aggregator.md) | Splits a message into multiple individual messages. | 2026-02-14 | fresh |
| [`transactional-outbox`](messaging/transactional-outbox.md) | Guarantee message reliability by storing them in an outbox table within the same transacti | 2026-02-14 | fresh |

## migrations (1)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`prompt-to-refine`](migrations/prompt-to-refine.md) | Skills Architecture v1.3 — PR5a deprecation, PR6 deletion. | 2026-05-21 | fresh |

## performance (8)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`batch-processing`](performance/batch-processing.md) | Collect multiple operations and execute them all at once. | 2026-02-14 | fresh |
| [`cache-strategies`](performance/cache-strategies.md) | The application manages the cache explicitly. | 2026-02-14 | fresh |
| [`connection-pool`](performance/connection-pool.md) | Maintain a set of pre-established connections to avoid connection overhead. | 2026-02-14 | fresh |
| [`debounce-throttle`](performance/debounce-throttle.md) | Wait until the user stops acting before executing. | 2026-02-14 | fresh |
| [`lazy-load`](performance/lazy-load.md) | Only load/initialize a resource when it is actually needed. | 2026-02-14 | fresh |
| [`memoization`](performance/memoization.md) | Store the result of a function call and return it directly on identical calls. | 2026-02-14 | fresh |
| [`object-pool`](performance/object-pool.md) | Pre-allocate and reuse objects to avoid the cost of creation/destruction. | 2026-02-14 | fresh |
| [`ring-buffer`](performance/ring-buffer.md) | Fixed-size buffer that overwrites old data when full. | 2026-02-14 | fresh |

## principles (6)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`DRY`](principles/DRY.md) | Every piece of knowledge must have a single, unambiguous representation within a system. | 2026-02-14 | fresh |
| [`GRASP`](principles/GRASP.md) | Assign the responsibility to the class that has the necessary information. | 2026-02-14 | fresh |
| [`KISS`](principles/KISS.md) | Simplicity should be a key goal in design. | 2026-02-14 | fresh |
| [`SOLID`](principles/SOLID.md) | A class should have only one reason to change. | 2026-02-14 | fresh |
| [`YAGNI`](principles/YAGNI.md) | Never implement something before you actually need it. | 2026-02-14 | fresh |
| [`defensive`](principles/defensive.md) | Validate preconditions at the beginning of a function and return immediately if invalid. | 2026-02-14 | fresh |

## refactoring (1)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`branch-by-abstraction`](refactoring/branch-by-abstraction.md) | Refactoring technique that allows making major changes on trunk/main incrementally and saf | 2026-02-14 | fresh |

## resilience (6)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`bulkhead`](resilience/bulkhead.md) | Isolate resources to prevent a failure from spreading to the entire system. | 2026-02-14 | fresh |
| [`circuit-breaker`](resilience/circuit-breaker.md) | Prevent cascading failures by stopping calls to a failing service. | 2026-02-14 | fresh |
| [`health-check`](resilience/health-check.md) | Verify a service's health to enable automatic detection and recovery. | 2026-02-14 | fresh |
| [`rate-limiting`](resilience/rate-limiting.md) | Control request throughput to protect services against overload. | 2026-02-14 | fresh |
| [`retry`](resilience/retry.md) | Automatically retry failed operations with exponential backoff and jitter. | 2026-02-14 | fresh |
| [`timeout`](resilience/timeout.md) | Limit the wait time of an operation to prevent resource blocking. | 2026-02-14 | fresh |

## security (8)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`abac`](security/abac.md) | Dynamic permissions based on subject, resource, and context attributes. | 2026-02-14 | **stale** |
| [`api-keys`](security/api-keys.md) | Simple secret key authentication for APIs. | 2026-02-14 | **stale** |
| [`input-validation`](security/input-validation.md) | Validate and sanitize all user input to prevent injections. | 2026-02-14 | **stale** |
| [`jwt`](security/jwt.md) | Signed and self-contained tokens for stateless authentication. | 2026-02-14 | **stale** |
| [`oauth2`](security/oauth2.md) | Authorization protocol for delegated access to resources. | 2026-02-14 | **stale** |
| [`rbac`](security/rbac.md) | Permissions based on roles assigned to users. | 2026-02-14 | **stale** |
| [`secrets-management`](security/secrets-management.md) | Secure management of secrets, credentials, and encryption keys. | 2026-02-14 | **stale** |
| [`session-auth`](security/session-auth.md) | Stateful server-side authentication with session cookies. | 2026-02-14 | **stale** |

## structural (7)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`adapter`](structural/adapter.md) | Convert the interface of a class into another interface expected by the client. | 2026-02-14 | fresh |
| [`bridge`](structural/bridge.md) | Decouple an abstraction from its implementation so that they can vary independently. | 2026-02-14 | fresh |
| [`composite`](structural/composite.md) | Compose objects into trees to represent part-whole hierarchies. | 2026-02-14 | fresh |
| [`decorator`](structural/decorator.md) | Add behaviors to an object dynamically without modifying its class. | 2026-02-14 | fresh |
| [`facade`](structural/facade.md) | Provide a simplified interface to a set of complex classes. | 2026-02-14 | fresh |
| [`flyweight`](structural/flyweight.md) | Minimize memory by sharing data between similar objects. | 2026-02-14 | fresh |
| [`proxy`](structural/proxy.md) | Provide a substitute or placeholder to control access to an object. | 2026-02-14 | fresh |

## testing (8)

| Doc | Summary | Verified | Status |
|---|---|---|---|
| [`builder`](testing/builder.md) | Fluent construction of test objects with sensible default values. | 2026-02-14 | fresh |
| [`contract-testing`](testing/contract-testing.md) | Verification of API contracts between services via consumer-driven tests. | 2026-02-14 | fresh |
| [`fixture`](testing/fixture.md) | Shared configuration and data for tests. | 2026-02-14 | fresh |
| [`object-mother`](testing/object-mother.md) | Centralized factory for pre-configured test objects. | 2026-02-14 | fresh |
| [`property-based`](testing/property-based.md) | Generative tests that verify properties on random data. | 2026-02-14 | fresh |
| [`snapshot`](testing/snapshot.md) | Capture and compare output with a saved reference. | 2026-02-14 | fresh |
| [`test-containers`](testing/test-containers.md) | Real infrastructure in Docker containers for integration tests. | 2026-02-14 | fresh |
| [`test-doubles`](testing/test-doubles.md) | Substitution objects to isolate the code under test. | 2026-02-14 | fresh |
