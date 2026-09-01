# Arquitectura lógica de componentes

| | |
|---|---|
| **Propósito** | Describir qué piezas componen Docket y cómo se comunican entre sí, sin entrar en dónde corre cada una. |
| **Audiencia** | Todo el equipo. Es el punto de entrada para entender el sistema sin leer el código. |
| **Estado** | Los componentes y sus dependencias están verificados contra el código de `microservice-app-example`. La plataforma de soporte (registry, pipelines, observabilidad) describe el objetivo. |

Dónde corre cada cosa está en [`ambientes.md`](ambientes.md) y [`infraestructura-aws.md`](infraestructura-aws.md).

> **Diagrama:** [Docket, arquitectura lógica (Eraser)](https://app.eraser.io/workspace/pK0utZappfSE43ELZTEs?diagram=0Xz4FPyYskUtz3MHjf3D)

## Componentes de aplicación

Cinco microservicios y una cola de mensajes. Cada servicio se despliega por separado y escala de forma independiente.

| Componente | Stack | Rol | Variables de entorno |
|---|---|---|---|
| **Frontend** | Vue.js | Interfaz web y proxy hacia las APIs. Es el único componente expuesto públicamente, a través del Ingress que el AWS Load Balancer Controller materializa como un ALB con certificado de ACM. | `PORT`, `AUTH_API_ADDRESS`, `TODOS_API_ADDRESS`, `ZIPKIN_URL` |
| **Auth API** | Go | Autenticación. `POST /login` valida credenciales contra Users API y emite un JWT. | `AUTH_API_PORT`, `USERS_API_ADDRESS`, `JWT_SECRET`, `ZIPKIN_URL` |
| **Users API** | Java, Spring Boot | Perfiles de usuario, solo lectura: `GET /users` y `GET /users/:username`. | `SERVER_PORT`, `JWT_SECRET` |
| **Todos API** | Node.js | CRUD de tareas: `GET`, `POST` y `DELETE /todos`. Publica un evento por cada alta y baja. | `TODO_API_PORT`, `JWT_SECRET`, `REDIS_HOST`, `REDIS_PORT`, `REDIS_CHANNEL`, `ZIPKIN_URL` |
| **Log Message Processor** | Python | Worker que consume la cola y procesa los eventos de forma asíncrona. | `REDIS_HOST`, `REDIS_PORT`, `REDIS_CHANNEL`, `ZIPKIN_URL` |
| **Redis** | , | Cola de mensajes entre Todos API (productor) y Log Message Processor (consumidor). | , |

## Flujos

### Autenticación

El navegador entra por el Ingress y llega al Frontend, que expone `/login` como proxy hacia Auth API. Para validar las credenciales, Auth API pide el perfil a Users API (`GET /users/:username`) y lo compara contra su lista de credenciales permitidas. Si coincide, emite el JWT que usará el resto de la sesión.

> Para llamar a Users API, Auth API firma su propio token de servicio con el mismo `JWT_SECRET` y lo envía como `Bearer`. El secreto compartido cumple entonces dos funciones: valida los tokens de usuario y autentica la llamada entre servicios.

### Operación sobre tareas

El Frontend usa el JWT del usuario para llamar a Todos API a través del proxy `/todos`. Todos API valida el token con el mismo secreto con el que Auth API lo firmó.

**Users API no recibe tráfico del Frontend.** El proxy del Frontend declara tres rutas: `/login`, `/todos` y `/zipkin`. Su único cliente es Auth API.

### Registro asíncrono

Cada alta y baja en Todos API publica un mensaje en el canal de Redis. Log Message Processor lo consume por su cuenta, de modo que el registro de la operación no bloquea la respuesta al usuario.

### El secreto compartido

Auth API firma los tokens; Users API y Todos API los verifican. Los tres necesitan el mismo valor de `JWT_SECRET`.

Es el acoplamiento más fuerte del sistema. Rotarlo obliga a actualizar los tres servicios de forma coordinada, y durante la rotación los tokens emitidos con el valor anterior dejan de validar. Su gestión está descrita en [`ambientes.md`](ambientes.md#gestión-de-secretos), y nunca viaja en el código ni en texto plano dentro de un repositorio.

## Plataforma de soporte

**Registry: Amazon ECR.** Guarda las imágenes de los cinco servicios y lo comparten los tres ambientes. Entre ambientes cambia la versión de imagen que se despliega, con el mismo origen en todos los casos. Ver [ADR-001](decisiones.md#adr-001-registry-amazon-ecr).

**Integración continua: GitHub Actions.** Construye, prueba y publica las imágenes al registry. El diseño de las pipelines corresponde al área 04 y no se detalla aquí.

**Observabilidad: Prometheus, Grafana, Zipkin y logs centralizados.** Métricas, dashboards por servicio, tracing distribuido y logs. El despliegue de este stack corresponde al área 07.

La observabilidad parte de una base existente. `auth-api` ya incluye instrumentación de tracing con Zipkin en `tracing.go`, todos los servicios leen `ZIPKIN_URL`, y el Frontend ya envía spans desde el navegador a través de su propio proxy `/zipkin`. El área 07 extiende ese punto de partida al resto de los servicios.
