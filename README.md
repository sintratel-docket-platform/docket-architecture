# Docket architecture

Architecture documentation for **Docket**, the task management platform for a legal firm.

This repository is the documentation deliverable of the project. It holds the reference architecture the platform is built towards and the record of the decisions supporting it. It is the source from which the infrastructure-as-code work, the pipeline design and the platform operation derive.

## Documents

| Document | Contents | Status |
|---|---|---|
| [`logical-architecture.md`](logical-architecture.md) | Logical architecture: the five microservices, the message queue, the call graph and the supporting platform. | Components verified against the code |
| [`environments.md`](environments.md) | Deployment per environment: namespaces, boundaries between `dev`, `staging` and `prod`, GitOps flow, secrets and DNS. | Target |
| [`aws-infrastructure.md`](aws-infrastructure.md) | Physical layer on AWS: budget, multi-AZ network, EKS, registry, state backend, identity and secrets. | Target |
| [`decisions.md`](decisions.md) | Decision record (ADR) with context, consequences and rejected alternatives. | Current |

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
| Logical architecture | [`img/logical-architecture.png`](img/logical-architecture.png) | [`logical-architecture.md`](logical-architecture.md) | Eraser |
| Deployment per environment | [`img/environments.png`](img/environments.png) | [`environments.md`](environments.md) | Eraser |
| AWS infrastructure | [`img/aws-infrastructure.png`](img/aws-infrastructure.png) | [`aws-infrastructure.md`](aws-infrastructure.md) | Lucidchart |

The PNGs in `img/` are the published version and travel with the repository. The editable source of each diagram lives in the tool indicated. When a diagram changes, the PNG must be re-exported under the same file name so the documents embedding it keep resolving.

> The diagrams are still labelled in Spanish. Re-exporting them in English is pending; it requires the editable sources in Eraser and Lucidchart, not just this repository.
