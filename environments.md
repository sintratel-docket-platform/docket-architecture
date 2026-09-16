# Deployment per environment

**Purpose** Define what separates one environment from another, how a change advances to production, and which controls exist at each transition.

![Docket deployment per environment](img/environments.png)

The components are described in [`logical-architecture.md`](logical-architecture.md). The physical layer holding this cluster up is in [`aws-infrastructure.md`](aws-infrastructure.md).

## Topology

A single Amazon EKS cluster in `us-east-1`, with three namespaces: `dev`, `staging` and `prod`. Each namespace runs a complete instance of the application, that is the five services plus Redis.

Alongside the application, running inside the cluster:

| Component | Role |
|---|---|
| **Argo CD** | Synchronises the three namespaces against the manifest repository |
| **External Secrets Operator** | Materialises the parameters it reads from SSM Parameter Store as Kubernetes `Secret` objects, per namespace |
| **AWS Load Balancer Controller** | Translates a `Gateway` and its `HTTPRoute`s into ALB configuration ([ADR-017](decisions.md#adr-017-exposure-through-the-gateway-api)) |
| **Health endpoints and probes** | Every service answers an unauthenticated `GET /health`, except the worker, which refreshes a heartbeat file. The Kubernetes probes read both, so a version that starts without serving never becomes `Ready` ([card 20](project-retrospective.md#current-limitations), first phase) |
| **Observability stack** | CloudWatch Container Insights, through the CloudWatch Observability EKS add-on; Zipkin instrumentation is preserved but unwired ([ADR-023](decisions.md#adr-023-observability-cloudwatch-container-insights)) |

Operational alerts are not deployed; they are card 21.

## Boundaries between development, staging and production

**What separates them.** Isolation is logical. Each namespace has its own RBAC, its own resource quotas and its own secret prefix in Parameter Store (`/docket/<environment>/...`), reachable only by its IRSA role. Sharing a cluster means there is no node or control plane isolation, so an incident in the cluster reaches all three environments at once, production included.

**What they share.** The cluster, the nodes, the registry, the Argo CD instance and the DNS zone. `dev` and `staging` also share the `docket-non-production` gateway and its load balancer; production has its own, and its gateway admits routes from no other namespace ([ADR-018](decisions.md#adr-018-productions-argo-cd-project-gateway-and-restore-on-start)). What changes between environments is the image version declared in the manifests, and the origin of that image is always the same registry.

**What connects them.** Only promotion, and always in one direction: `dev` to `staging` to `prod`. There is no traffic between namespaces and no access from one environment to another's data.

**The controls.**

Each environment has two independent controls: one over the merge in the manifest repository, and one over the synchronisation Argo CD performs.

| Target environment | Control over the merge | Argo CD sync policy |
|---|---|---|
| `dev` | None additional | `automated`, syncs when the change is detected |
| `staging` | Pull request with review | `automated`, syncs after the merge |
| `prod` | Pull request with an approval from a named approver, checked and audited ([ADR-016](decisions.md#adr-016-production-approval-without-branch-protection)); whether that approver may be the requester is a policy parameter ([ADR-020](decisions.md#adr-020-independent-approval-as-a-policy-parameter)) | **Manual**, an approver triggers the sync after the merge and records it; who may sync is recorded, not enforced ([ADR-021](decisions.md#adr-021-security-controls-applied-and-the-ones-deferred-on-record)) |

The distinction between the two controls matters in production. Approving and merging the pull request leaves the version declared in Git, and the change reaches the cluster only when a person runs the sync of the Argo CD `Application`. They are two separate, auditable acts.

The approval policy and its approvers live in the manifests repository, in `docs/production-change-policy.md`, next to the files and workflows that apply it. [ADR-016](decisions.md#adr-016-production-approval-without-branch-protection) records why approval there is checked, audited and reported rather than enforced. What is defined here is the boundary that policy respects.

## What differs between environments

Staging exists to rehearse production, so it deliberately runs what production
will run. What separates the three is isolation, exposure and how a version
arrives, not the application's configuration. An identical row below is a
decision, not an oversight, and says why.

| Dimension | `dev` | `staging` | `prod` | Why |
|---|---|---|---|---|
| Namespace | `dev` | `staging` | `prod` | One cluster, one namespace per environment ([ADR-003](decisions.md#adr-003-one-shared-cluster-with-three-namespaces)) |
| Resource quota and limit range | 2 CPU / 3 Gi of limits, 15 pods | same | same | A staging that fits where production would not proves nothing; production-shaped capacity, if needed, is card 26 |
| RBAC for operators | `exec` and `port-forward` allowed | allowed | **not allowed** | Diagnosing a rehearsal needs a shell; production does not get one |
| Network isolation | namespace-scoped policy, load balancer subnets admitted | same | same | No traffic crosses environments |
| Secrets | `/docket/dev/`, read by `docket-dev-eso` | `/docket/staging/` | `/docket/prod/` | Each environment can only name, and only read, its own prefix |
| Host | `dev.docket.<domain>` | `staging.docket.<domain>` | `docket.<domain>`, once production is synced | One wildcard certificate covers all three |
| Load balancer | shared `docket-non-production` gateway | shared with `dev` | its own gateway, `docket-production`, in `prod` | [ADR-015](decisions.md#adr-015-staging-shares-the-non-production-load-balancer), [ADR-017](decisions.md#adr-017-exposure-through-the-gateway-api), [ADR-018](decisions.md#adr-018-productions-argo-cd-project-gateway-and-restore-on-start) |
| How a version arrives | the service pipeline writes it on merge | a promotion pull request, checked by `gitops-ci` | a promotion pull request approved by a named approver | [ADR-013](decisions.md#adr-013-semantic-versioning-for-services-and-modules), [ADR-014](decisions.md#adr-014-promotion-between-environments) |
| Argo CD sync | automated, self-heal, prune | automated, self-heal, prune | **manual**; every start restores the last recorded release | The merge declares production; a person applies it; a start never applies anything newer than the last release ([ADR-018](decisions.md#adr-018-productions-argo-cd-project-gateway-and-restore-on-start)) |
| Argo CD project | `default` | `default` | `production`: this repository, the `prod` namespace, no cluster-scoped objects, only the kinds production renders | A production Application cannot deploy elsewhere or anything unexpected ([ADR-018](decisions.md#adr-018-productions-argo-cd-project-gateway-and-restore-on-start)) |
| Images kept in the registry | the last ten | every declared image pinned `promoted-staging-*` | pinned `promoted-production-*` | An environment must never declare a pruned image |
| Replicas, requests, limits, environment variables | from the base manifests | same | same | Staging rehearses production's configuration exactly |

## GitOps flow

The manifest repository holds the declarative truth of the three environments. Argo CD runs inside the cluster, watches that repository and synchronises each namespace with what is declared.

The important consequence: the pipeline never applies changes to the cluster directly. GitHub Actions builds the image and publishes it to ECR, and the deployment happens when a manifest in Git references that new version. Every change in production has, by construction, a commit explaining it.

This flow imposes one constraint on tagging: **image tags must be immutable**. With a tag that gets rewritten, the manifest does not change, Argo CD detects nothing, and promotion between environments stops working. The concrete tagging scheme is defined when the pipeline is built.

The same applies to infrastructure: the Terraform pipeline provisions the AWS layer and leaves the inside of the cluster untouched. They are two independent flows. See [`aws-infrastructure.md`](aws-infrastructure.md#infrastructure-change-flow).

> **Consequence of the ephemeral lifecycle.** The cluster is destroyed and recreated routinely ([ADR-010](decisions.md#adr-010-ephemeral-infrastructure-with-split-state)). Anything living inside it and not declared in the GitOps repository is lost on every cycle: Redis data is ephemeral by construction, and Argo CD must be installed from the Terraform stack or from a declared bootstrap so the cluster rebuilds without manual intervention. Observability data is the exception: CloudWatch metrics and logs are AWS-managed outside the cluster, so they outlive a destroy and apply cycle for as long as the configured retention keeps them ([ADR-023](decisions.md#adr-023-observability-cloudwatch-container-insights)).

## Dependencies between repositories and environments

| Repository role | What it contributes | How it reaches the environment |
|---|---|---|
| **Service repositories**, one per microservice | Application code | A push triggers the pipeline, which builds the image and publishes it to ECR with an immutable tag |
| **Infrastructure repository** | Terraform, split into a persistent stack and an ephemeral stack | Provisions the VPC, the cluster and the supporting resources |
| **GitOps manifest repository** | Declarative state per environment | Argo CD watches it and synchronises each namespace |
| **External configuration repository** | Per-environment application configuration (External Configuration Store) | Consumed at deployment time, separate from the image |
| **Documentation repository** (this one) | Reference architecture and decisions | Not deployed. It is the source for the other four |

## Secrets management

The application secrets, among them the `JWT_SECRET` shared by Auth API, Users API and Todos API, live in SSM Parameter Store as `SecureString`, outside the cluster. External Secrets Operator reads them through IRSA and materialises them as Kubernetes `Secret` objects in each namespace.

The scope is per environment: the `dev` IRSA role has read access only to `/docket/dev/...`. No secret is left in plain text in a repository, and the set survives the destruction of the cluster.

The AWS credentials the pipeline uses are resolved through OIDC federation with temporary credentials, separately from this mechanism. See [ADR-011](decisions.md#adr-011-pipeline-credentials-with-oidc-and-an-iam-role).

## Domain, DNS and TLS

Each environment resolves through a different host. Development and staging reach the shared non-production ALB and production its own; each environment's `HTTPRoute` claims its `Host` on its gateway.

| Environment | Host |
|---|---|
| `prod` | `docket.<domain>` |
| `staging` | `staging.docket.<domain>` |
| `dev` | `dev.docket.<domain>` |

The certificate is issued by ACM and terminates at the ALB. The Route 53 records are ALIAS type. They are created by external-dns from inside the cluster rather than by Terraform, because the ALB is recreated on every cluster cycle and changes DNS name. Detail in [`aws-infrastructure.md`](aws-infrastructure.md#domain-dns-and-tls).
