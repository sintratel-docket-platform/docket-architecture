# Arquitectura de Docket

Arquitectura objetivo y mapa de ambientes de **Docket**, la plataforma de
gestión de tareas para una firma legal.

Este repositorio contiene la arquitectura **de referencia** del proyecto: la
meta hacia la que se construye, no una descripción de lo que ya está desplegado.
Sirve de base para el trabajo de infraestructura como código (Terraform y
Kubernetes), para el diseño de las pipelines de integración y despliegue
continuo, y para la operación de la plataforma.

Responde a la historia `02. Definir arquitectura objetivo y mapa de ambientes`
del tablero del equipo.

## Documentos

| Documento | Contenido |
|---|---|
| [`logica.md`](logica.md) | Arquitectura lógica de componentes: los cinco microservicios, la cola de mensajes y la plataforma de soporte (registry, pipelines y observabilidad). |
| [`ambientes.md`](ambientes.md) | Despliegue por ambiente: topología de Kubernetes, límites entre desarrollo, staging y producción, flujo GitOps y gestión de secretos. |
| [`decisiones.md`](decisiones.md) | Decisiones arquitectónicas con su justificación y la alternativa descartada, y los supuestos que todavía no están confirmados. |

Los diagramas exportados están en [`img/`](img/).

## Cómo usar esta arquitectura

- **Para infraestructura como código:** `ambientes.md` define la topología de
  clúster y namespaces, y `decisiones.md` recoge las decisiones ya tomadas sobre
  registry y gestión de secretos. Los módulos de Terraform se derivan de ahí sin
  volver a discutir la arquitectura.
- **Para las pipelines:** `ambientes.md` describe los límites entre ambientes y
  la promoción entre ellos, incluida la aprobación manual antes de producción.
- **Para operación:** `logica.md` describe qué hace cada servicio y de qué
  depende, y `ambientes.md` describe dónde corre cada cosa.

## Antes de dar algo por sentado

`decisiones.md` marca de forma explícita los supuestos que aún no ha confirmado
el team lead, en particular la topología de clúster. Reviselos antes de
construir sobre ellos: cambiar un supuesto en esta etapa cuesta una
conversación, y hacerlo después cuesta rehacer infraestructura.
