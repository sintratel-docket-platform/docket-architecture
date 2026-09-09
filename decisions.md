# Architecture decisions

| | |
|---|---|
| **Purpose** | Record each architecture decision with its context, its consequences and the alternative that was rejected. |
| **Format** | One ADR (Architecture Decision Record) per decision, numbered and with an explicit status. |
| **Rule** | A decision is never deleted or silently rewritten. It is marked *Superseded* and the new one is added, so there is a record of what was rejected and why. |

Statuses: **Accepted** · **Assumption** (taken in the absence of guidance to the contrary and not yet confirmed) · **Superseded** · **Implemented**.

## Conditions framing every decision

| Condition | Confirmed value |
|---|---|
| Account type | AWS free credit plan |
| Balance | 100 USD, extendable to 200 USD with 5 guided activities |
| Plan term | 182 days |
| Working window | 2 weeks |
| Region | `us-east-1` |
| Operating mode | Ephemeral infrastructure, with routine `destroy` and `apply` |

| ADR | Decision | Status |
|---|---|---|
| [001](#adr-001-registry-amazon-ecr) | Registry: Amazon ECR | Accepted |
| [002](#adr-002-secrets-with-external-secrets-and-ssm-parameter-store) | Secrets: External Secrets and SSM Parameter Store | Accepted |
| [003](#adr-003-one-shared-cluster-with-three-namespaces) | One shared cluster with three namespaces | Accepted |
| [004](#adr-004-compute-amazon-eks) | Compute: Amazon EKS | Accepted |
| [005](#adr-005-multi-az-network-with-a-single-nat-gateway) | Network: multi-AZ with a single NAT Gateway | Accepted |
| [006](#adr-006-administrative-access-with-ssm-session-manager) | Administrative access with SSM Session Manager | Accepted |
| [007](#adr-007-terraform-validation-with-ci-quality-gates) | Terraform validation with CI quality gates | Implemented |
| [008](#adr-008-dns-in-route-53-and-tls-with-acm) | DNS in Route 53 and TLS with ACM | Accepted |
| [009](#adr-009-native-s3-state-locking) | Native S3 state locking | Accepted |
| [010](#adr-010-ephemeral-infrastructure-with-split-state) | Ephemeral infrastructure with split state | Accepted |
| [011](#adr-011-pipeline-credentials-with-oidc-and-an-iam-role) | Pipeline credentials with OIDC and an IAM role | Accepted |
| [012](#adr-012-modules-in-their-own-repository-versioned-by-tag) | Modules in their own repository, versioned by tag | Accepted |

---

## ADR-001 Registry: Amazon ECR

**Status:** Accepted.

**Context.** The whole platform infrastructure lives in the team AWS account, with IAM as the authorisation mechanism.

**Decision.** Five private Amazon ECR repositories, one per microservice. The nodes `pull` with the node group instance role.

**Consequences.**
- Image pulls are resolved with the node role, with no `imagePullSecrets` and no static credentials in the cluster.
- Registry access control is expressed in IAM, alongside the rest of the infrastructure.
- The ECR free tier covers 500 MB per month, which forces a lifecycle policy that prunes old images.

**Rejected alternative.** GitHub Container Registry, which was the initial choice when the project had no cloud account. It remains technically valid and its free tier is broader. Rejected because it leaves the registry with a different permission model from the rest of the platform, and cannot take advantage of the instance role for pulls.

---

## ADR-002 Secrets with External Secrets and SSM Parameter Store

**Status:** Accepted. Supersedes Bitnami Sealed Secrets.

**Context.** The cluster is destroyed and recreated routinely ([ADR-010](#adr-010-ephemeral-infrastructure-with-split-state)). Any mechanism holding the decryption key inside the cluster loses it on every `destroy`, and with it the ability to decrypt the secrets stored in the repository.

**Decision.** Secrets live in SSM Parameter Store as `SecureString`, outside the cluster and inside the persistent stack. External Secrets Operator, authenticated through IRSA, reads them and materialises them as Kubernetes `Secret` objects in each namespace. The tree is segmented per environment (`/docket/<environment>/...`) and each role has read access only over its own prefix.

**Consequences.**
- Secrets survive the destruction of the cluster.
- There is no cryptographic material to back up and restore between deployments.
- Access is expressed in IAM and audited in CloudTrail.
- Parameter Store in the standard tier has no cost. The advanced tier and automatic rotation would.
- Secrets leave the Git repository, which reduces the "all declared state in Git" traceability the previous approach offered.

**Rejected alternative.** Sealed Secrets with backup and restore of the controller key on every `apply`. It works, and it turns a critical key into an artifact that must be custodied and reinjected every cycle, introducing a fragile manual step into a daily operation.

---

## ADR-003 One shared cluster with three namespaces

**Status:** Accepted.

**Context.** The board acceptance criterion mentions "cluster/namespace" as a single unit, and the available budget is a limited credit balance.

**Decision.** A single EKS cluster with the namespaces `dev`, `staging` and `prod`, each with its own RBAC and its own resource quotas.

**Consequences.**
- Isolation between environments is logical. There is no node or control plane separation, so an incident in the cluster reaches all three environments at once, production included.
- It forces sizing the nodes for the sum of the three environments. See the pods-per-node calculation in [`aws-infrastructure.md`](aws-infrastructure.md#compute).

**Rejected alternative.** One cluster per environment. It offers real isolation and is the right call with a client who requires it. Rejected because it triples the control plane cost and exhausts the available balance in a few days.

---

## ADR-004 Compute: Amazon EKS

**Status:** Accepted.

**Context.** The EKS control plane costs 0.10 USD per hour. Over the 2-week project window that is around 34 USD, which fits within the available credit balance. The brief requires Kubernetes orchestration in all three environments.

**Decision.** Amazon EKS in `us-east-1`, with a managed node group of 2 nodes, one per availability zone, in private subnets.

**Consequences.**
- The control plane is managed by AWS, with no `etcd` to back up and no upgrades to operate.
- It enables IRSA, EKS access entries and the native controllers, which are the basis of [ADR-002](#adr-002-secrets-with-external-secrets-and-ssm-parameter-store) and [ADR-008](#adr-008-dns-in-route-53-and-tls-with-acm).
- It matches the architecture that would be used with a real client, which strengthens the credibility of the deliverable.
- It consumes about a third of the balance if kept running for the full 2 weeks, which makes claiming the additional credits and shutting down outside working hours necessary.
- EKS requires subnets in two availability zones and caps pods per node by instance type. Both constraints shape [ADR-005](#adr-005-multi-az-network-with-a-single-nat-gateway) and the node group sizing.

**Rejected alternative.** Self-managed Kubernetes with k3s on a small EC2 instance. Rejected because 1 GiB of RAM does not sustain three complete environments plus Argo CD and observability, and a single node removes fault tolerance.

---

## ADR-005 Multi-AZ network with a single NAT Gateway

**Status:** Accepted.

**Context.** EKS requires subnets in at least two availability zones. A NAT Gateway costs 0.045 USD per hour, around 15 USD over the project window, and the reference topology deploys one per zone.

**Decision.** VPC `10.0.0.0/16` across `us-east-1a` and `us-east-1b`, with four subnets: two public for the ALB and the NAT, and two private for the nodes. A single NAT Gateway, located in public subnet A and shared by both zones.

**Consequences.**
- The nodes are out of reach from the internet and the only exposed component is the ALB.
- If `us-east-1a` becomes unavailable, the nodes in `us-east-1b` lose internet egress. The concession is taken deliberately in exchange for 15 USD of budget.

**Rejected alternative.** One NAT Gateway per zone, which is correct for production and adds 15 USD. Placing the nodes in public subnets to do without the NAT was also evaluated: it saves the same amount and exposes the nodes, moving away from the standard topology the project sets out to demonstrate.

---

## ADR-006 Administrative access with SSM Session Manager

**Status:** Accepted.

**Context.** With EKS, cluster administration is done with `kubectl` against the managed endpoint, authorised by IAM. Access to the node operating system is needed on rare occasions.

**Decision.** Occasional access to a node is done with SSM Session Manager. No bastion host is deployed, no administration subnet is reserved, and no security group rule opens `22/tcp`.

**Consequences.**
- The attack surface of an exposed SSH port disappears, along with the associated key management.
- Every session is authorised by IAM and recorded in CloudTrail, traceable per person.
- One EC2 instance and its volume are saved.
- It depends on the SSM agent, included in the EKS AMI, and on the node having internet egress or VPC endpoints towards SSM.

**Rejected alternative.** A bastion host in an administration subnet with SSH restricted by IP. It is the classic pattern and remains valid. Rejected because it costs an additional instance, requires custodying shared SSH keys, and offers less traceability than SSM.

---

## ADR-007 Terraform validation with CI quality gates

**Status:** Implemented.

**Context.** A Terraform defect applied to the real account can leave partially created infrastructure and consume the limited AWS credit balance. The original decision proposed an emulator, but no Floci configuration was implemented.

**Decision.** Pull requests run canonical formatting and validation, TFLint, Trivy and Checkov. The infrastructure planning workflow serialises its saved plan with `terraform show -json` and evaluates it against the Docket OPA policy. Terraform module tests run in a separate job whenever a module provides a `tests/` directory.

**Consequences.**
- Syntax errors, broken references, provider-specific defects and common IaC misconfigurations fail before infrastructure planning.
- Docket-specific security invariants are evaluated against the planned resource values rather than inferred from source text.
- Real-state planning remains necessary, because static gates cannot detect drift, an incorrect target, or a missing `moved` block.

**Rejected alternative.** Applying against the real account as the first validation step would turn shared infrastructure into the test environment. Floci remains a possible future integration tool, but it is not recorded as an implemented control.

---

## ADR-008 DNS in Route 53 and TLS with ACM

**Status:** Accepted.

**Context.** Traffic enters through an ALB, which is identified by DNS name and is recreated on every cluster cycle ([ADR-010](#adr-010-ephemeral-infrastructure-with-split-state)).

**Decision.** Hosted zone in Route 53, with one ALIAS record per environment pointing at the ALB. Certificate issued by AWS Certificate Manager, validated by DNS against that same zone and terminated at the ALB.

**Reasons.**

1. ACM issues public certificates at no cost, renews them automatically and validates by DNS against the zone itself.
2. Recreating the cluster frequently turns a certificate authority with weekly issuance limits into a real bottleneck. ACM imposes no such limit.
3. DNS is declared in Terraform, versioned and reproducible, which is what area 02 is assessed on.

**Consequences.**
- Around 0.50 USD per month for the hosted zone, the only cost that runs outside the start-up and shutdown cycle.
- One manual step, once: delegating the domain nameservers at the registrar.
- The certificate and the zone belong to the persistent stack, and the ALB to the ephemeral one.
- The ALIAS records themselves are created by external-dns from inside the cluster, because the ALB changes name on every cycle and Terraform-managed records would force a re-apply after every start-up.

**Rejected alternative.** DNS at the registrar with hand-created records, and `cert-manager` with Let's Encrypt inside the cluster.

---

## ADR-009 Native S3 state locking

**Status:** Accepted.

**Context.** Since Terraform 1.10 the S3 backend supports native locking through conditional writes, with the `use_lockfile` argument. Since 1.11 the `dynamodb_table`, `dynamodb_endpoint` and `endpoints.dynamodb` arguments are deprecated, and the official documentation warns that DynamoDB locking will be removed in a future minor version.

**Decision.** S3 backend with `use_lockfile = true`. Locking uses a `.tflock` object in the same state bucket.

**Consequences.**
- One less resource to provision, permission and maintain.
- The locking permissions are `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` over `<key>.tflock`.
- It forces setting `required_version` to 1.11 or later.

**Rejected alternative.** A DynamoDB table for locking. It appears in most tutorials and its free tier covers the project usage. Rejected because it is deprecated, and adopting it today would mean writing code with a known expiry date.

---

## ADR-010 Ephemeral infrastructure with split state

**Status:** Accepted.

**Context.** The budget is a credit balance and the project window is 2 weeks. Keeping EKS running continuously consumes about a third of the balance. Destroying and recreating the infrastructure outside working hours cuts that spend to less than half, and covers the FinOps stretch goal in the brief.

**Decision.** The infrastructure is operated as ephemeral, with `terraform destroy` and `terraform apply` as routine operations. The Terraform is split into stacks with separate state:

| Stack | Contains | Lifecycle |
|---|---|---|
| `persistent` | ECR, Route 53 zone, ACM certificate, OIDC provider, IAM roles | Created once and stays |
| `ephemeral` | VPC, subnets, NAT, EKS, node group, IRSA roles | `apply` and `destroy` on demand |
| `platform` | Namespaces, quotas, RBAC, network policies, controllers | Rebuilt with the cluster |
| `environments/*` | SSM parameter tree per environment | Stays |

**Consequences.**
- A `destroy` leaves the registry, the secrets and the DNS zone intact.
- It is what forces the design of [ADR-002](#adr-002-secrets-with-external-secrets-and-ssm-parameter-store), because a secrets mechanism with the key inside the cluster does not survive the cycle.
- Bringing the cluster up from scratch takes on the order of 15 to 20 minutes, time that has to be accounted for in daily planning.
- Anything living inside the cluster and not declared in the GitOps repository is lost on every cycle. Prometheus and Redis data are ephemeral by construction.
- Argo CD has to be installed from the `platform` stack so the cluster rebuilds without manual intervention.

**Rejected alternative.** Keeping the infrastructure running for the whole 2 weeks. It is simpler and leaves the platform always available for review. Rejected because it consumes around 92 USD of the balance and wastes the opportunity to demonstrate FinOps practices.

---

## ADR-011 Pipeline credentials with OIDC and an IAM role

**Status:** Accepted.

**Context.** The pipeline needs AWS credentials to run Terraform and publish images. Storing long-lived access keys as repository secrets is the most widespread practice and the most fragile, because they do not rotate by themselves and outlive whoever created them.

**Decision.** GitHub Actions obtains temporary credentials through OIDC federation, assuming two different roles depending on the job:

| Role | Assumed by | Permissions |
|---|---|---|
| `GitHubActionsBuildRole` | The job that builds and publishes images | ECR on the five repositories |
| `GitHubActionsDeployRole` | The job that runs Terraform | EC2, VPC, IAM, S3, EKS and Route 53 |

Application secrets are resolved by [ADR-002](#adr-002-secrets-with-external-secrets-and-ssm-parameter-store).

**Consequences.**
- The project stores no long-lived access key.
- The build job has no ability to touch the infrastructure, which answers the least-privilege criterion of card `18`.
- The trust policy of each role is restricted to the specific repository and branch, using the immutable subject form GitHub issues, with numeric organisation and repository identifiers. Opening it to the whole organisation would be equivalent to a shared credential.
- The deploy role currently holds a broad policy. A scoped candidate and a plan-only role exist alongside it, unattached, pending a CloudTrail-backed apply and teardown cycle to confirm the action set.

**Rejected alternative.** HashiCorp Vault as a single secrets manager. It covers the same scope as OIDC and Parameter Store combined, and requires operating a third system that itself needs initial credentials. It remains available as a learning stretch goal.

---

## ADR-012 Modules in their own repository, versioned by tag

**Status:** Accepted.

**Context.** The Terraform modules lived in `docket-infrastructure` and were consumed by relative path. That means every stack always uses whatever is on `main`: there is no way to run one version in production while a change is exercised in development, and a module edit reaches all three environments the moment it merges.

Measured before deciding: 11 of 36 commits in that repository touched `modules/` and `stacks/` together, and the coupling was not confined to the early scaffolding. That is the signal that the modules were still co-evolving with their only consumer, which is the usual argument for *not* splitting.

**Decision.** Two repositories, following the Gruntwork `infrastructure-modules` and `infrastructure-live` split:

| Repository | Holds | Visibility |
|---|---|---|
| `docket-terraform-modules` | The eight reusable modules, versioned by tag | **Public** |
| `docket-infrastructure` | The seven stacks: the live infrastructure | Private |

Stacks consume modules as `git::…//modules/<name>?ref=v1.0.0`. Each environment pins independently, so promotion is a one-line change to a `ref` in a pull request.

**Why public.** `terraform init` has to clone the modules repository from CI. A private one needs a static credential in the pipeline, which is what [ADR-011](#adr-011-pipeline-credentials-with-oidc-and-an-iam-role) exists to avoid. Public keeps that posture, and costs a hard constraint in exchange: nothing internal may ever land there. The `exposure` job fails the build on an account identifier, an account-qualified ARN, the domain, or credential material, and the split itself was gated on it — one commit message naming the project domain was rewritten out of the history before the first push, because published history cannot be retracted.

**Consequences.**
- Production can run an older module version than development, deliberately.
- A module change no longer reaches an environment until someone bumps its `ref`. That is the point, and it is also friction: testing a module change against a stack means pointing at a branch first and turning it into a tag before the consumer merges.
- The modules stopped naming their own resources after this project. Every one takes a `name_prefix`, which is what made them publishable at all.
- Tags are repository-wide: `v1.1.0` versions all eight modules together. Accepted at this size. If they start releasing at visibly different cadences, the answer is component tags (`network/v1.2.0`), not more repositories.
- Renovate opens a pull request per environment when a release exists, and is disabled for production, so a version reaches prod because a person promoted it.
- The split changed no infrastructure. The `ephemeral` plan was diffed against the same baseline three times — before parameterising the names, after it, and after repointing the sources — and was identical each time. Changing a `source` does not change a resource address, so no `moved` blocks were needed.

**Rejected alternatives.**

*Keeping one repository.* Simpler, and it is what the 31% coupling measurement argued for. Rejected because the coupling is a symptom of modules that had no way to be versioned, not a reason to leave them that way, and because per-environment promotion is what areas 04 and 06 are assessed on.

*One repository per module, nine in total.* What a private Terraform registry requires. Rejected because it takes the organisation from 12 repositories to 20 and multiplies a pipeline that had just been built once, for versioning granularity nobody has asked for at eight modules.

*Private modules repository with a deploy key.* Would keep the account identifier question moot. Rejected because the modules contain no account identifier — they were audited before publishing — and because it reintroduces a long-lived credential into CI for no gain.

---

## Open assumptions

Statements this design takes as true and worth resolving before or during the Terraform work.

**Cluster capacity.** The sizing to 2 nodes comes from the pod count and the limit the EKS CNI imposes, without validation under real load. If it turns out to be insufficient, the available way out is reducing how many environments run simultaneously, because the budget does not allow larger nodes.

**Instance type is constrained by the free plan, not only by capacity.** The account only allows launching free-tier-eligible instance types. A type outside that list fails silently, with the error visible only in CloudTrail. The implementation uses `m7i-flex.large`.

**Only production requires manual approval.** It is assumed that promotion from `dev` to `staging` can be automatic after the pull request review. To be confirmed when the area 04 pipelines are defined.

**Observability starts from an existing base.** `auth-api` already includes Zipkin tracing instrumentation and the frontend already sends spans. Area 07 extends that starting point.

**The GitOps manifest repository now exists.** `docket-gitops` holds the Argo CD `Application` for development, targeting the `dev` namespace on EKS. Only Redis has manifests so far; the five services have none, which is what blocks the first deployment through GitOps.
