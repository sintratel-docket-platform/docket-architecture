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
| [013](#adr-013-semantic-versioning-for-services-and-modules) | Semantic versioning for services and modules | Accepted |
| [014](#adr-014-promotion-between-environments) | Promotion between environments | Implemented |
| [015](#adr-015-staging-shares-the-non-production-load-balancer) | Staging shares the non-production load balancer | Implemented |
| [016](#adr-016-production-approval-without-branch-protection) | Production approval without branch protection | Implemented |
| [017](#adr-017-exposure-through-the-gateway-api) | Exposure through the Gateway API | Implemented |
| [018](#adr-018-productions-argo-cd-project-gateway-and-restore-on-start) | Production's Argo CD project, gateway and restore on start | Implemented |
| [019](#adr-019-release-notes) | Release notes | Implemented |
| [020](#adr-020-independent-approval-as-a-policy-parameter) | Independent approval as a policy parameter | Implemented |
| [021](#adr-021-security-controls-applied-and-the-ones-deferred-on-record) | Security controls applied, and the ones deferred on record | Implemented |
| [022](#adr-022-level-2-and-3-gates-run-inside-the-promotion-pipeline-not-reactively) | Level 2 and 3 gates run inside the promotion pipeline, not reactively | Implemented |

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

## ADR-013 Semantic versioning for services and modules

**Status:** Accepted.

**Context.** Every image the five service pipelines publish is identified only by `sha-<short-sha>`. That answers *which source* but not *which release*: nobody can say which release of a service development runs, or tell a fix from a breaking change by looking at a tag. Module releases in `docket-terraform-modules` are semantic, but each tag is cut by hand, and the release-please workflow written to automate it has never run, because the organisation does not let Actions open pull requests. Three later cards need a version to act on: release notes attach to one (card `24`), promotion moves one between environments (card `23`), and the first production release has to name the one it shipped (card `27`).

Conventional Commits were adopted from the start precisely so this could be automated: `AGENTS.md` §5 already maps `feat` to a minor bump, `fix` and `perf` to a patch, and `!` or a `BREAKING CHANGE` footer to a major.

**Decision.** Two mechanisms, because services and modules are released differently.

| | Services | Modules |
|---|---|---|
| What a release is | Every image the pipeline publishes | A deliberate release, approved as a pull request |
| Unit | One version per service, each with its own history | One version for the repository, as ADR-012 already set |
| Calculated | At merge, in `service-ci`, before the build | By release-please, from the commits since the last tag |
| Bump | Major, minor or patch from the commits since the last tag; **any other commit that publishes an image still bumps the patch** | Only `feat`, `fix`, `perf` and breaking changes touching `modules/` produce a release |
| First version | `1.0.0` | Continues from `v3.0.0` |
| Git tag | `vX.Y.Z` on the merge commit, created after the image is in the registry | `vX.Y.Z`, created by merging the release pull request |
| Artifact | The image tagged `X.Y.Z` and `sha-<short-sha>`, with `org.opencontainers.image.version` and `org.opencontainers.image.revision` labels | The tag itself, pinned by stacks as `?ref=vX.Y.Z` |
| Deployment | `newTag: X.Y.Z` in `docket-gitops`, written by the pipeline for development | Renovate proposes the `?ref=` bump per environment, never production; a person plans and applies |

Service repositories merge by squash only, and the squash commit takes the pull request title, which `pr-conventions` validates. That makes the commit a merge puts on `main` the one input the version is read from.

`AGENTS.md` §8 rule 5 allows a semantic version as an image tag. It is as fixed as a `sha-` tag only because ECR tags are immutable.

**Why every publication gets a version.** A merge of a `ci:` or `chore:` change still builds and deploys a new image to development. Leaving it without a version would put an image in the registry and in a running environment that can only be identified by hash, which is the ambiguity this decision exists to remove.

**Consequences.**
- A deployment reads as a release. Argo CD shows `1.4.0`, and a promotion pull request reads `1.3.0 → 1.4.0` rather than two hashes. The sha still travels in the image label and in the deploy commit message.
- Service versions climb fast in development, because every publication counts. No pre-release suffix distinguishes them; the version is what development runs, and staging and production only see it once promoted.
- A version can never mean two images. If `X.Y.Z` already exists in the registry for a different commit, the run fails and names both commits instead of skipping the push. Runs on `main` queue rather than cancel one another, so a publication is never left half done.
- Service tags live in private repositories, which cannot be protected on the current GitHub plan. The immutable registry tag is the backstop: a moved Git tag cannot change what the version deploys. Module tags stay protected by the *Immutable version tags* ruleset.
- Enabling release-please required the organisation setting that lets Actions create **and approve** pull requests. No workflow approves today; if one ever did, it could satisfy the one-approval rule on the two public repositories, the only ones with branch protection.
- The module release pull request is opened with the workflow token, so no workflow runs on it. It touches only the changelog and the manifest, and its title is fixed by configuration.
- ECR keeps the last ten images per repository. Once staging or production pin an older version, it can be pruned. Nothing pins one yet; card `23` introduces the first long-lived pin and has to address retention.
- Release notes are card `24`. release-please writes a changelog for modules as a side effect; its format is not settled here. *Settled by [ADR-019](#adr-019-release-notes).*

**Rejected alternatives.**

*release-please for services.* The image reaches development at merge, before any release pull request exists, so every deployment between two releases would carry only a hash.

*semantic-release.* It brings a Node toolchain into Go, Java and Python repositories, and it tags at the end of its run, so the version needed before the build could only be read by scraping a dry run.

*A third-party versioning action in the service pipeline.* The job that calculates the version also holds the build role, the `docket-gitops` App key and a token that can push tags. The rule is three patterns and a default; a short script in the repository, with its test, keeps third-party code out of that job. The project has already carried one compromised action.

*Reserving the version with a Git tag before the build.* A build or scan that fails afterwards leaves a version with no image. Publishing first means the worst case is an image whose commit is not yet tagged, and the next run stops on the collision rather than deploying the wrong bytes.

*Keeping `sha-` in `newTag` and carrying the version only in labels and commit messages.* No change to `AGENTS.md`, but every deployment and every promotion would still read as a hash.

*A dedicated GitHub App to open module release pull requests.* Scoped to one repository, and checks would run on its pull requests. Rejected as a new credential to create, store and rotate for a pull request that changes only release files.

*Tagging modules at merge, as services do.* No organisation setting to change, but a module release would stop being a separate decision, and every `fix` merge would send Renovate bump pull requests to every stack.

---

## ADR-014 Promotion between environments

**Status:** Implemented.

**Context.** Development receives a new version on every merge, written by the service pipeline (ADR-013). Nothing moved a version anywhere else: staging sat for a week on images nobody promoted, and one of them was pruned from the registry while staging still declared it, so the next cluster start would have failed. The deliverables ask for controlled promotion by updating the version reference in the manifest repository, and `AGENTS.md` §9.5 gates each transition on tests that do not exist yet (cards 16 and 17).

**Decision.** A version moves between environments only as a reviewed change to `newTag`, and every such change is checked, whoever writes it.

| Piece | Where | What it does |
|---|---|---|
| `promote` | `docket-gitops`, run by hand | Takes a target and a set of services, refuses what the rules reject, edits `newTag`, and opens the pull request as the `docket-gitops-writer` App so checks run on it |
| `gitops-ci` | `docket-gitops`, every pull request touching the manifests | The environments render; each moved image exists in ECR; a version reaching staging was declared by development first, one reaching production by staging, read from the base of the pull request; the verify gate |
| Pin | `docket-gitops`, after a merge to staging or production | Adds `promoted-<environment>-<tag>` to each declared image, writing its own manifest back so the digest cannot change |
| Retention | `registry` module | A first lifecycle rule keeps the last 20 images carrying `promoted-`; the last ten of the rest are kept as before |
| Identity | `ci-identity` module | A read role for the manifests repository, trusted for its pull requests and `main`, `ecr:DescribeImages` only; a pin role trusted for `main` only, `BatchGetImage`, `DescribeImages`, `PutImage` |

A promotion moves services, not environments: each service at its own version, so one held-back service never blocks the others and each can be reverted alone. The same flow serves development to staging and staging to production; production additionally needs its designated approver and a manual sync (cards 25 to 27).

**The verify gate is reserved, not enforced.** The contract is fixed now: `verify` (cards 16 and 17) sets a commit status named `verify` on the commit in `docket-gitops` that deployed a version to an environment. `gitops-ci` reads it on the source environment's deploy commit. Absent or pending, the check passes with a visible warning; failed, it blocks. Promotion shipped with human review as the control rather than waiting for the suites.

**Consequences.**
- There is no side door. A hand-edited pull request meets the same rules as one the workflow opens; one moving staging to a tag development never declared was refused on the order rule alone.
- A promoted image outlives any number of development publications. A lifecycle preview with a deliberately tight rule kept the pinned image, the oldest in its repository, while expiring five newer unpinned ones.
- Only the references a pull request moves are checked. Production still declares an image pruned before this decision; card 26 will meet it rather than every unrelated pull request.
- Rollback is a revert of the promotion's commit in `docket-gitops`, never a rollback in the Argo CD interface, which self-heal would undo. The reverted-to image is still in the registry because it was pinned.
- Enforcing the review depends on branch protection, unavailable for the private manifests repository on the current GitHub plan (card 39).

**Rejected alternatives.**

*Keeping more images of every kind instead of pinning.* No write access needed, but it only postpones the failure staging had, and at around 90 MB an image for users-api, 50 versions is several gigabytes that still do not guarantee anything.

*Checking every declared reference on every pull request.* Would fail every unrelated change until production is fixed, which teaches the team to ignore the check.

*Reading the source environment's health from Argo CD.* Needs an Argo CD credential in CI, where no pipeline holds cluster access. The manifest history is the record that a version was deployed.

*Opening the pull request with the workflow token.* A pull request opened by `GITHUB_TOKEN` starts no workflow, so the checks would never run on the pull requests that most need them.

*Giving the manifests repository the build role.* It would gain push access to every image repository. Reading and tagging are two roles because IAM can only separate a pull request from `main` in the trust policy.

*Waiting for the verify pipeline before shipping promotion.* Would have left staging unpromoted, and one image already pruned, for as long as cards 16 and 17 take.

---

## ADR-015 Staging shares the non-production load balancer

**Status:** Implemented.

**Context.** Card 22 exposes staging so a person can reach it and the end-to-end suite of card 17 has somewhere to run. Every exposed environment costs an Application Load Balancer, roughly 0.18 USD per eight-hour working day on top of the environment, and the manifests repository left the choice between one per environment and a shared one explicitly to cards 22 and 26.

**Decision.** Development and staging join the `docket-non-production` ingress group, so the AWS Load Balancer Controller serves both hosts from one load balancer, with development's rules ordered first. Production does not join it and will have its own when card 26 exposes it. The group is named for what it is not, so adding production to it reads as wrong on sight.

**Consequences.**
- Exposing staging cost nothing extra; the listener routes by host to each namespace's own target groups, and neither host reaches the other environment.
- Development and staging share a front door: a misconfiguration of the load balancer, or its deletion, takes both down together. Accepted for two environments without users.
- Joining the group replaced development's own load balancer, leaving it unreachable for a few minutes while DNS followed. A revert does the same in the other direction.
- Staging is public, with the same controls as development: fail-closed JWT and its own `ALLOWED_USERS` from its secret prefix.

**Rejected alternatives.**

*One load balancer per environment.* Full isolation of the front door, at a cost the brief's budget does not justify for an environment with no users.

*One load balancer for all three.* Would put production's access logs, certificate listener and single point of failure together with two environments people break on purpose.

**Mechanism superseded by [ADR-017](#adr-017-exposure-through-the-gateway-api).** The ingress group and its ordering annotations are replaced by one Gateway whose HTTPS listener accepts routes from `dev` and `staging`. The decision above stands.

---

## ADR-016 Production approval without branch protection

**Status:** Implemented. The approval rule is amended by [ADR-020](#adr-020-independent-approval-as-a-policy-parameter).

**Context.** `environments.md` sets the boundary for production: a change is declared by a pull request approved by a designated owner, and applied by a person's manual sync. Card 25 asks for the policy behind it, with named approvers, and for a flow that is demonstrable and auditable. Four facts shaped it. The manifests repository is private and the organisation is on GitHub's free plan, so branch protection, rulesets and required reviewers are unavailable (card 39) and anyone with write access can merge. Argo CD is reached with one shared account, so a sync names no person. Every document said "its designated approver" and named nobody. And five merged pull requests had already changed what production renders with no approval at all.

**Decision.** Because approval cannot be enforced, it is checked before the merge, audited after it, and reported when broken. Every piece lives in the manifests repository except the sync notice.

| Piece | Where | What it does |
|---|---|---|
| Approver list | A `production-policy` section at the end of the manifests repository's `CODEOWNERS` | The paths that change what production renders (its environment, its overlays, every base, its Argo CD `Application`) and the policy's own files, each with its approvers. The only list: narrowing it is editing those lines |
| Approval status | `production-approval`, on every pull request and review | The commit status `production-approval` on the head commit. Valid: the latest review of an approver who is neither the author nor the person who requested the promotion, on the commit being merged, not withdrawn. Rules are read from `main` |
| Audit | The same workflow, on every push to `main`, on demand, and on a retrospective approval | A production change with no pull request, no valid approval, or merged by someone who is not an approver is a violation: failure status on the commit, a comment on the pull request, a message to the alerts channel |
| Sync notice | Argo CD notifications, `platform` stack | Once per finished production sync, with the revision and the time |
| Sync record | `production-sync-record`, run by the person who synced | Comments on every pull request the sync applied since the last record, and sets the commit status `production-sync` on the revision. A sync by someone who is not an approver is recorded as a failure and reported |
| Manual sync guard | `gitops-ci` | Refuses a production `Application` that declares automated sync |

One approval is enough. Today the approvers are the four team members; the policy document in the manifests repository names them and gives the steps to narrow the list. The same list decides who may merge and who may sync.

An emergency change, labelled as one, may merge without a prior approval. Its audit reports the violation; a comment starting `Retrospective approval:` by another approver within one working day runs the audit again and clears it.

**Consequences.**
- Every production change carries a recorded verdict on its merge commit. The first real audit reported the pull request that introduced the audit, merged without an approval.
- Nothing blocks a merge. A violation reaches the cluster only when someone syncs, and the alert reaches the team first.
- The verdict is a commit status, not a job result: GitHub keeps one check per triggering event, so a job that failed when a pull request opened would stay red beside the green one from its approval.
- A change cannot approve itself by editing the list or the script, because both are read from `main` before the merge and from the parent commit after it. The workflow file itself comes from the pull request, so a change that weakens the audit is audited by its own version; auditing the commit again from `main` catches it.
- Who synced depends on a person running the record. The Argo CD notice makes an unrecorded sync visible. Per-person access to Argo CD is card 19.
- The requester of a promotion is a marker in the pull request body, which can be edited.
- Narrowing the list narrows approving, merging and syncing, not repository permissions.
- The retrospective approval is a comment because GitHub documents no way to approve a pull request after it merges. A working day skips weekends; public holidays count.
- A reviewer whose access came only through a team could not approve, and was given direct access; one team member's approval is still refused on the private repository with an error about explicit access, unresolved.

**Rejected alternatives.**

*A paid plan with branch protection.* It would enforce reviews and code owners, at a recurring cost the project does not carry. The `CODEOWNERS` section is written so GitHub would enforce it as it stands if that changes.

*Making the manifests repository public to get protection.* Its manifests carry the registry address, which includes the account identifier.

*A separate approvers file.* Two lists to keep in step, and not the one GitHub reads.

*A team as the approver.* The workflow token cannot read team membership, so a team would count as nobody.

*A bot that reverts an unapproved merge.* An automated write to production's declared state with no person deciding, and one that would fight an emergency fix.

*Auditing only after the merge.* Nothing would be visible while the pull request is open.

*Argo CD's GitHub notifier writing the sync status.* A GitHub credential inside the cluster, and the status would still name the shared account.

---

## ADR-017 Exposure through the Gateway API

**Status:** Implemented.

**Context.** Development and staging were exposed through one `Ingress` per environment, joined into the `docket-non-production` ingress group (ADR-015), with HTTPS from an ACM certificate found by host (ADR-008) and DNS written by external-dns. The Ingress API is frozen, and the Kubernetes project points to the Gateway API as its successor; the course asked for the refactor, with what the Gateway API needs installed with Helm. Two cards were about to build on the entry point, health checks (card 20) and production's exposure (card 26). The AWS Load Balancer Controller the platform already runs implements the Gateway API on an ALB, and its `v3.5.0` is built for Gateway API `v1.6.0`. Its chart installs the controller's own Gateway CRDs, but not the standard ones, and the Gateway API project publishes those only as a manifest.

**Decision.** Exposure moves to the Gateway API on the same controller, and its pieces are split by who decides them.

| Piece | Where | Decides |
|---|---|---|
| Standard CRDs, Gateway API `v1.6.0` | A local chart in the platform stack carrying the upstream manifest unmodified in `crds/`, installed with Helm before the controller | The API version, the one the controller is built for |
| Controller feature gates | The controller's Helm values | ALB gateway on; layer 4 gateway and listener sets off |
| `GatewayClass docket-alb` and its class configuration | A second local chart, installed after the controller | What every load balancer shares: internet-facing, IP targets |
| `Gateway docket-non-production` | The manifests repository, in a `gateway` namespace, with an Argo CD Application of its own | That development and staging share one load balancer, its listeners, and which namespaces may attach: `dev` and `staging` only |
| `HTTPRoute docket` per environment | The manifests repository, one overlay per environment | The host and the path split |
| DNS | external-dns reads the `gateway-httproute` source | Records from route hostnames |

ADR-015's decision stands: development and staging share one load balancer, and production gets its own. Its mechanism, the ingress group, is replaced by one Gateway with an HTTPS listener open to both namespaces.

**Consequences.**
- The CRDs must exist before the controller starts, or its Gateway support stays off; Terraform orders the releases.
- Helm never upgrades or deletes `crds/`. A failed release cannot delete every Gateway and route, and a version change reaches the cluster on its next start, which recreates it.
- The controller defaults would give an internal load balancer and node-port targets; the class configuration sets both, as the Ingress annotations did.
- The certificate is still discovered from hostnames; the controller does not support `certificateRefs`, so no certificate appears in any manifest.
- The HTTP to HTTPS redirect is a route on the Gateway's HTTP listener, and the controller orders listener rules by path length, so no ordering annotations remain.
- Production cannot attach to the shared Gateway: its HTTPS listener selects namespaces by the name label Kubernetes maintains.
- The teardown deletes Gateways and routes while the controller is alive, so its finalizer removes the load balancer before the cluster is destroyed.
- Health checks still use the controller's defaults, as they did; card 20 sets them through `TargetGroupConfiguration`.
- The manifest in the local chart is 1.2 MB, vendored by hand; changing the version is replacing that file and its recorded checksum.

**Rejected alternatives.**

*Keeping the Ingress.* It works, but the next two cards would each have been written twice.

*A community chart, or another implementation's chart, for the CRDs.* A third party between the Gateway API project and the cluster, or a second implementation's naming and versioning in a cluster that does not run it.

*`kubectl apply` in the start workflow, or `kubernetes_manifest`.* Not Helm, and the second needs the CRDs to exist at plan time.

*Everything in the platform stack.* Exposure would change through `terraform apply` instead of a reviewed manifest, and card 26 would add production's Gateway to Terraform.

*Everything in the manifests repository.* The class would depend on an Argo CD Application instead of being installed with the controller.

*The shared Gateway in the `dev` namespace.* Staging's exposure would depend on development's Application.

*Another Gateway API implementation.* A second controller in front of the same ALBs the current one already manages.

---

## ADR-018 Production's Argo CD project, gateway and restore on start

**Status:** Implemented.

**Context.** Card 26 provisions production before its first release (card 27). Production was declared in the manifests repository and had never run: its Application sat in Argo CD's `default` project, which lets an Application deploy anything anywhere, and it had no exposure of its own, since the non-production gateway refuses routes from `prod` (ADR-017) and ADR-015 gives production its own load balancer. The cluster is recreated on every start, and the course requires a manual sync policy on the production Application, so production would start empty after every start until someone synced it again. Per-person Argo CD access (card 19) and metrics and alerts (card 20) were not done; the team lead decided to go ahead and state those gaps.

**Decision.**

| Piece | Where | What it does |
|---|---|---|
| Production's gateway | The manifests repository, in the `prod` namespace, inside production's own Application | `Gateway docket-production` of the `docket-alb` class, its own load balancer, listeners accepting routes from `prod` only, the redirect to HTTPS; the route for production's host |
| Argo CD project `production` | The manifests repository, created by the root Application a sync wave before the Applications | Source: the manifests repository only; destination: the `prod` namespace only; no cluster-scoped object; only the kinds production renders |
| Pipeline guards | The manifests repository's CI | Refuse a production Application outside the project, a project with a cluster-scoped entry or a second destination, and a rendered kind the project does not list |
| Release marker | The production sync record workflow | Moves the tag `production` to the revision an approver synced and recorded |
| Restore on start | The start workflow in the infrastructure repository | Reads that tag over SSH with the read-only deploy key Argo CD uses, and asks Argo CD to sync production to exactly that commit; no tag, no action; never fails the start |

The production Application keeps its manual sync policy. The restore re-applies a release already approved and recorded; a change merged and not yet synced still waits for a person.

**Consequences.**
- One Application declares everything production is, so its first sync brings up the load balancer, the DNS record and the workloads as one approved, recorded act.
- Production and non-production Applications never write to the same namespace.
- A new kind in a production manifest is refused by the pipeline before a release, not by Argo CD during one.
- After every start, production runs its last release within minutes, with no one syncing; before the first release it stays empty.
- The start workflow now reads a credential, the deploy key, which was already in SSM and read by Terraform.
- The tag can be moved by hand by anyone with write access to the manifests repository; the revision it names carries a `production-sync` status to check.
- Who may sync production is still not enforced in Argo CD (card 19), and production has no metrics or alerts (card 20).

**Rejected alternatives.**

*Automated sync pinned to a released commit.* Restores itself on every start, but breaks the course requirement of a manual sync policy on the production Application and `AGENTS.md` section 8.

*Production's gateway in the shared `gateway` namespace with an Application of its own.* Two Applications to sync for one release, and a production project allowed into a namespace non-production also writes to.

*A project that restricts destinations only.* A production manifest could still create any namespaced kind, a Role or a LoadBalancer Service among them.

*A GitHub token in the infrastructure repository to read the sync statuses.* A new credential for information the tag already carries.

*Syncing on start what `main` declares.* Applies a production change that was merged and never synced, which the policy leaves to a person, and brings production up before its first release.

---

## ADR-019 Release notes

**Status:** Implemented.

**Context.** Every service publishes a semantic version on merge and tags its commit (ADR-013), but nothing said what a version contains: the five service repositories had tags and no release notes. Modules already had GitHub Releases from release-please, grouped by type, without the roadmap card. The first production release (card 27) has to name what it ships, and card 24 asks for notes per release, linked to the published version, with changes, fixes and references to the work, in a consistent format. The team lead decided that a release is both a service version and a production release, which consolidates the notes of the versions it moves. The promotion workflow runs in the manifests repository, which holds no credential to read the private service repositories.

**Decision.**

| Piece | Where | What it does |
|---|---|---|
| Notes of a version | `release-notes.sh`, identical in the five service repositories, with a test suite | Reads the first-parent commits since the previous version tag and prints *Features*, *Fixes* and *Other changes* by Conventional Commit type; each entry links its pull request, its commit and every roadmap card its `Refs:` lines name; then the image, without the registry host, and a comparison with the previous version |
| Publication | The pipeline's image job, right after the version tag | A GitHub Release on the tag with those notes, and a copy in the manifests repository, `releases/<service>/<version>.md`, in the same commit that deploys the version to development |
| Existing versions | The same pipeline, dispatched with a tag | Publishes or regenerates the notes of a version without building anything |
| Consolidation | The promotion workflow in the manifests repository | A promotion to production embeds the notes of every version it moves; a promotion to staging links each release |
| Modules | release-please, unchanged | Their existing releases stand |

**Consequences.**
- Every service version has notes the moment it exists, and every production release pull request carries what it changes, next to its approval status and sync record (ADR-016).
- The copy in the manifests repository needs no new credential: the write that deploys a version already carries its notes.
- A card reference written as `#N` in a service repository would link that repository's issue; the notes rewrite it to the roadmap card.
- Five copies of the same script can drift, the same debt the version script already carries; their checksums are compared when they change.
- A correction changes two copies, the release and the file in the manifests repository.
- Module notes still do not name the roadmap card.

**Rejected alternatives.**

*release-please for services.* It versions by merging a release pull request, which ADR-013 rejected for services.

*GitHub's generated release notes.* They group by pull request labels the project does not use and cannot rewrite card references.

*Granting the promotion workflow read access to the service repositories.* A permission change on an organisation App for information the existing deployment write already carries.

*Links only in the production pull request.* Consolidates nothing a reviewer can read in place.

---

## ADR-020 Independent approval as a policy parameter

**Status:** Implemented. Amends the approval rule of [ADR-016](#adr-016-production-approval-without-branch-protection).

**Context.** ADR-016 counts an approval of a production change only from a named approver who is neither the pull request's author nor the person who requested the promotion. Card 27 runs the first release to production while one team member is available and the other approvers are not, so under that rule every release would be a recorded violation, and a policy violated on every use tells an auditor nothing. GitHub already refuses a review from a pull request's author. Promotions are opened by the manifests repository's App, so the person who requests one is not its author and GitHub lets them review it. The team lead decided that, for now, the requester may approve, and asked for the stricter rule to stay one documented change away.

**Decision.** Independence becomes a parameter of the policy, in the same place as the approvers.

| Piece | Where | What it does |
|---|---|---|
| The parameter | A line `independent-approval=<value>` inside the `production-policy` section of the manifests repository's `CODEOWNERS` | `required`: the approver is neither the author nor the requester, ADR-016's rule. `not-required`: the approver is not the author. Set to `not-required` |
| Default | The approval rules | Without the line, `required`. A different value, the line twice, or the line outside the section fails the check instead of being guessed |
| Mode in force | The approval check and the audit | Read, like the approvers, from `main` before the merge and from the parent commit after it. Rules older than the parameter are applied as written, which required independence |
| Emergency path | The retrospective approval | `required`: an approver who is not the author, the requester or the merger. `not-required`: an approver who is not the author |
| Visibility | The `production-approval` status and the audit comment | An approval that counted only because of the mode is `success`, and names the requester or merger it came from |

Every named approver stays an approver, and the merge must still be made by one. The policy document in the manifests repository says why the value is `not-required`, how to set it to `required`, and when the team should.

**Consequences.**
- One person can request, approve, merge and sync a production promotion. Each such approval is named where it is recorded, so non-independent approvals can be told from independent ones and from violations.
- Requiring an independent approver again is one line in a pull request. That pull request is a production change judged with the value still on `main`, so it cannot relax its own check, and a change that sets `not-required` cannot either.
- The author is excluded in both modes. A pull request written by a person still needs another approver, and an emergency change cannot be written, merged and approved by one person.
- A copy of the section without the line is strict, not permissive.
- Separation of duties is not evidenced while the value is `not-required`; the policy's known limits say so.

**Rejected alternatives.**

*A repository variable.* Changing it leaves no pull request, no approval and no line in the history, the opposite of what ADR-016 guarantees for the approver list.

*No parameter, recording every release as a violation.* The audit would report the normal path as broken, and a real violation would look like every other release.

*Removing every exclusion, the author included.* GitHub would still refuse the review, and the retrospective comment would let one person write, merge and clear an emergency change.

*Default `not-required` when the line is missing.* Forgetting the line would silently relax the policy.

---

## ADR-021 Security controls applied, and the ones deferred on record

**Status:** Implemented.

**Context.** Card 19 asks for the technical security minimums: permissions, basic policies, separation by environment and a smaller risk surface. Three cards had already ended with the same gaps written on their own board comment and nowhere else: the deployment tool is reached with one shared account, so a production sync is recorded rather than restricted; the people who run the project hold full administrator in the cloud account; and the controls that do exist had never been listed in one place. The team is three students on course credits, with a free plan that offers no branch protection on private repositories, and production had just gone live. Closing the two large gaps means identities in the deployment tool and a split of cloud administration, each a migration with its own rehearsal.

**Decision.** State the minimum for every identity, apply only what is cheap and cannot break the delivery flow, and record the rest as accepted risk rather than leaving it implied.

| Piece | Where | What it holds |
|---|---|---|
| The record | A document in the private infrastructure repository | Per identity: what it can do today, what it needs, and the gap. Pipelines, repositories and people, deployments, cluster and deployment tool, namespaces and workloads |
| The enforcement design | The same document | How per-person access and a role that grants the production sync only to the approvers would work, so the migration is a decision, not a study |
| The register | The same document | One row per accepted risk: the reason, the impact if the judgement is wrong, what would close it, and the open card that owns the work when one does |
| The re-check | The same document | A read-only command per claim, none of which prints a secret; when the command and the record disagree, the command is right |
| The applied change | The development environment's application credentials | Rotated away from the values published by the upstream project this fork came from |

The record is private because it names people, roles and paths; this decision is the public half.

**Consequences.**
- A gap is now a row with a reason and an impact instead of a sentence in an old board comment; the delivery comments of the three cards are folded into it.
- The team can tell an accepted risk from an overlooked one, which is what an evaluator, or the next person, needs.
- The controls that already existed are visible: per-repository image push, deployment credentials scoped to one repository, secrets read per environment through workload identity, a namespace per environment with its quota, network policy and a role without a shell into production's pods, and workloads that run unprivileged.
- Nothing enforces the production sync rule yet, so the sync record and the notices stay the only trail of who changed production.
- The broad deploy policy stays until a full lifecycle can be exercised against the scoped candidate; without an audit trail that evidence cannot be collected.
- A permission changed without updating the record makes the record wrong. The re-check commands are the defence, and the rule that the same pull request updates both.

**Rejected alternatives.**

*Applying per-person access to the deployment tool now.* It needs identities or an identity provider, a role policy, and a rehearsal on a cluster start, in the same week the first production release happened.

*Splitting cloud administration now.* The team granted itself administrator to unblock its own work; a narrower set would be re-granted the first time it blocks someone before a deadline, which teaches the wrong lesson about controls.

*Attaching the scoped deploy policy without evidence.* A missing action appears during destroy paths, not during a plan, so it can stop a recovery halfway.

*Raising the pod admission level to the strictest one.* The application workloads already satisfy it, but the cache does not and would be rejected, taking the environments down.

*Leaving the gaps in the board comments.* They were scattered across three cards, each stating a subset, and nothing said whether a gap was accepted or forgotten.

---

## ADR-022 Level 2 and 3 gates run inside the promotion pipeline, not reactively

**Status:** Implemented.

**Context.** ADR-014 fixed how a version becomes promotable: a commit status named `verify` on the `docket-gitops` commit that deployed it, which `gitops-ci` reads before letting a promotion proceed. The original design behind that contract, in `pipelines.md`'s `verify` pipeline, was reactive — triggered by Argo CD reporting `development` Synced and Healthy, running the integration and end-to-end suites against it, and writing the status from there. Nobody ever built the trigger. Every gate this project has run — cards 22, 23, 25, 26, 27 among them — was a person running the level 3 suite by hand and pasting its result into a pull request comment. The suites themselves need no cluster or cloud credential: they drive a browser against a deployed environment's public host, exactly what a person did. The reactive trigger would have needed one anyway — Argo CD's only notification target is a Slack webhook, and reaching GitHub Actions from inside the cluster means a GitHub credential living there, a category this project's every other pipeline was built to avoid. The cards that owned this work, 16 and 17, sat assigned to a team member with no commits or pull requests in any repository of the project.

**Decision.** The gate runs synchronously, inside the pipeline that already asks for a promotion, instead of reacting to a deployment.

| Piece | Where | What it does |
|---|---|---|
| The `verify` job | `docket-gitops`, inside `promote.yml` | Before anything is written, runs the level 3 suite in the pinned Playwright image against the promotion's source environment: the smoke suite for a staging promotion, the full suite for a production one |
| The status write | The same workflow, the `promote` job | Writes the `verify` commit status on every service's deploy commit from the gate's result, before `newTag` is touched or a pull request opens |
| The block | `promote.yml`, and `promotion-order.sh`'s `cmd_gate` | A failed gate stops the run before any pull request exists; `cmd_gate` now fails on any status but `success`, absent and pending included, since something writes one from here on |
| The evidence | A `Gate evidence:` comment on the promotion pull request | The same format a person wrote by hand all session, generated instead of pasted |
| Level 2's own criterion | No new code | `service-ci`'s `image` job already needs `test`, so a version cannot reach `docket-gitops` without level 1 and level 2 passing for that exact commit — "the pipeline blocks promotion" for level 2 was already true by construction |

Credentials for the suite — three pairs, one per source environment level 3 gates, plus the second account the full suite's isolation scenario needs — are read directly from repository secrets into the run step's environment, never through a step output, so they are never retrievable from a run's API even once GitHub masks them in its log.

**Consequences.**
- The gate that ADR-014 designed for now has a writer. `gitops-ci`'s read of `verify` needs no change: it already computes the same deploy commit independently and finds the status already set by the time a promotion pull request exists.
- No new credential surface was opened. The suite still only ever talks to a public HTTPS host.
- A promotion moving several services together is verified once, as one environment, and every service in that batch carries the same verdict — the suite exercises the whole stack, not one service in isolation, so re-running it per service would test nothing new.
- `cmd_gate`'s tightening applies to every future promotion from the moment it merges, not only the ones this card cares about; the six credentials it depends on have to exist before the first promotion after that, or every promotion fails outright until they do.
- The reactive design `pipelines.md` originally sketched is superseded, not merely unbuilt; the document is rewritten to describe what actually runs.

**Rejected alternatives.**

*The original reactive trigger, from Argo CD reporting `development` Healthy.* Needed a new notification target and a GitHub credential inside the cluster for information the pipeline can get by driving the same public host a person already used.

*A combined JSON secret for all environments' credentials.* Harder to rotate one environment's accounts independently, and puts every environment's credentials in one payload.

*Re-checking level 1 and level 2 from `docket-gitops` for each promotion.* Would need read access into five more private repositories for a fact the job graph already guarantees — a version cannot exist in `docket-gitops` without having passed `test` for that exact commit.

*Passing suite credentials through a step output.* An output is visible from a workflow run's API in cleartext, independent of the masking applied to logs; reading secrets straight into an `env:` block at the point of use avoids that entirely.

---

## Open assumptions

Statements this design takes as true and worth resolving before or during the Terraform work.

**Cluster capacity.** The sizing to 2 nodes comes from the pod count and the limit the EKS CNI imposes, without validation under real load. If it turns out to be insufficient, the available way out is reducing how many environments run simultaneously, because the budget does not allow larger nodes.

**Instance type is constrained by the free plan, not only by capacity.** The account only allows launching free-tier-eligible instance types. A type outside that list fails silently, with the error visible only in CloudTrail. The implementation uses `m7i-flex.large`.

**Only production requires manual approval.** It is assumed that promotion from `dev` to `staging` can be automatic after the pull request review. To be confirmed when the area 04 pipelines are defined. *Resolved by [ADR-014](#adr-014-promotion-between-environments): staging syncs automatically once a reviewed promotion pull request merges; production also needs a manual sync.*

**Observability starts from an existing base.** `auth-api` already includes Zipkin tracing instrumentation and the frontend already sends spans. Area 07 extends that starting point.

**The GitOps manifest repository now exists.** `docket-gitops` holds the Argo CD `Application` for development, targeting the `dev` namespace on EKS. Only Redis has manifests so far; the five services have none, which is what blocks the first deployment through GitOps.
