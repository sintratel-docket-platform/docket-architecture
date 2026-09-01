# Despliegue por ambiente

| | |
|---|---|
| **Propósito** | Definir qué separa un ambiente de otro, cómo avanza un cambio hasta producción y qué controles existen en cada transición. |
![Despliegue por ambiente de Docket](img/ambientes.png)

Los componentes están descritos en [`logica.md`](logica.md). La capa física que sostiene este clúster está en [`infraestructura-aws.md`](infraestructura-aws.md).

## Topología

Un único clúster de Amazon EKS en `us-east-1`, con tres namespaces: `dev`, `staging` y `prod`. Cada namespace corre una instancia completa de la aplicación, es decir los cinco servicios más Redis.

Junto a la aplicación, dentro del clúster corren:

| Componente | Rol |
|---|---|
| **Argo CD** | Sincroniza los tres namespaces contra el repositorio de manifiestos |
| **External Secrets Operator** | Materializa como `Secret` de Kubernetes los parámetros que lee de SSM Parameter Store, por namespace |
| **AWS Load Balancer Controller** | Traduce los objetos `Ingress` en la configuración del ALB |
| **Stack de observabilidad** | Prometheus, Grafana, Zipkin y logs centralizados |

> **Supuesto todavía sin validar.** La elección de un clúster compartido en lugar de tres clústeres separados. 

## Límites entre desarrollo, staging y producción

**Qué los separa.** El aislamiento ocurre a nivel lógico. Cada namespace tiene su propio RBAC, sus resource quotas y su prefijo de secretos en Parameter Store (`/docket/<ambiente>/...`), al que solo accede su rol de IRSA. Al compartir clúster no hay aislamiento de nodo ni de plano de control, así que un incidente en el clúster alcanza a los tres ambientes al mismo tiempo, producción incluida.

**Qué comparten.** El clúster, los nodos, el registry, el ALB, la instancia de Argo CD y la zona DNS. Entre ambientes cambia la versión de imagen declarada en los manifiestos, y el origen de esa imagen es siempre el mismo registry.

**Qué los conecta.** Únicamente la promoción, y siempre en un sentido: `dev` hacia `staging` hacia `prod`. No hay tráfico entre namespaces ni acceso de un ambiente a los datos de otro.

**Los controles.**

Cada ambiente tiene dos controles independientes: uno sobre el merge en el repositorio de manifiestos y otro sobre la sincronización que hace Argo CD.

| Ambiente destino | Control sobre el merge | Política de sync de Argo CD |
|---|---|---|
| `dev` | Ninguno adicional | `automated`, sincroniza al detectar el cambio |
| `staging` | Pull request con revisión | `automated`, sincroniza tras el merge |
| `prod` | Pull request con revisión y aprobación de un responsable definido | **Manual**, alguien dispara el sync después del merge |

La distinción entre los dos controles importa en producción. Aprobar y mergear el pull request deja la versión declarada en Git, y el cambio llega al clúster solo cuando una persona ejecuta el sync de la `Application` de Argo CD. Son dos actos separados y auditables.

El diseño de las políticas de aprobación y la designación de los responsables corresponden al área 04. Aquí se define el límite que esas políticas deben respetar.

## Flujo GitOps

El repositorio de manifiestos contiene la verdad declarativa de los tres ambientes. Argo CD corre dentro del clúster, vigila ese repositorio y sincroniza cada namespace con lo declarado.

La consecuencia importante: la pipeline nunca aplica cambios al clúster de forma directa. GitHub Actions construye la imagen y la publica en ECR, y el despliegue ocurre cuando un manifiesto en Git referencia esa versión nueva. Todo cambio en producción tiene, por construcción, un commit que lo explica.

Este flujo impone una restricción sobre el etiquetado: **las etiquetas de imagen tienen que ser inmutables**. Con una etiqueta que se reescribe, el manifiesto no cambia, Argo CD no detecta nada y la promoción entre ambientes deja de funcionar. El esquema concreto de etiquetado se define al construir la pipeline.

Lo mismo aplica a la infraestructura: la pipeline de Terraform provisiona la capa de AWS y deja intacto el interior del clúster. Son dos flujos independientes. Ver [`infraestructura-aws.md`](infraestructura-aws.md#flujo-de-cambio-de-infraestructura).

> **Consecuencia del ciclo de vida efímero.** El clúster se destruye y se recrea de forma rutinaria ([ADR-010](decisiones.md#adr-010-infraestructura-efímera-con-estado-dividido)). Todo lo que viva dentro y no esté declarado en el repositorio GitOps se pierde en cada ciclo: los datos de Prometheus y de Redis son efímeros por construcción, y Argo CD debe instalarse desde el stack de Terraform o desde un bootstrap declarado para que el clúster se reconstruya sin intervención manual.

## Dependencias entre repositorios y ambientes

| Rol del repositorio | Qué aporta | Cómo llega al ambiente |
|---|---|---|
| **Repos de servicio**, uno por microservicio | Código de la aplicación | Un push dispara la pipeline, que construye la imagen y la publica en ECR con una etiqueta inmutable |
| **Repo de infraestructura** | Terraform, dividido en stack persistente y stack efímero | Provisiona la VPC, el clúster y los recursos de soporte |
| **Repo de manifiestos GitOps** | Estado declarativo por ambiente | Argo CD lo vigila y sincroniza cada namespace |
| **Repo de configuración externa** | Configuración de la aplicación por ambiente (External Configuration Store) | Se consume en tiempo de despliegue, separada de la imagen |
| **Repo de documentación** (este) | Arquitectura de referencia y decisiones | No se despliega. Es la fuente para los otros cuatro |

## Gestión de secretos

Los secretos de la aplicación, entre ellos el `JWT_SECRET` que comparten Auth API, Users API y Todos API, viven en SSM Parameter Store como `SecureString`, fuera del clúster. External Secrets Operator los lee mediante IRSA y los materializa como `Secret` de Kubernetes en cada namespace.

El alcance es por ambiente: el rol de IRSA de `dev` tiene lectura únicamente sobre `/docket/dev/...`. Ningún secreto queda en texto plano en un repositorio, y el conjunto sobrevive a la destrucción del clúster.

Las credenciales de AWS que usa la pipeline se resuelven por federación OIDC con credenciales temporales, al margen de este mecanismo. Ver [ADR-011](decisiones.md#adr-011-credenciales-de-pipeline-con-oidc-e-iam-role).

## Dominio, DNS y TLS

Cada ambiente resuelve por un host distinto hacia el mismo ALB, y el Ingress separa el tráfico por cabecera `Host`.

| Ambiente | Host |
|---|---|
| `prod` | `docket.<dominio>` |
| `staging` | `staging.docket.<dominio>` |
| `dev` | `dev.docket.<dominio>` |

El certificado lo emite ACM y termina en el ALB. Los registros de Route 53 son de tipo ALIAS y se gestionan desde Terraform, porque el ALB se recrea con cada `apply` y cambia de nombre DNS. Detalle en [`infraestructura-aws.md`](infraestructura-aws.md#dominio-dns-y-tls).
