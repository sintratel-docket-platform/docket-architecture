# Docket architecture

Architecture documentation for **Docket**, the task management platform for a legal firm.

This repository is the documentation deliverable of the project. It holds the reference architecture the platform is built towards and the record of the decisions supporting it. It is the source from which the infrastructure-as-code work, the pipeline design and the platform operation derive.

## Start here

New to the project? [`project-walkthrough.md`](project-walkthrough.md) is the
narrative: the client's problem, what was built area by area, results with
evidence, limitations and a suggested reading order.
[`documentation-map.md`](documentation-map.md) is the index into every
document of every repository, organised by area.

## Documents

| Document | Contents | Status |
|---|---|---|
| [`project-walkthrough.md`](project-walkthrough.md) | The final presentation: the client's problem, what was built, results, limitations and coverage against the course brief. | Current |
| [`logical-architecture.md`](logical-architecture.md) | Logical architecture: the five microservices, the message queue, the call graph and the supporting platform. | Components verified against the code |
| [`environments.md`](environments.md) | Deployment per environment: namespaces, boundaries between `dev`, `staging` and `prod`, GitOps flow, secrets and DNS. | Current, describes what is deployed |
| [`aws-infrastructure.md`](aws-infrastructure.md) | Physical layer on AWS: budget, multi-AZ network, EKS, registry, state backend, identity and secrets. | Current, describes what is deployed |
| [`pipelines.md`](pipelines.md) | The ten pipelines, how they connect, the test pyramid and the promotion gate table. | Current |
| [`testing-strategy.md`](testing-strategy.md) | The three test levels, where and when each runs, current counts per service. | Current |
| [`decisions.md`](decisions.md) | Decision record (ADR) with context, consequences and rejected alternatives. | Current |
| [`project-retrospective.md`](project-retrospective.md) | ADRs grouped by theme, current limitations consolidated from four repositories, and a ranked improvement list. | Current |
| [`demo-runbook.md`](demo-runbook.md) | The technical demo script: order, commands, expected screens, timing and fallback plan. | Current |
| [`documentation-map.md`](documentation-map.md) | Index of every project document across the thirteen repositories, and which of the nine areas each answers. | Current |
| [`standards/`](standards/README.md) | The canonical engineering constitution, the long-form Terraform standard, the distributed templates and the branch-protection record. | Current |

## How to read this documentation

The three documents describe the same system at three levels, from the most abstract to the most concrete:

1. **`logical-architecture.md`**: which pieces exist and how they communicate, without going into where they run.
2. **`environments.md`**: how environments are separated inside Kubernetes and how a change advances to production.
3. **`aws-infrastructure.md`**: which AWS resources everything above runs on, and what it costs.

`decisions.md` cuts across all three. Every design statement in the others links to the ADR that justifies it.

## Conditions framing the design

| Condition | Value |
|---|---|
| AWS account | Free credit plan: 100 USD, extendable to 200 USD with 5 guided activities |
| Region | `us-east-1` |
| Operating mode | Ephemeral infrastructure, with routine `destroy` and `apply` |

These conditions determine [ADR-002](decisions.md#adr-002-secrets-with-external-secrets-and-ssm-parameter-store), [ADR-004](decisions.md#adr-004-compute-amazon-eks), [ADR-005](decisions.md#adr-005-multi-az-network-with-a-single-nat-gateway) and [ADR-010](decisions.md#adr-010-ephemeral-infrastructure-with-split-state).

## How to use this architecture

- **For infrastructure as code:** the budget, the network topology and the stack split are in `aws-infrastructure.md`. The namespace topology is in `environments.md`.
- **For the pipelines:** `environments.md` describes the promotion controls, and `aws-infrastructure.md` the infrastructure change flow and the credential model.
- **For operations:** `logical-architecture.md` describes what each service does and what it depends on. The other two describe where each thing runs and how it is reached.

## Diagrams

| Diagram | Image | Document explaining it | Editable source |
|---|---|---|---|
| Logical architecture | [`img/logical-architecture.png`](img/logical-architecture.png) | [`logical-architecture.md`](logical-architecture.md) | Lucidchart |
| Deployment per environment | [`img/environments.png`](img/environments.png) | [`environments.md`](environments.md) | Lucidchart |
| AWS infrastructure | [`img/aws-infrastructure.png`](img/aws-infrastructure.png) | [`aws-infrastructure.md`](aws-infrastructure.md) | Lucidchart |
| How the pipelines connect | [`img/pipeline-map.png`](img/pipeline-map.png) | [`pipelines.md`](pipelines.md) | Lucidchart |
| Commit to development | [`img/pipeline-commit-to-development.png`](img/pipeline-commit-to-development.png) | [`pipelines.md`](pipelines.md) | Lucidchart |
| Promotion to production | [`img/pipeline-promotion-to-production.png`](img/pipeline-promotion-to-production.png) | [`pipelines.md`](pipelines.md) | Lucidchart |
| Cluster lifecycle | [`img/pipeline-cluster-lifecycle.png`](img/pipeline-cluster-lifecycle.png) | [`pipelines.md`](pipelines.md) | Lucidchart |
| Module to live infrastructure | [`img/pipeline-module-to-infrastructure.png`](img/pipeline-module-to-infrastructure.png) | [`pipelines.md`](pipelines.md) | Lucidchart |
| Rollback | [`img/pipeline-rollback.png`](img/pipeline-rollback.png) | [`pipelines.md`](pipelines.md) | Lucidchart |

The PNGs in `img/` are the published version and travel with the repository. The editable source of each diagram lives in the tool indicated. When a diagram changes, the PNG must be re-exported under the same file name so the documents embedding it keep resolving.

**A diagram is documentation and goes stale the same way.** A review on 16 September 2026 found every diagram describing a state the platform had left behind. Only the pipeline map was re-exported then; the other eight were redrawn in Lucidchart and their PNGs never reached this repository. All nine were redrawn again and re-exported on 21 September 2026 against the platform as it runs. They show the Gateway API with two load balancers, CloudWatch observability with its alarms reaching Slack, the SonarQube gate and the HIGH and CRITICAL image gate in every service pipeline, the recorded production sync that the restore on start reads, and Renovate as pending work (card 52). The editable source lives outside the repository and never enters a pull request, so a change that alters what a diagram shows is not finished until its PNG is re-exported.

## Contributing

[`CONTRIBUTING.md`](CONTRIBUTING.md) is the short, repository-local form of
[`standards/AGENTS.md`](standards/AGENTS.md), which is normative. Pull
requests follow [`.github/pull_request_template.md`](.github/pull_request_template.md).
