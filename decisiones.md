# Decisiones arquitectónicas

| | |
|---|---|
| **Propósito** | Registrar cada decisión de arquitectura con su contexto, sus consecuencias y la alternativa descartada. |
| **Formato** | Un ADR (Architecture Decision Record) por decisión, numerado y con estado explícito. |
| **Regla** | Una decisión no se borra ni se reescribe en silencio. Se marca como *Reemplazada* y se agrega la nueva, para que quede registro de qué se rechazó y por qué. |

Estados: **Aceptada** · **Supuesto** (tomada por ausencia de indicación contraria y todavía sin confirmar) · **Reemplazada**.

## Condiciones que enmarcan todas las decisiones

| Condición | Valor confirmado |
|---|---|
| Tipo de cuenta | Plan gratuito de AWS por créditos |
| Saldo | 100 USD, ampliables a 200 USD con 5 actividades guiadas |
| Plazo del plan | 182 días |
| Ventana de trabajo | 2 semanas |
| Región | `us-east-1` |
| Modo de operación | Infraestructura efímera, con `destroy` y `apply` rutinarios |

| ADR | Decisión | Estado |
|---|---|---|
| [001](#adr-001-registry-amazon-ecr) | Registry: Amazon ECR | Aceptada |
| [002](#adr-002-secretos-con-external-secrets-y-ssm-parameter-store) | Secretos: External Secrets y SSM Parameter Store | Aceptada |
| [003](#adr-003-un-clúster-compartido-con-tres-namespaces) | Un clúster compartido con tres namespaces | Aceptada |
| [004](#adr-004-cómputo-amazon-eks) | Cómputo: Amazon EKS | Aceptada |
| [005](#adr-005-red-multi-az-con-un-solo-nat-gateway) | Red: multi-AZ con un solo NAT Gateway | Aceptada |
| [006](#adr-006-acceso-administrativo-con-ssm-session-manager) | Acceso administrativo con SSM Session Manager | Aceptada |
| [007](#adr-007-validación-de-terraform-contra-floci-en-ci) | Validación de Terraform contra Floci en CI | Aceptada |
| [008](#adr-008-dns-en-route-53-y-tls-con-acm) | DNS en Route 53 y TLS con ACM | Aceptada |
| [009](#adr-009-bloqueo-de-estado-nativo-de-s3) | Bloqueo de estado nativo de S3 | Aceptada |
| [010](#adr-010-infraestructura-efímera-con-estado-dividido) | Infraestructura efímera con estado dividido | Aceptada |
| [011](#adr-011-credenciales-de-pipeline-con-oidc-e-iam-role) | Credenciales de pipeline con OIDC e IAM Role | Aceptada |

---

## ADR-001 Registry: Amazon ECR

**Estado:** Aceptada.

**Contexto.** Toda la infraestructura de la plataforma vive en la cuenta AWS del equipo, con IAM como mecanismo de autorización.

**Decisión.** Cinco repositorios privados en Amazon ECR, uno por microservicio. Los nodos hacen `pull` con el rol de instancia del node group.

**Consecuencias.**
- El `pull` de imágenes se resuelve con el rol del nodo, sin `imagePullSecrets` ni credenciales estáticas en el clúster.
- El control de acceso al registry queda expresado en IAM, junto con el del resto de la infraestructura.
- La capa gratuita de ECR cubre 500 MB al mes, lo que obliga a una política de ciclo de vida que pode imágenes antiguas.

**Alternativa descartada.** GitHub Container Registry, que fue la elección inicial cuando el proyecto todavía no tenía cuenta cloud. Sigue siendo técnicamente válido y su capa gratuita es más amplia. Se descarta porque deja el registry con un modelo de permisos distinto al del resto de la plataforma y sin poder aprovechar el rol de instancia para el `pull`.

---

## ADR-002 Secretos con External Secrets y SSM Parameter Store

**Estado:** Aceptada. Reemplaza a Bitnami Sealed Secrets.

**Contexto.** El clúster se destruye y se recrea de forma rutinaria ([ADR-010](#adr-010-infraestructura-efímera-con-estado-dividido)). Cualquier mecanismo que custodie la llave de descifrado dentro del clúster la pierde en cada `destroy`, y con ella la capacidad de descifrar los secretos guardados en el repositorio.

**Decisión.** Los secretos viven en SSM Parameter Store como `SecureString`, fuera del clúster y dentro del stack persistente. External Secrets Operator, autenticado por IRSA, los lee y los materializa como `Secret` de Kubernetes en cada namespace. El árbol se segmenta por ambiente (`/docket/<ambiente>/...`) y cada rol tiene lectura solo sobre su prefijo.

**Consecuencias.**
- Los secretos sobreviven a la destrucción del clúster.
- No queda material criptográfico que respaldar y restaurar entre despliegues.
- El acceso se expresa en IAM y queda auditado en CloudTrail.
- Parameter Store en tier estándar no genera costo. El tier avanzado y la rotación automática sí lo harían.
- Los secretos salen del repositorio Git, lo que reduce la trazabilidad de "todo el estado declarado en Git" que ofrecía el enfoque anterior.

**Alternativa descartada.** Sealed Secrets con respaldo y restauración de la llave del controller en cada `apply`. Funciona, y convierte una llave crítica en un artefacto que hay que custodiar y reinyectar en cada ciclo, lo que introduce un paso manual frágil en una operación que se repite a diario.

---

## ADR-003 Un clúster compartido con tres namespaces

**Estado:** Aceptada.

**Contexto.** El criterio de aceptación del tablero menciona "clúster/namespace" como una sola unidad, y el presupuesto disponible es un saldo de créditos limitado.

**Decisión.** Un solo clúster EKS con los namespaces `dev`, `staging` y `prod`, cada uno con su propio RBAC y sus resource quotas.

**Consecuencias.**
- El aislamiento entre ambientes ocurre a nivel lógico. No hay separación de nodo ni de plano de control, así que un incidente en el clúster alcanza a los tres ambientes al mismo tiempo, producción incluida.
- Obliga a dimensionar los nodos para la suma de los tres ambientes. Ver el cálculo de pods por nodo en [`infraestructura-aws.md`](infraestructura-aws.md#cómputo).

**Alternativa descartada.** Un clúster por ambiente. Ofrece aislamiento real y es lo indicado con un cliente que lo exija. Se descarta porque triplica el costo del control plane y agota el saldo disponible en pocos días.

---

## ADR-004 Cómputo: Amazon EKS

**Estado:** Aceptada.

**Contexto.** El control plane de EKS cuesta 0.10 USD por hora. Sobre la ventana de 2 semanas del proyecto son ~34 USD, que caben en el saldo de créditos disponible. El brief exige orquestación con Kubernetes en los tres ambientes.

**Decisión.** Amazon EKS en `us-east-1`, con un node group gestionado de 2 nodos `t3.medium`, uno por zona de disponibilidad, en subredes privadas.

**Consecuencias.**
- El control plane queda gestionado por AWS, sin `etcd` que respaldar ni actualizaciones que operar.
- Se habilitan IRSA, las EKS access entries y los controllers nativos, que son la base de [ADR-002](#adr-002-secretos-con-external-secrets-y-ssm-parameter-store) y [ADR-008](#adr-008-dns-en-route-53-y-tls-con-acm).
- Corresponde a la arquitectura que se usaría con un cliente real, lo que refuerza la credibilidad del entregable.
- Consume alrededor de un tercio del saldo si se mantiene encendido las 2 semanas completas, lo que hace necesario reclamar los créditos adicionales y apagar fuera de horario.
- EKS exige subredes en dos zonas de disponibilidad y limita los pods por nodo según el tipo de instancia. Ambas restricciones condicionan [ADR-005](#adr-005-red-multi-az-con-un-solo-nat-gateway) y el dimensionamiento del node group.

**Alternativa descartada.** Kubernetes autogestionado con k3s sobre una instancia EC2 pequeña. Se descarta por tres motivos: 1 GiB de RAM no sostiene tres ambientes completos más Argo CD y observabilidad, un solo nodo elimina la tolerancia a fallos.

---

## ADR-005 Red: multi-AZ con un solo NAT Gateway

**Estado:** Aceptada.

**Contexto.** EKS exige subredes en al menos dos zonas de disponibilidad. Un NAT Gateway cuesta 0.045 USD por hora, unos 15 USD sobre la ventana del proyecto, y la topología de referencia despliega uno por zona.

**Decisión.** VPC `10.0.0.0/16` sobre `us-east-1a` y `us-east-1b`, con cuatro subredes: dos públicas para el ALB y el NAT, y dos privadas para los nodos. Un solo NAT Gateway, ubicado en la subred pública A y compartido por ambas zonas.

**Consecuencias.**
- Los nodos quedan fuera del alcance de internet y el único componente expuesto es el ALB.
- Si `us-east-1a` deja de estar disponible, los nodos de `us-east-1b` pierden salida a internet. La concesión se asume de forma deliberada a cambio de 15 USD del presupuesto.

**Alternativa descartada.** Un NAT Gateway por zona, que es lo correcto para producción y añade 15 USD. También se evaluó colocar los nodos en subredes públicas para prescindir del NAT: ahorra el mismo monto y expone los nodos, alejándose de la topología estándar que el proyecto busca demostrar.

---

## ADR-006 Acceso administrativo con SSM Session Manager

**Estado:** Aceptada.

**Contexto.** Con EKS, la administración del clúster se hace con `kubectl` contra el endpoint gestionado, autorizado por IAM. El acceso al sistema operativo del nodo se necesita en contadas ocasiones.

**Decisión.** El acceso puntual a un nodo se hace con SSM Session Manager. No se despliega bastion host, no se reserva una subred de administración y ninguna regla de security group abre `22/tcp`.

**Consecuencias.**
- Desaparece la superficie de ataque de un puerto SSH expuesto y la gestión de llaves asociadas.
- Cada sesión queda autorizada por IAM y registrada en CloudTrail, con trazabilidad por persona.
- Se ahorra una instancia EC2 y su volumen.
- Depende del agente de SSM, que viene incluido en la AMI de EKS, y de que el nodo tenga salida a internet o endpoints de VPC hacia SSM.

**Alternativa descartada.** Bastion host en una subred de administración con SSH restringido por IP. Es el patrón clásico y sigue siendo válido. Se descarta porque cuesta una instancia adicional, obliga a custodiar llaves SSH compartidas y ofrece menos trazabilidad que SSM.

---

## ADR-007 Validación de Terraform contra Floci en CI

**Estado:** Aceptada.

**Contexto.** Un error de Terraform aplicado contra la cuenta real puede dejar infraestructura a medio crear y consumir créditos del saldo. Floci es un emulador de código abierto de la API de AWS, ejecutable dentro del runner de CI.

**Decisión.** Antes del `apply` real, un job corre `terraform plan` y `apply` contra Floci. Terraform declara dos configuraciones del provider `aws`: la real y un alias con `endpoints` apuntando a `localhost:4566`, activo solo en ese job.

**Consecuencias.**
- Los errores de sintaxis, las referencias rotas y las políticas mal formadas se detectan en CI.
- Floci emula la API sin plano de datos, así que un recurso creado contra el emulador responde como recurso pero no ejecuta nada. Su alcance es validar código de infraestructura.
- La cobertura de un emulador nunca es total, de modo que un `apply` válido contra Floci reduce el riesgo sin eliminarlo.

**Alternativa descartada.** Aplicar directamente contra la cuenta real desde el primer intento. Es lo habitual en proyectos pequeños y convierte el ambiente real en el lugar donde se descubren los errores, algo que aquí se paga en créditos.

---

## ADR-008 DNS en Route 53 y TLS con ACM

**Estado:** Aceptada.

**Contexto.** El tráfico entra por un ALB, que se identifica por nombre DNS y se recrea con cada `apply` ([ADR-010](#adr-010-infraestructura-efímera-con-estado-dividido)).

**Decisión.** Zona alojada en Route 53, con un registro ALIAS por ambiente apuntando al ALB. Certificado emitido por AWS Certificate Manager, validado por DNS contra esa misma zona y terminado en el ALB.

**Razones.**

1. ACM entrega certificados públicos sin costo, los renueva de forma automática y valida por DNS contra la propia zona.
2. Al recrear el clúster con frecuencia, una autoridad certificadora con límites de emisión por semana se convierte en un cuello de botella real. ACM no impone ese límite.
3. El DNS queda declarado en Terraform, versionado y reproducible, que es lo que evalúa el área 02.

**Consecuencias.**
- ~0.50 USD al mes por zona alojada, el único costo que corre al margen del ciclo de encendido y apagado.
- Un paso manual, una sola vez: delegar los nameservers del dominio en el registrador.
- El certificado y la zona pertenecen al stack persistente, y el ALB al efímero.

**Alternativa descartada.** DNS en el registrador con registros creados a mano, y `cert-manager` con Let's Encrypt dentro del clúster.

---

## ADR-009 Bloqueo de estado nativo de S3

**Estado:** Aceptada.

**Contexto.** Desde Terraform 1.10 el backend S3 admite bloqueo nativo mediante escrituras condicionales, con el argumento `use_lockfile`. Desde 1.11 los argumentos `dynamodb_table`, `dynamodb_endpoint` y `endpoints.dynamodb` están deprecados, y la documentación oficial advierte que el bloqueo por DynamoDB se removerá en una versión menor futura.

**Decisión.** Backend S3 con `use_lockfile = true`. El bloqueo usa un objeto `.tflock` en el mismo bucket del estado.

**Consecuencias.**
- Un recurso menos que provisionar, permisionar y mantener.
- Los permisos del bloqueo son `s3:GetObject`, `s3:PutObject` y `s3:DeleteObject` sobre `<key>.tflock`.
- Obliga a fijar `required_version` en 1.11 o superior.

**Alternativa descartada.** Tabla de DynamoDB para el bloqueo. Aparece en la mayoría de tutoriales y su capa gratuita cubre el uso del proyecto. Se descarta porque está deprecada y adoptarla hoy sería escribir código con fecha de caducidad conocida.

---

## ADR-010 Infraestructura efímera con estado dividido

**Estado:** Aceptada.

**Contexto.** El presupuesto es un saldo de créditos y la ventana del proyecto es de 2 semanas. Mantener EKS encendido de forma continua consume alrededor de un tercio del saldo. Destruir y recrear la infraestructura fuera del horario de trabajo reduce ese gasto a menos de la mitad, y cubre la meta extra de FinOps del brief.

**Decisión.** La infraestructura se opera como efímera, con `terraform destroy` y `terraform apply` como operaciones rutinarias. El Terraform se divide en dos stacks con estados separados:

| Stack | Contiene | Ciclo de vida |
|---|---|---|
| `persistente` | Bucket de estado, ECR, zona de Route 53, certificado de ACM, OIDC provider, IAM roles y parámetros de SSM | Se crea una vez y permanece |
| `efimero` | VPC, subredes, NAT, EKS, node group, ALB | `apply` y `destroy` a demanda |

**Consecuencias.**
- Un `destroy` deja intactos el registry, los secretos y la zona DNS.
- Es lo que fuerza el diseño de [ADR-002](#adr-002-secretos-con-external-secrets-y-ssm-parameter-store), porque un mecanismo de secretos con la llave dentro del clúster no sobrevive al ciclo.
- Levantar el clúster desde cero toma del orden de 15 a 20 minutos, tiempo que hay que contemplar en la planificación diaria.
- Todo lo que viva dentro del clúster y no esté declarado en el repositorio GitOps se pierde en cada ciclo. Los datos de Prometheus y de Redis son efímeros por construcción.
- Argo CD tiene que instalarse desde el stack efímero o desde un bootstrap declarado, de modo que el clúster se reconstruya sin intervención manual.

**Alternativa descartada.** Mantener la infraestructura encendida durante las 2 semanas. Es más simple y deja la plataforma siempre disponible para revisión. Se descarta porque consume ~92 USD del saldo y desaprovecha la oportunidad de demostrar prácticas de FinOps.

---

## ADR-011 Credenciales de pipeline con OIDC e IAM Role

**Estado:** Aceptada.

**Contexto.** La pipeline necesita credenciales de AWS para ejecutar Terraform y publicar imágenes. Guardar llaves de acceso de larga duración como secretos del repositorio es la práctica más extendida y la más frágil, porque no rotan solas y sobreviven a quien las creó.

**Decisión.** GitHub Actions obtiene credenciales temporales mediante federación OIDC, asumiendo dos roles distintos según el job:

| Rol | Lo asume | Permisos |
|---|---|---|
| `GitHubActionsBuildRole` | El job que construye y publica imágenes | `ecr:*` sobre los cinco repositorios |
| `GitHubActionsDeployRole` | El job que ejecuta Terraform | EC2, VPC, IAM, S3, EKS y Route 53 |

Los secretos de la aplicación se resuelven por [ADR-002](#adr-002-secretos-con-external-secrets-y-ssm-parameter-store).

**Consecuencias.**
- El proyecto no almacena ninguna llave de acceso de larga duración.
- El job de build queda sin capacidad de tocar la infraestructura, lo que responde al criterio de accesos limitados según necesidad de la historia `18` del tablero.
- La política de confianza de cada rol se restringe al repositorio y la rama concretos. Abierta a toda la organización equivaldría a una credencial compartida.

**Alternativa descartada.** HashiCorp Vault como gestor único de secretos. Cubre el mismo alcance que OIDC y Parameter Store combinados, y exige operar un tercer sistema que a su vez necesita credenciales iniciales propias. Queda disponible como meta extra de aprendizaje.

---

## Supuestos abiertos

Afirmaciones que este diseño da por ciertas y que conviene resolver antes o durante la historia de Terraform.


**La capacidad del clúster.** El dimensionamiento a 2 nodos `t3.medium` sale del conteo de pods y del límite que impone el CNI de EKS, sin validación con carga real. Si resulta insuficiente, la salida disponible es reducir los ambientes activos de forma simultánea, porque el presupuesto no admite nodos mayores.

**Solo producción exige aprobación manual.** Se asume que la promoción de `dev` a `staging` puede ser automática tras la revisión del pull request. Queda por confirmar al definir las pipelines del área 04.

**La observabilidad parte de una base existente.** `auth-api` ya incluye instrumentación de tracing con Zipkin y el frontend ya envía spans. El área 07 extiende ese punto de partida.

**El repositorio de manifiestos GitOps todavía no existe.** Corresponde a la historia 06 del tablero, que depende de esta.
