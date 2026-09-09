# Arquitectura de Docket

Documentación de arquitectura de **Docket**, la plataforma de gestión de tareas para una firma legal.

Este repositorio es el entregable de documentación del proyecto. Contiene la arquitectura de referencia hacia la que se construye y el registro de las decisiones que la sostienen. Es la fuente de la que derivan el trabajo de infraestructura como código, el diseño de las pipelines y la operación de la plataforma.


## Documentos

| Documento | Contenido | Estado |
|---|---|---|
| [`logical-architecture.md`](logical-architecture.md) | Arquitectura lógica: los cinco microservicios, la cola de mensajes, el grafo de llamadas y la plataforma de soporte. | Componentes verificados contra el código |
| [`environments.md`](environments.md) | Despliegue por ambiente: namespaces, límites entre `dev`, `staging` y `prod`, flujo GitOps, secretos y DNS. | Objetivo |
| [`aws-infrastructure.md`](aws-infrastructure.md) | Capa física en AWS: presupuesto, red multi-AZ, EKS, registry, backend de estado, identidad y secretos. | Objetivo |
| [`decisions.md`](decisions.md) | Registro de decisiones (ADR) con contexto, consecuencias y alternativas descartadas. | Vigente |

## Cómo leer esta documentación

Los tres documentos describen el mismo sistema en tres niveles, del más abstracto al más concreto:

1. **`logical-architecture.md`**: qué piezas hay y cómo se comunican, sin entrar en dónde corren.
2. **`environments.md`**: cómo se separan los ambientes dentro de Kubernetes y cómo avanza un cambio hasta producción.
3. **`aws-infrastructure.md`**: sobre qué recursos de AWS corre todo lo anterior y cuánto cuesta.

`decisions.md` es transversal. Cada afirmación de diseño en los otros tres enlaza al ADR que la justifica.

## Condiciones que enmarcan el diseño

| Condición | Valor |
|---|---|
| Cuenta AWS | Plan gratuito por créditos: 100 USD, ampliables a 200 USD con 5 actividades guiadas |
| Región | `us-east-1` |
| Modo de operación | Infraestructura efímera, con `destroy` y `apply` rutinarios |

Estas condiciones determinan [ADR-002](decisions.md#adr-002-secretos-con-external-secrets-y-ssm-parameter-store), [ADR-004](decisions.md#adr-004-cómputo-amazon-eks), [ADR-005](decisions.md#adr-005-red-multi-az-con-un-solo-nat-gateway) y [ADR-010](decisions.md#adr-010-infraestructura-efímera-con-estado-dividido).

## Cómo usar esta arquitectura

- **Para infraestructura como código:** el presupuesto, la topología de red y la división de stacks están en `aws-infrastructure.md`. La topología de namespaces está en `environments.md`.
- **Para las pipelines:** `environments.md` describe los controles de promoción, e `aws-infrastructure.md` el flujo de cambio de infraestructura y el modelo de credenciales.
- **Para operación:** `logical-architecture.md` describe qué hace cada servicio y de qué depende. Los otros dos describen dónde corre cada cosa y cómo se accede.

## Diagramas

| Diagrama | Imagen | Documento que lo explica | Fuente editable |
|---|---|---|---|
| Arquitectura lógica | [`img/logical-architecture.png`](img/logical-architecture.png) | [`logical-architecture.md`](logical-architecture.md) | Eraser |
| Despliegue por ambiente | [`img/environments.png`](img/environments.png) | [`environments.md`](environments.md) | Eraser |
| Infraestructura AWS | [`img/aws-infrastructure.png`](img/aws-infrastructure.png) | [`aws-infrastructure.md`](aws-infrastructure.md) | Lucidchart |

Los PNG de `img/` son la versión publicada y viajan con el repositorio. La fuente editable de cada diagrama vive en la herramienta indicada. Cuando se modifique un diagrama hay que reexportar el PNG conservando el mismo nombre de archivo, para que los documentos que lo embeben sigan resolviendo.
