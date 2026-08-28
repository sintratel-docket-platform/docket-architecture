# Decisiones arquitectónicas y supuestos

Por qué la arquitectura es como es. Cada decisión incluye la alternativa que se descartó, porque saber qué se rechazó y por qué evita volver a discutirlo más adelante.

Las decisiones sostienen [`logica.md`](logica.md) y [`ambientes.md`](ambientes.md).


## 1. Registry: GitHub Container Registry

Es gratuito para los repositorios de la organización, se integra de forma nativa con GitHub Actions (la herramienta de integración continua del proyecto) y hereda el control de acceso de los permisos de la organización, sin gestionar credenciales aparte.

*Alternativa descartada:* Amazon ECR o Docker Hub. Ambos añaden una cuenta y un juego de credenciales adicionales sin resolver ningún problema que GHCR no resuelva ya en este contexto.

## 2. Gestión de secretos: Bitnami Sealed Secrets

Permite versionar los secretos cifrados dentro del repositorio de manifiestos sin romper el flujo declarativo de forma que el estado completo sigue estando en Git y Argo CD lo sincroniza sin excepciones.

*Alternativa descartada:* que la pipeline inyecte los secretos directamente en el clúster, por fuera de Argo CD. Funciona, pero abre un camino por el que el estado del clúster deja de estar descrito en Git, que es justamente lo que el flujo GitOps busca evitar.


## 3. Topología: un clúster compartido con tres namespaces

> **Supuesto, no decisión confirmada.** No ha sido validado. Si el
> equipo prefiere aislamiento físico entre ambientes, hay que revisarlo **antes**
> de que el área 02 escriba el Terraform que lo dé por sentado.

Un solo clúster de Kubernetes con los namespaces `dev`, `staging` y `prod`, cada uno con su RBAC y sus resource quotas.

*Razonamiento:* Un clúster único reduce la carga operativa. Namespaces con RBAC dan aislamiento lógico suficiente para lo que exige el criterio de aceptación, que además menciona "clúster/namespace" como una sola unidad. 

*Lo que se acepta a cambio:* no hay aislamiento a nivel de nodo ni de plano de control. Un incidente en el clúster afecta a los tres ambientes al mismo tiempo, incluida producción.

*Alternativa descartada:* un clúster por ambiente. Da aislamiento real y sería lo indicado si se exigiera separación física.

## Otros supuestos registrados

**La aplicación base no está contenerizada.** No existen Dockerfiles, `docker-compose` ni manifiestos de Kubernetes. Ambos diagramas son
prescriptivos. Es probable que haya ajustes cuando se implemente la infraestructura real.

**Solo producción exige aprobación manual.** Se asume que la promoción de `dev` a `staging` puede ser automática tras la revisión del pull request. Queda por confirmar al definir los pipelines.

**La observabilidad no parte de cero.** `auth-api` ya incluye instrumentación de tracing con Zipkin en `tracing.go`. El área 07 extiende ese punto de partida al resto de los servicios en lugar de introducir el tracing desde el principio.

**El repositorio de manifiestos GitOps todavía no existe.** Es la historia 06 del tablero, que depende de esta. Hasta que se cree, su estructura interna es una previsión.
