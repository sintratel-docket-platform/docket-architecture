# Design patterns

**Purpose** Name the patterns this platform applies, in the application and in
the way it is built and deployed, and point at the file that implements each
one. Area 03 of the SINTRATEL brief asks for exactly this, plus at least one
resilience, one configuration and one integration pattern, so section 1 answers
that part first and section 5 says what the platform does not do.

A pattern appears here only when a file implements it. Where the platform
solves a problem without a named pattern, this document says so rather than
attaching a name to make a list longer.

## 1. The three the brief asks for

| Category | Pattern | Where it lives |
|---|---|---|
| Resilience | **Retry with capped backoff** | `docket-log-message-processor/main.py`, `create_pubsub` reconnects on a refused Redis connection with a delay that grows 100 ms per attempt. `docket-todos-api/redisClient.js`, `retryStrategy` returns `attempt × 100 ms` capped at two seconds and never stops, so commands issued while Redis is away wait in the client's offline queue. Each service's `service-ci` retries the write into `docket-gitops` five times, rebasing between attempts, because five pipelines write the same file |
| Configuration | **External configuration with a provider** | No environment-specific value is baked into an image; every service reads its configuration from environment variables, and the same image runs in development, staging and production. The values come from SSM Parameter Store through the External Secrets Operator ([ADR-002](decisions.md#adr-002-secrets-with-external-secrets-and-ssm-parameter-store)), and the per-environment differences live in Kustomize overlays rather than in the code |
| Integration | **Event-driven messaging over a channel** | `docket-todos-api` publishes an event for every create, status change, assignment and delete on a Redis channel, and `docket-log-message-processor` consumes it. The write path answers the user without waiting for the log to be written, and neither service knows the other's address |

The retry policies and the secret provider were built by this team, in cards
[#27](https://github.com/sintratel-docket-platform/docket-roadmap/issues/27) and
[#18](https://github.com/sintratel-docket-platform/docket-roadmap/issues/18).
The Redis channel came with the application this project forked, and card #27
made it survive a Redis outage rather than end the process.

## 2. Patterns in the services

| Pattern | What it does here | Where |
|---|---|---|
| **Dependency injection** | Collaborators arrive as arguments, which is also what makes the suites runnable without a network. `todos-api` builds its controller with `{tracer, redisClient, logChannel, clock}`, and the injected clock is what makes every compliance test deterministic | `docket-todos-api/routes.js`, `todoController.js` |
| **Dependency inversion behind an interface** | `auth-api` calls `users-api` through an `HTTPDoer` interface rather than an HTTP client, so a test supplies a stub and the traced client is just another implementation | `docket-auth-api/user.go` |
| **Decorator** | `TracedClient` wraps a Zipkin-instrumented HTTP client and satisfies the same `HTTPDoer` interface, adding a span per call without the caller knowing. In the frontend, a Vue-resource interceptor adds the `Authorization` header to every request that lacks one | `docket-auth-api/tracing.go`, `docket-frontend/src/auth.js` |
| **Chain of responsibility** | Each service composes its request handling from middleware: Echo's logger, recovery and CORS in `auth-api`; `express-jwt` in `todos-api`, registered after `/health` so probes reach it without a token; and a Spring Security chain in `users-api`, which adds its JWT filter after the basic-authentication one | `docket-auth-api/main.go`, `docket-todos-api/server.js`, `docket-users-api/.../configuration/SecurityConfiguration.java` |
| **Factory** | `createRedisClient` builds a client with the retry policy and the error handling already attached, so no caller can forget either | `docket-todos-api/redisClient.js` |
| **Repository** | `users-api` reads users through a Spring Data interface, which keeps the controller free of persistence detail and lets the integration tests run against H2 | `docket-users-api/.../repository/UserRepository.java` |
| **Layered separation** | `routes → controller → store` in `todos-api`, and `controller → repository → entity` in `users-api`. The compliance rules sit in a module of their own, as pure functions of a task and a clock | `docket-todos-api/compliance.js` |
| **State container** | The frontend keeps authentication and user state in a Vuex store with explicit mutations, so a component never writes shared state directly | `docket-frontend/src/store/` |

## 3. Patterns in the platform

| Pattern | What it does here | Recorded in |
|---|---|---|
| **GitOps reconciliation** | The cluster's desired state is a Git revision, and Argo CD reconciles towards it. Nothing reaches an environment by a command against the cluster | [ADR-014](decisions.md#adr-014-promotion-between-environments) |
| **Base and overlay composition** | One base per service, three overlays that differ only in what an environment must change. A promotion is a version pinned in an overlay | [ADR-013](decisions.md#adr-013-semantic-versioning-for-services-and-modules) |
| **Versioned module composition** | Infrastructure is assembled from modules consumed by tag, never by path, so each environment pins its own version and a module change reaches them one at a time | [ADR-012](decisions.md#adr-012-modules-in-their-own-repository-versioned-by-tag) |
| **Split lifecycle state** | What is expensive to recreate (registry, DNS, identities) lives in a stack that stays, and what can be destroyed nightly lives in one that goes | [ADR-010](decisions.md#adr-010-ephemeral-infrastructure-with-split-state) |
| **Federated workload identity** | Neither the pipeline nor a pod holds a static credential: GitHub Actions assumes a role through OIDC, and a pod assumes one through IRSA | [ADR-011](decisions.md#adr-011-pipeline-credentials-with-oidc-and-an-iam-role) |
| **Secret injection from a provider** | The External Secrets Operator writes a Kubernetes Secret from Parameter Store, so no secret is committed and rotation is a parameter version | [ADR-002](decisions.md#adr-002-secrets-with-external-secrets-and-ssm-parameter-store) |
| **Edge routing through a gateway** | One gateway terminates TLS and routes by host, and production has its own so no other namespace can attach a route to it | [ADR-017](decisions.md#adr-017-exposure-through-the-gateway-api), [ADR-018](decisions.md#adr-018-productions-argo-cd-project-gateway-and-restore-on-start) |
| **Health probe, and a heartbeat for a process with no endpoint** | The four HTTP services answer `/health`, which Kubernetes reads for readiness and liveness. `log-message-processor` serves nothing, so it refreshes a file every fifteen seconds and its liveness probe reads the file's age | `docket-gitops/apps/*/base/deployment.yaml` |

## 4. Where the patterns are verified

The patterns that carry behaviour have tests, and the tests are how a reader
confirms the pattern does what this document claims.

| Claim | Test |
|---|---|
| The Redis client retries for as long as Redis is away, with a growing delay | `docket-todos-api/__tests__/unit/redis-client.test.js` |
| The board still answers while Redis refuses connections | `docket-todos-api/__tests__/integration/redis-unavailable.test.js` |
| Compliance states depend on the injected clock, not on the real one | `docket-todos-api/__tests__/unit/compliance.test.js` |
| `auth-api` can be tested without `users-api`, through the `HTTPDoer` seam | `docket-auth-api/user_test.go` |
| The filter chain rejects a token signed with another key, or with another algorithm | `docket-users-api/.../JwtAuthenticationFilterTest.java` |

## 5. What the platform does not do

| Not used | Why |
|---|---|
| **Circuit breaker** and **bulkhead** | One synchronous call exists between services, `auth-api` to `users-api` during a login. A breaker around a single hop in a five-service application adds a failure mode to reason about and hides the one signal the login already gives |
| **Timeout as a policy** | The alert formatter sets one on its own HTTP call, and nothing else does. The Go client that `auth-api` uses has no timeout, which is a real gap rather than a decision |
| **Feature toggles** | Nothing in the application is released dark. Promotion between environments carries that role, with a version pinned per environment |
| **Service mesh, sidecars** | Retries, mutual TLS and traffic splitting between five services would cost more to operate than the problems they would solve here, on a course budget |
| **CQRS, event sourcing, saga** | There is one write model, one store per service and no cross-service transaction to coordinate |

## 6. Related documents

[`logical-architecture.md`](logical-architecture.md) describes the services and
the queue this document names patterns in.
[`environments.md`](environments.md) and
[`pipelines.md`](pipelines.md) cover the deployment and delivery flows behind
section 3. [`decisions.md`](decisions.md) carries the reasoning for every ADR
referenced here.
