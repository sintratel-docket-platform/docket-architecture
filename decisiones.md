# Decisiones arquitectónicas y supuestos

Por qué la arquitectura es como es. Cada decisión incluye la alternativa que se
descartó, porque saber qué se rechazó y por qué evita volver a discutirlo más
adelante.

Las decisiones sostienen [`logica.md`](logica.md) y
[`ambientes.md`](ambientes.md).

## 1. Los documentos viven en la raíz del repositorio

Este repositorio está dedicado a la arquitectura, así que anidar el contenido
bajo `docs/architecture/` repetiría el nombre del repositorio dos veces en cada
ruta sin aportar información.

*Alternativa descartada:* `docs/architecture/`, que tenía sentido cuando la
documentación iba a convivir con otros temas dentro de un repositorio
compartido.

## 2. Diagramación con Eraser.io en modo diagram-as-code

Los diagramas se definen como código, no se dibujan a mano. La fuente queda
versionada y un cambio en el diagrama se revisa como cualquier otro cambio.

*Alternativa descartada:* draw.io o Excalidraw editados manualmente. Producen
una imagen sin fuente revisable y no permiten reconstruir el diagrama de forma
reproducible.

## 3. Registry: GitHub Container Registry

Es gratuito para los repositorios de la organización, se integra de forma
nativa con GitHub Actions (la herramienta de integración continua del proyecto)
y hereda el control de acceso de los permisos de la organización, sin gestionar
credenciales aparte.

*Alternativa descartada:* Amazon ECR o Docker Hub. Ambos añaden una cuenta y un
juego de credenciales adicionales sin resolver ningún problema que GHCR no
resuelva ya en este contexto.

## 4. Gestión de secretos: Bitnami Sealed Secrets

Permite versionar los secretos cifrados dentro del repositorio de manifiestos
sin romper el flujo declarativo: el estado completo sigue estando en Git y Argo
CD lo sincroniza sin excepciones.

*Alternativa descartada:* que la pipeline inyecte los secretos directamente en
el clúster, por fuera de Argo CD. Funciona, pero abre un camino por el que el
estado del clúster deja de estar descrito en Git, que es justamente lo que el
flujo GitOps busca evitar.

## 5. Los repositorios se representan por rol, no por nombre

Los diagramas muestran clases de repositorio (servicio, infraestructura,
manifiestos GitOps, configuración externa) sin nombrar repositorios concretos.

El proyecto está separando el código en varios repositorios, pero **los
repositorios por microservicio todavía no existen y su convención de nombres no
está acordada**. Escribir nombres concretos en un documento de referencia les
daría una apariencia de decisión tomada, y otras historias los copiarían como si
lo fueran.

*Alternativa descartada:* nombrar los repositorios asumiendo una convención.
Cuando la convención se acuerde, esta decisión puede revisarse y los diagramas
actualizarse con los nombres reales.

## 6. Topología: un clúster compartido con tres namespaces

> ⚠️ **Supuesto, no decisión confirmada.** El team lead no lo ha validado. Si el
> equipo prefiere aislamiento físico entre ambientes, hay que revisarlo **antes**
> de que el área 02 escriba el Terraform que lo dé por sentado. Cambiarlo ahora
> cuesta una conversación; cambiarlo después cuesta rehacer infraestructura.

Un solo clúster de Kubernetes con los namespaces `dev`, `staging` y `prod`, cada
uno con su RBAC y sus resource quotas.

*Razonamiento:* el proyecto no cuenta con un presupuesto de infraestructura
amplio, y un clúster único reduce el costo y la carga operativa para equipos
junior. Namespaces con RBAC dan aislamiento lógico suficiente para lo que exige
el criterio de aceptación, que además menciona "clúster/namespace" como una sola
unidad y no habla de clústers en plural.

*Lo que se acepta a cambio:* no hay aislamiento a nivel de nodo ni de plano de
control. Un incidente en el clúster afecta a los tres ambientes al mismo tiempo,
incluida producción.

*Alternativa descartada:* un clúster por ambiente. Da aislamiento real y sería
lo indicado si los datos de la firma legal exigieran separación física, pero
triplica el costo y el trabajo de operación.

## Otros supuestos registrados

**La aplicación base no está contenerizada.** No existen Dockerfiles,
`docker-compose` ni manifiestos de Kubernetes. Ambos diagramas son
prescriptivos: describen la meta, no algo que ya esté corriendo. Es probable que
haya ajustes cuando el área 02 implemente la infraestructura real.

**Solo producción exige aprobación manual.** Se asume que la promoción de `dev`
a `staging` puede ser automática tras la revisión del pull request. Queda por
confirmar al definir las pipelines del área 04.

**La observabilidad no parte de cero.** `auth-api` ya incluye instrumentación de
tracing con Zipkin en `tracing.go`. El área 07 extiende ese punto de partida al
resto de los servicios en lugar de introducir el tracing desde el principio.

**El repositorio de manifiestos GitOps todavía no existe.** Es la historia 06
del tablero, que depende de esta. Hasta que se cree, su estructura interna es
una previsión, no un hecho.
