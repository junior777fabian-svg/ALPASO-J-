# Al Paso — Estructura del proyecto

**Estado:** Etapa 1: partes 1A, 1B y 1C verificadas; 1D preparada, a la espera del proyecto demo. Etapa 2: partes 2A a 2E implementadas y verificadas en la nube. El dueño indicó avanzar por partes; las propuestas de este documento siguen abiertas a cambios. Lo implementado se marca en cada sección.
**Última actualización:** 18 de noviembre de 2026.

Este documento es el plano del proyecto: qué se construye, con qué, en qué orden y cómo se comprueba. Se escribe antes del código y se actualiza cada vez que cambia una decisión.

Cada punto lleva uno de tres estados: **propuesto**, **implementado** o **verificado**. Hoy todo es propuesto. Una función solo pasa a "verificada" cuando tiene pruebas que la respaldan.

La versión anterior (repositorio `al-paso-principal`) queda como referencia de diseño. Su código no se copia.

---

## 1. El producto

Al Paso es una app móvil para Android y iPhone, pensada para Lima Metropolitana y Callao. Resuelve dos problemas: ir de hostal en hostal preguntando si hay cuarto, y pagar un cuarto sin saber cómo es por dentro.

Con la app una persona:

1. Ve en un mapa los hostales y hospedajes cercanos que tienen cuarto disponible, con su precio.
2. Mira el cuarto antes de reservar: fotos de la habitación, del baño y del jacuzzi si tiene.
3. Reserva por horas (4, 6 u 8), por 12 horas o por 24 horas.
4. Agrega extras (gaseosa, agua, preservativos, papel, vino, cerveza y otros) para encontrarlos en el cuarto al llegar.
5. Paga en la app y entra mostrando un código.

No compite con Booking ni Airbnb. Apunta a hospedajes de precio accesible, por horas, para ahora o para hoy.

### Principios

1. **Disponibilidad verdadera.** Lo que la app muestra como libre se puede reservar. Si el hostal alquila un cuarto a alguien que llegó caminando, la app se entera.
2. **El servidor decide.** Precio, disponibilidad, estados de la reserva, pagos y permisos se calculan y validan en el servidor. La app solo muestra y solicita.
3. **Nada simulado se presenta como real.** Los servicios en modo demo llevan un rótulo visible y no pueden activarse en la versión de tiendas.
4. **Discreción.** Avisos con texto neutro, datos personales mínimos, y el hostal solo ve del cliente lo necesario para atenderlo.
5. **Solo mayores de 18 años.**
6. **Gratis primero.** Se construye con herramientas sin costo. Cada servicio de pago queda detrás de un conector que se activa cuando se adquiera.

---

## 2. Decisiones

### Tomadas por el dueño del proyecto (14/11/2026)

| Tema | Decisión |
|---|---|
| Plataformas | Android y iPhone con un solo código, en Flutter |
| Pago | Total en la app al reservar |
| Costos | Solo herramientas gratuitas por ahora; lo que exige pago queda en demo, listo para conectar |
| Pruebas | Automáticas y a cargo del agente de la nube |
| Forma de trabajo | Dos agentes autónomos; el trabajo se divide en partes y cada parte termina con un prompt para el agente local |
| Repositorio | `ALPASO-J-`; el agente de la nube escribe y el PC del dueño descarga |
| Equipos disponibles | PC con Windows, celular Android, iPhone, y una Mac en el instituto |

### Propuestas por el agente, pendientes de confirmación

| Tema | Propuesta | Motivo |
|---|---|---|
| Servidor | Supabase: Postgres con PostGIS, Auth, Storage, Edge Functions y Realtime | Postgres garantiza que no haya doble reserva; PostGIS resuelve "cerca de mí"; tiene plan gratuito |
| Mapa | OpenStreetMap con `flutter_map` | No pide tarjeta ni llave y se puede probar de forma automática |
| Interruptor "pago en el hostal" | Existe como configuración, apagado por defecto | Permite un piloto real antes de tener pasarela |
| Panel de administrador | Web aparte, fuera de la app de tiendas | Menos riesgo y revisión de tiendas más simple |
| Zona inicial | Lima Metropolitana y Callao | Foco del lanzamiento |

---

## 3. Piezas del sistema

```
  App móvil Al Paso (Flutter)          Panel admin (web)      Web pública
  modo Cliente · modo Negocio                 │              (páginas legales)
              │                               │
              └───────────────┬───────────────┘
                              ▼
                     Supabase (servidor)
     Auth · Postgres + PostGIS · Funciones · Fotos · Tiempo real
                              │
                              ▼
                         Conectores
        Pagos · SMS · Push · Correo     (demo ahora, real después)
```

| Pieza | Qué es | Etapa |
|---|---|---|
| App móvil | Una sola app con dos modos: Cliente y Negocio. Quien tiene un hostal o trabaja en uno cambia de modo desde su perfil | 1 a 5 |
| Servidor | Base de datos, cuentas, fotos y las reglas del negocio | 1 a 5 |
| Panel admin | Aprobar hostales, cuentas, reservas, liquidaciones e incidencias | 6 |
| Web pública | Términos, privacidad, eliminación de cuenta y libro de reclamaciones | 6 |

---

## 4. Roles

| Rol | Puede | No puede |
|---|---|---|
| **Cliente** | Buscar, reservar, pagar, pedir extras, ver su código, cancelar según las reglas | Ver reservas ajenas ni alterar precios o estados |
| **Dueño** | Gestionar su hostal: cuartos, tarifas, fotos, carta de extras, personal, reservas e ingresos | Tocar hostales ajenos ni modificar pagos |
| **Recepcionista** | Atender el día en los hostales que le asignaron: ingresos, salidas, limpieza, clientes directos y extras | Cambiar precios, ver ingresos, invitar personal |
| **Administrador** | Aprobar hostales, gestionar cuentas, resolver incidencias, registrar liquidaciones | Actuar sin dejar registro |

Una cuenta puede ser cliente y además dueño o recepcionista. El modo Negocio aparece solo si la cuenta pertenece a algún hostal. El rol de administrador no se puede obtener desde la app.

---

## 5. Módulos y pantallas

### Modo Cliente

| Código | Módulo | Pantallas y funciones |
|---|---|---|
| C1 | Acceso | Bienvenida, confirmación de mayoría de edad, registro e inicio de sesión (correo y Google; Apple cuando se conecte), verificación de celular antes de la primera reserva |
| C2 | Explorar | Mapa con pines de precio y lista. Selector de duración (4, 6, 8, 12, 24 h) y de llegada (ahora, más tarde, otra fecha). Filtros: precio, jacuzzi, cochera y otros servicios. Búsqueda por distrito. Se puede explorar sin cuenta |
| C3 | Hostal | Fotos, servicios, dirección y referencia, reglas, y los tipos de cuarto disponibles con su precio para la duración elegida |
| C4 | Cuarto | Galería etiquetada (habitación, baño, jacuzzi), características y tarifas por bloque |
| C5 | Reservar | Duración y hora de llegada, extras, resumen con el total, pago y confirmación con código |
| C6 | Mis reservas | Reserva activa con código y QR, cómo llegar, tiempo restante y cancelación. Historial |
| C7 | Perfil | Datos personales, ayuda, documentos legales, eliminar cuenta, cambio a modo Negocio |

### Modo Negocio

| Código | Módulo | Pantallas y funciones |
|---|---|---|
| N1 | Registro del hostal | Datos, ubicación marcada en el mapa, fotos y envío a revisión |
| N2 | Cuartos | Tipos de cuarto con fotos y características, unidades (201, 202…), tarifas por bloque y tiempo de limpieza |
| N3 | Extras | Carta propia: producto, foto, precio, categoría, disponible o agotado |
| N4 | Hoy | Tablero de recepción: llegadas próximas, cuartos ocupados y por limpiar. Ingreso con código o QR, salida, marcar limpio, ocupar un cuarto para un cliente directo, extras por preparar |
| N5 | Reservas | Lista y detalle, cancelar con motivo |
| N6 | Personal | Invitar y retirar recepcionistas |
| N7 | Ingresos | Ventas, comisión y liquidaciones recibidas |

### Panel admin (web)

| Código | Módulo |
|---|---|
| A1 | Hostales por aprobar y publicados |
| A2 | Cuentas: buscar, bloquear |
| A3 | Reservas y pagos, reembolsos |
| A4 | Liquidaciones a hostales |
| A5 | Incidencias de soporte |
| A6 | Configuración: comisión, tiempos, duraciones permitidas, conectores activos |

---

## 6. Reglas de negocio

Los números de esta sección son propuestas de partida. Las que requieren decisión del dueño están en la sección 17.

### 6.1 Duraciones

- Bloques permitidos: 4, 6, 8, 12 y 24 horas. La lista es configuración de la plataforma, no código.
- Cada hostal activa los bloques que vende y les pone precio por tipo de cuarto.
- El cliente elige la hora de llegada: desde "en 15 minutos" hasta 7 días adelante.
- Todas las horas se manejan en horario de Lima.

### 6.2 Disponibilidad

- Un hostal tiene **tipos de cuarto**, que es lo que el cliente ve y elige, y **cuartos**, que son las unidades físicas (201, 202…).
- Si cada cuarto es distinto, se crea un tipo por cuarto. Así el cliente siempre ve fotos del cuarto que va a recibir.
- Un cuarto puede estar ocupado por cuatro motivos: una reserva (incluida la retención mientras se paga), un cliente directo, la limpieza o estar fuera de servicio.
- **Regla central, aplicada por la base de datos:** dos ocupaciones del mismo cuarto nunca se cruzan en el tiempo.
- Cada reserva bloquea el cuarto hasta la hora de salida más el tiempo de limpieza.
- Un tipo de cuarto está disponible si al menos una de sus unidades está libre durante todo el rango pedido.
- Al reservar, el servidor asigna una unidad. Recepción puede cambiarla por otra libre del mismo tipo.

### 6.3 Precio

- Total = precio del bloque + extras.
- Lo calcula el servidor con las tarifas vigentes. La app nunca envía precios.
- La reserva guarda una copia del precio cobrado. Si el hostal cambia sus tarifas después, la reserva no cambia.
- Los montos son en soles y se guardan en céntimos, como números enteros.

### 6.4 Pago

1. El cliente confirma. El servidor crea la reserva en estado "pendiente de pago" y retiene el cuarto 10 minutos.
2. La app abre el pago del conector activo (demo o pasarela real).
3. El conector avisa al servidor. Solo entonces la reserva pasa a "confirmada" y se emite el código. Pulsar un botón en la app no confirma nada por sí solo.
4. Si no se paga a tiempo, la reserva vence y el cuarto se libera.
5. Reintentos, avisos repetidos o cierre de la app producen una sola reserva y un solo cobro.

Con el interruptor "pago en el hostal" encendido, la reserva nace confirmada y el cobro lo hace el hostal.

### 6.5 Ingreso y salida

- Cada reserva confirmada tiene un código corto y un QR, visibles en "Mis reservas" incluso sin conexión.
- Recepción escanea el QR o escribe el código. El servidor valida que sea de ese hostal, que la reserva esté confirmada, que esté en horario y que no se haya usado antes.
- Se puede ingresar desde 15 minutos antes, si el cuarto ya está libre.
- Si el cliente no llega dentro de los 30 minutos posteriores a su hora, la reserva pasa a "no llegó" y el cuarto se libera.
- El tiempo corre desde la hora reservada, no desde la llegada.
- La salida la marca recepción, o se registra sola al terminar el tiempo. El cuarto pasa a limpieza y vuelve a estar libre cuando recepción lo marca limpio o vence el tiempo de limpieza.

### 6.6 Cancelación y reembolso

- El cliente recibe reembolso total si cancela hasta 1 hora antes de su hora de llegada.
- Si reservó para dentro de menos de 1 hora, tiene 5 minutos de gracia desde el pago.
- Pasados esos plazos no hay reembolso desde la app; queda la vía de soporte.
- Si cancela el hostal o el administrador, el reembolso es total.
- Ninguna reserva pagada se borra: cambia de estado y queda enlazada a su reembolso.

### 6.7 Extras

- Cada hostal administra su propia carta, con sus precios.
- La reserva guarda cada producto con su cantidad y el precio del momento.
- Recepción ve qué preparar y marca "listo en el cuarto". Si un producto falta, lo marca "no disponible" y ese monto se reembolsa.
- Los licores se ofrecen solo si la plataforma y el hostal los activan.

### 6.8 Estados de la reserva

```
pending_payment ──pago aprobado──▶ confirmed ──ingreso──▶ checked_in ──salida──▶ completed
       │                               │
       └── vence ──▶ expired           ├── cancelación ──▶ cancelled
                                       └── no llega ────▶ no_show
```

El estado del pago se lleva aparte: `created`, `pending`, `paid`, `failed`, `refunded`.

---

## 7. Datos

Tablas previstas, agrupadas por tema. Las columnas se definen en cada etapa, dentro de las migraciones.

| Grupo | Tablas | Para qué |
|---|---|---|
| Personas | `profiles`, `lodging_members`, `lodging_invites`, `admins` | Cuenta, pertenencia a un hostal como dueño o recepcionista, invitaciones, administradores |
| Oferta | `lodgings`, `lodging_photos`, `room_types`, `room_type_photos`, `rooms`, `rates`, `products` | Hostal, tipos de cuarto con fotos etiquetadas, unidades físicas, tarifas por bloque, carta de extras |
| Reservas | `bookings`, `booking_items`, `room_occupancy`, `booking_events` | Reserva, extras pedidos, ocupación de cada cuarto, historial de cambios |
| Dinero | `payments`, `payment_events`, `refunds`, `payouts`, `lodging_payout_accounts` | Cobros, avisos del conector, reembolsos, liquidaciones al hostal y su cuenta de destino |
| Operación | `notifications`, `device_tokens`, `support_cases`, `audit_log` | Avisos, teléfonos registrados para push, incidencias, registro de acciones sensibles |
| Configuración | `app_settings`, `districts` | Comisión, tiempos, duraciones, conectores activos; distritos de Lima y Callao |

Implementado en la parte 1B: `profiles`, `admins` y `app_settings`, con las funciones `confirm_adult` y `get_public_settings`. En la etapa 2: `districts`, `lodgings`, `lodging_members`, `room_types`, `rooms`, `rates`, `products`, `lodging_photos` y `room_type_photos`, con `create_lodging`, `submit_lodging`, `admin_review_lodging` y `save_room_type`. El resto sigue propuesto.

Las tablas que la app nunca debe leer ni escribir directamente, como `admins` y `app_settings`, viven en un esquema `private` que la API no expone. Las reglas para escribir migraciones están en `supabase/README.md`.

Reglas de integridad:

- **`room_occupancy` es la única fuente de verdad de la disponibilidad.** Reservas, clientes directos, limpieza y mantenimiento escriben ahí, y una restricción de exclusión impide que dos filas del mismo cuarto se crucen.
- La ubicación de cada hostal se guarda como punto geográfico (PostGIS) con índice espacial.
- Para publicar un tipo de cuarto se exige al menos una foto de habitación y una de baño, y una de jacuzzi si lo declara.
- Todas las tablas tienen seguridad por fila (RLS) activa.
- Reservas, pagos, ocupación y estados solo se modifican mediante funciones del servidor.
- El contenido del hostal (cuartos, tarifas, carta) lo edita su dueño directamente, limitado por RLS y validaciones.
- El recepcionista ve del cliente solo el nombre y el código de la reserva.

---

## 8. Operaciones del servidor

| Operación | Quién | Qué garantiza |
|---|---|---|
| `search_lodgings` | Cualquiera | Devuelve hostales cercanos con cuarto libre para la hora y duración pedidas, con precio y distancia |
| `get_quote` | Cualquiera | Calcula el total de cuarto más extras con tarifas vigentes |
| `create_booking` | Cliente | En una sola transacción: revalida disponibilidad, asigna unidad, calcula precio, crea reserva y retención |
| `payments-start` | Cliente | Abre el cobro en el conector activo |
| `payments-webhook` | Conector | Verifica la firma, confirma el pago una sola vez y confirma la reserva |
| `cancel_booking` | Cliente, hostal, admin | Aplica las reglas de cancelación y dispara el reembolso |
| `host_check_in` | Dueño, recepcionista | Valida el código y registra el ingreso una única vez |
| `host_check_out`, `host_mark_clean` | Dueño, recepcionista | Cierra la estadía y libera el cuarto |
| `host_block_room` | Dueño, recepcionista | Ocupa un cuarto para un cliente directo o por mantenimiento |
| `host_set_item_status` | Dueño, recepcionista | Marca un extra como listo o no disponible |
| `invite_staff`, `accept_invite`, `revoke_staff` | Dueño, invitado | Gestiona el personal del hostal |
| `submit_lodging`, `admin_review_lodging` | Dueño, admin | Envía el hostal a revisión y lo publica o rechaza |
| `admin_create_payout`, `admin_mark_payout_paid` | Admin | Calcula y registra la liquidación a un hostal |
| `delete_my_account` | Cualquier cuenta | Elimina la cuenta y sus datos personales |
| Tareas automáticas | Servidor | Vence retenciones impagas, marca "no llegó", cierra estadías terminadas, envía recordatorios |

---

## 9. Conectores: demo ahora, real después

Cada servicio externo que cuesta dinero o exige un trámite queda detrás de un conector. El conector tiene una implementación demo, hecha por nosotros y gratuita, y una real que se activa por configuración. Las pantallas y las reglas no cambian al conectar.

| Conector | Demo (ahora) | Real (después) | Qué hace falta |
|---|---|---|---|
| Pagos | Pasarela demo: pantalla de cobro ficticio con resultado aprobado, rechazado o vencido | Culqi, Izipay o Mercado Pago, con Yape y tarjeta | RUC, cuenta aprobada en la pasarela, comisión por venta |
| Verificación de celular | Código fijo de prueba | SMS o WhatsApp | Proveedor de mensajes, costo por mensaje |
| Push en Android | Firebase, gratuito | No cambia | Proyecto de Firebase |
| Push en iPhone | Avisos dentro de la app | Push real | Cuenta de desarrollador de Apple |
| Inicio de sesión con Apple | Oculto | Activo | Cuenta de desarrollador de Apple |
| Correo de la app (confirmar cuenta, recuperar contraseña) | Registro sin correo de confirmación; captura local en pruebas | Servicio de correo | Dominio propio |
| Teselas del mapa | OpenStreetMap | Proveedor con garantía de servicio | Se decide al lanzar |
| Monitoreo de errores | Apagado | Sentry, plan gratuito | Cuenta gratuita |
| Servidor | Supabase gratuito | Supabase Pro | Unos US$ 25 al mes |

Reglas de seguridad de los conectores:

1. Cuando un conector demo está activo, la app muestra un rótulo "DEMO" permanente.
2. El entorno de producción se niega a funcionar con el conector demo de pagos o de verificación de celular.
3. Las llaves de los servicios reales viven como secretos del servidor. Nunca en la app ni en el repositorio.
4. Cada conector real se prueba primero en el modo de pruebas del proveedor.

---

## 10. Estructura de carpetas

```
ALPASO-J-/
├─ README.md
├─ AGENTS.md                    reglas de trabajo para agentes y colaboradores
├─ docs/
│  ├─ ESTRUCTURA.md             este documento
│  └─ pruebas-locales/          instrucciones de cada parte para el agente local
├─ reportes/                    resultados que sube el agente local
├─ apps/
│  ├─ mobile/                   la app Flutter (Cliente y Negocio)
│  │  ├─ lib/
│  │  │  ├─ app/                arranque, rutas, tema, configuración por entorno
│  │  │  ├─ core/               errores, red, ubicación, permisos, formato de soles y fechas
│  │  │  ├─ design/             sistema de diseño: colores, tipografía, componentes
│  │  │  └─ features/
│  │  │     ├─ auth/            C1
│  │  │     ├─ explore/         C2: mapa, lista, filtros
│  │  │     ├─ lodging/         C3 y C4: ficha de hostal y de cuarto
│  │  │     ├─ booking/         C5: reservar, extras, pago, confirmación
│  │  │     ├─ my_bookings/     C6
│  │  │     ├─ profile/         C7
│  │  │     └─ business/        N1 a N7
│  │  │        ├─ onboarding/   rooms/   catalog/   today/
│  │  │        └─ bookings/     staff/   earnings/
│  │  ├─ test/                  pruebas unitarias, de pantalla y de imagen
│  │  ├─ integration_test/      recorridos completos en emulador y simulador
│  │  └─ android/  ios/  web/
│  ├─ admin/                    panel web (etapa 6)
│  └─ site/                     páginas legales (etapa 6)
├─ supabase/
│  ├─ migrations/               esquema versionado; se aplica solo
│  ├─ functions/                pagos, avisos, eliminación de cuenta
│  │  └─ _shared/connectors/    implementaciones demo y real de cada conector
│  ├─ tests/                    pruebas de reglas y permisos
│  └─ seed.sql                  datos de prueba de Lima
├─ e2e/                         recorridos en navegador sobre la app web
├─ tools/                       scripts de apoyo
└─ .github/workflows/           pruebas y compilación automáticas
```

Cada carpeta de `features/` se divide igual:

- `data/`: comunicación con el servidor.
- `domain/`: modelos y reglas.
- `presentation/`: pantallas y su estado.

---

## 11. La app por dentro

| Necesidad | Elección propuesta |
|---|---|
| Estado | Riverpod |
| Navegación | go_router |
| Modelos | freezed y json_serializable |
| Servidor | supabase_flutter |
| Mapa y ubicación | flutter_map, latlong2, geolocator |
| Fotos | image_picker con compresión antes de subir; caché de imágenes |
| Código de ingreso | qr_flutter para mostrar, mobile_scanner para leer |
| Avisos | firebase_messaging y avisos locales |
| Textos | Centralizados en archivos de traducción, en español |

Las versiones exactas quedan fijadas en `apps/mobile/pubspec.lock`.

Decisiones tomadas al crear el proyecto (parte 1A, implementadas):

- **Flutter 3.50 estable.** Desde esta versión Material se importa de `package:material_ui/material_ui.dart`; el import anterior está obsoleto.
- **Identificador `pe.alpaso.app`** en Android y iOS. Es la propuesta de la sección 17 y se puede cambiar hasta el día de publicar.
- **Marca:** se conservan los colores de la versión anterior (oro, carbón y perla), en tema oscuro. La tipografía Inter viaja dentro de la app y no se descarga al abrirla.
- **Textos** centralizados en `lib/l10n/app_es.arb`.

La app tiene dos entornos, elegidos al compilar con un archivo de `apps/mobile/config/`:

- **demo**: muestra la cinta "DEMO" sobre todas las pantallas. Puede correr sin servidor.
- **prod**: la que irá a las tiendas. Exige servidor con https y no arranca con conectores demo.

Decisiones de la parte 1C (cuentas en la app, implementadas):

- **Registro con correo y contraseña**, de al menos 8 caracteres, igual que la regla del servidor. Google y Apple llegan cuando se conecten (sección 9).
- **El registro exige marcar "Confirmo que tengo 18 años o más".** La app llama entonces a `confirm_adult`, y la fecha la pone el servidor. Si esa llamada falla, el perfil vuelve a pedir la confirmación con un botón. La app no puede escribir `adult_confirmed_at` ni `is_blocked`: lo impiden los permisos de la base.
- **Sin correo de confirmación.** El servicio de cuentas entrega la sesión al registrarse. Así está el servidor local y así debe quedar el entorno demo (parte 1D) mientras no haya servicio de correo (sección 9). Si el servidor pidiera confirmar el correo, la app lo explica en vez de fallar en silencio.
- **La sesión se guarda en el teléfono** y se recupera al abrir la app.
- **Perfil (C7):** nombre editable, correo, estado de la mayoría de edad, aviso de cuenta bloqueada, cierre de sesión y paso al modo negocio. Sin servidor configurado, el perfil avisa que las cuentas no están disponibles.
- **Direcciones:** `/ingresar` y `/registro`.
- **Los errores del servidor se traducen a mensajes en español.** El texto técnico nunca se muestra.
- **Android:** el permiso de internet va en todas las compilaciones. Solo la compilación de depuración puede usar http, y solo hacia el servidor local (`10.0.2.2`, `127.0.0.1`).

Pendiente para la parte de publicación: que la variante demo se instale con nombre e identificador propios ("Al Paso DEMO"), para convivir en el mismo teléfono con la de tiendas. Requiere configuración nativa de Android y de iOS que debe comprobarse en una Mac.

---

## 12. Entornos

| Entorno | Dónde vive | Para qué | Costo |
|---|---|---|---|
| Local | Contenedores Docker, en la nube del agente y en la automatización | Pruebas automáticas contra un servidor completo | Ninguno |
| Demo | Proyecto gratuito de Supabase, región São Paulo. Lo mantiene al día `.github/workflows/demo.yml`; guía en `docs/ENTORNO-DEMO.md` | Probar en teléfonos reales con pagos demo. El APK se descarga de la página de descargas del repositorio ("Al Paso DEMO") | Ninguno |
| Producción | Proyecto de Supabase separado | Clientes reales | Plan Pro al lanzar |

Los cambios de base de datos son archivos versionados en `supabase/migrations/`. La automatización los aplica; no se pega SQL a mano.

---

## 13. Pruebas

| Nivel | Qué comprueba | Dónde corre |
|---|---|---|
| Reglas de la base | Precio calculado en servidor, sin doble reserva, permisos por rol, estados, retenciones | Nube del agente y automatización |
| Funciones | Pago demo, avisos repetidos del conector, reembolsos | Nube del agente y automatización |
| Unitarias | Lógica, validaciones, formatos | Nube del agente y automatización |
| Pantallas | Cada pantalla en sus estados: cargando, vacía, con error, con datos | Nube del agente y automatización |
| App con servidor | Que la app y el servidor se entienden, contra el servidor local | Nube del agente y automatización |
| Recorrido en navegador | Buscar, reservar, pagar en demo, ver código, ingresar en recepción | Nube del agente y automatización |
| Emulador Android | El mismo recorrido en un Android emulado; genera el APK | GitHub Actions |
| Simulador iPhone | Que iOS compila y el recorrido corre | GitHub Actions o Codemagic, a demanda |
| Manual | GPS real, cámara, fluidez, avisos | El dueño, con una lista corta por etapa |

El agente de la nube no puede correr emuladores ni tocar un teléfono real. Por eso los dos niveles de emulador viven en la automatización y la revisión manual es del dueño.

Una etapa se da por terminada cuando sus pruebas automáticas pasan, hay evidencia (resultados y capturas) y el dueño completó su lista manual.

---

## 14. Forma de trabajo

Decidido por el dueño el 14/11/2026: los dos agentes trabajan de forma autónoma, el trabajo se divide en partes cortas y cada parte termina con un prompt para el agente local.

- El **agente de la nube** escribe el código y las pruebas, las ejecuta y sube los cambios a GitHub.
- El **agente local**, en la laptop del dueño, trae los cambios, ejecuta las pruebas en la laptop y en el teléfono, y sube su reporte. No cambia código.
- Cada etapa se divide en **partes** (1A, 1B…). Cada parte se desarrolla en una rama y se integra a `main` cuando sus pruebas pasan.
- Al terminar una parte, el agente de la nube deja las instrucciones en `docs/pruebas-locales/` y entrega al dueño un prompt corto para su chat local.
- El agente local guarda su resultado en `reportes/`. El agente de la nube lo lee antes de empezar la parte siguiente.
- Ningún secreto ni dato personal se guarda en el repositorio.
- Idioma: documentación y textos de la app en español; código, tablas y carpetas en inglés.

El detalle del traspaso está en `AGENTS.md`.

---

## 15. Etapas

| # | Etapa | Entrega | Criterio de salida |
|---|---|---|---|
| 0 | Estructura | Este documento | Aprobado por el dueño |
| 1 | Cimientos | Proyecto Flutter con variantes demo y prod, sistema de diseño, navegación base, servidor local, cuentas, automatización | Pruebas en verde; APK demo que abre, registra e inicia sesión; iOS compila en la nube |
| 2 | Negocio publica | N1, N2, N3 y aprobación mínima de hostales | Un hostal de prueba queda publicado desde la app; permisos probados |
| 3 | Cliente descubre | C2, C3, C4 con disponibilidad real | La búsqueda solo devuelve cuartos reservables; probado con cruces y limpieza |
| 4 | Reserva y pago demo | C5, C6: cotización, retención, pago demo, código, cancelación y reembolso demo | Sin doble reserva ni precio manipulable; recorrido completo probado |
| 5 | Recepción | N4, N5, N6: ingreso con código, salida, limpieza, cliente directo, extras, avisos | Recorrido cliente más recepción probado; un código sirve una sola vez |
| 6 | Admin, dinero y legales | Panel web, N7, liquidaciones, eliminación de cuenta, páginas legales, soporte | Un administrador aprueba, reembolsa y liquida; la cuenta se elimina de verdad |
| 7 | Endurecimiento | Rendimiento, accesibilidad, revisión de seguridad, ícono, textos, capturas de tienda | Lista manual completa en Android e iPhone reales |
| 8 | Conexión de servicios reales | Pasarela, SMS, Apple, correo, servidor de producción | Cada conector probado en el modo de pruebas del proveedor y luego en real |
| 9 | Piloto y publicación | Prueba cerrada con hostales reales, envío a Google Play y App Store | Aprobación de ambas tiendas |

Las etapas 1 a 7 se completan sin gastar. La 8 empieza cuando el dueño adquiera cada servicio y puede hacerse por partes.

### Partes de la etapa 1

Cada etapa se divide en partes al empezarla. Estas son las de la etapa 1:

| Parte | Entrega | Cómo se comprueba | Estado |
|---|---|---|---|
| 1A | Esqueleto de la app: proyecto Flutter, configuración demo y prod, tema, navegación base, primeras pruebas y automatización | Análisis y pruebas en la nube; el agente local la compila y la abre en el teléfono | Implementada. Verificado en la nube: análisis, 24 pruebas y recorrido en navegador. Falta: compilación Android y teléfono real (agente local) |
| 1B | Servidor base: Supabase local, tablas de identidad (perfiles, administradores, configuración), permisos y sus pruebas | Pruebas de reglas y permisos en la nube y en GitHub | Implementada. Verificado en la nube: 41 pruebas de reglas, que fallan si se rompe una regla a propósito, y un registro real por el servicio de cuentas local |
| 1C | Cuentas en la app: registro, inicio de sesión, confirmación de mayoría de edad y perfil | Pruebas de la app contra el servidor local | Implementada. Verificado en la nube: análisis, 54 pruebas de pantalla, 10 pruebas de la app contra el servidor local, recorrido de cuentas en navegador (9 de 9) y las pruebas de reglas del servidor sin cambios. Verificado por el agente local (19/11): análisis, pruebas, APK y recorrido en el emulador Android 16; automatización de GitHub en verde. Falta: registro real en un dispositivo, que llega con el entorno demo (1D) |
| 1D | Entorno demo: proyecto demo de Supabase con las migraciones aplicadas, APK demo descargable y compilación de iOS en la nube | Registro real desde el teléfono contra el entorno demo; iOS compila | Implementada la automatización (`.github/workflows/demo.yml`) y la guía `docs/ENTORNO-DEMO.md`. Verificado en la nube: revisión de las automatizaciones y comprobación del servidor contra el local. Verificado en GitHub: la app compila para iPhone sin firmar. Falta: que el dueño cree el proyecto demo y cargue sus datos en GitHub, la primera corrida en GitHub y el registro desde el teléfono |

La parte 1B original incluía también las cuentas en la app. Se dividió en 1B y 1C para que cada parte sea corta.

### Partes de la etapa 2

| Parte | Entrega | Cómo se comprueba | Estado |
|---|---|---|---|
| 2A | Servidor de la oferta: distritos, hostales con ubicación, personal, tipos de cuarto, cuartos, tarifas, extras; registrar, enviar a revisión y publicar | Pruebas de reglas y permisos | Implementada. Verificado en la nube: 50 pruebas pgTAP nuevas (91 en total) |
| 2B | Modo negocio en la app: mis hostales, registrar con ubicación en el mapa, editar, estado de revisión y envío | Pruebas de pantalla y de la app contra el servidor local | Implementada. Verificado en la nube: 12 pruebas de pantalla y 7 contra el servidor local |
| 2C | Tipos de cuarto con tarifas y cuartos, y carta de extras, en la app | Ídem | Implementada. Verificado en la nube: `save_room_type` con 14 pruebas pgTAP (105 en total), 76 pruebas de pantalla en total y 24 de la app contra el servidor local |
| 2D | Fotos del hostal y de cada tipo de cuarto (habitación, baño, jacuzzi), exigidas para publicar | Ídem, con el almacenamiento de fotos local | Implementada. Verificado en la nube: 16 pruebas pgTAP nuevas (121 en total), 78 pruebas de pantalla y 28 de la app contra el servidor local con almacenamiento real |
| 2E | Recorrido completo: un hostal de prueba queda publicado desde la app | Recorrido en navegador contra el servidor local; agente local en el emulador | Implementada. Verificado en la nube: `e2e/business.cjs`, 11 de 11 pasos en tres corridas seguidas (registro, hostal, fotos reales, cuarto, envío, aprobación, publicado y visible sin sesión). Corre también en GitHub. Falta: emulador (agente local) |

Decisiones de la etapa 2 (implementadas en 2A y 2B):

- **El estado del hostal solo lo cambia el servidor:** `create_lodging` lo crea en borrador, `submit_lodging` lo pasa a revisión y `admin_review_lodging` lo publica o lo rechaza con motivo.
- **Para enviar a revisión** hacen falta: al menos una foto del hostal, al menos un tipo de cuarto activo con una tarifa y un cuarto activo, y en cada tipo de cuarto con precio una foto de la habitación y una del baño (y del jacuzzi si lo tiene). Si falta algo, el servidor dice qué, y la app lo muestra en una lista.
- **Fotos:** se guardan en el almacenamiento `lodging-photos`, en una carpeta por hostal. Solo el dueño sube o borra, y solo en la carpeta de su hostal. Una fila de foto solo puede apuntar a un archivo ya subido. La app reduce cada foto a 1600 px antes de subirla. La lectura es pública porque las fotos de un hostal publicado las ve cualquiera.
- **Una cuenta puede tener hasta 3 hostales sin publicar a la vez** (configuración `max_open_lodgings_per_account`). Para registrar un hostal hay que haber confirmado la mayoría de edad.
- **La ubicación debe caer en Lima Metropolitana o Callao.** Se marca moviendo el mapa de OpenStreetMap bajo un pin fijo.
- **Hasta que exista el panel de administración (etapa 6)**, los hostales se aprueban con `npm run admin:review`, que usa la llave de servidor.
- **Sin sesión** solo se ve lo publicado. Los números de cuarto y el personal nunca son públicos.
- **Un tipo de cuarto se guarda completo o no se guarda** (`save_room_type`): datos, precios por bloque y números de cuarto en una sola operación. Un número de cuarto no se repite en el mismo hostal.
- **Precios:** se escriben en soles en la app y viajan en céntimos. Cuarto: de S/ 1 a S/ 5,000 por bloque. Extra: de S/ 0.50 a S/ 1,000.
- **Formularios:** se construyen completos (no con listas que construyen solo lo visible), para que se validen todos sus campos en cualquier tamaño de pantalla.

---

## 16. Lo que depende del dueño

| Qué | Cuándo | Costo |
|---|---|---|
| Aprobar este documento y resolver la sección 17 | Ahora | Ninguno |
| Crear el proyecto demo en Supabase y entregar sus llaves como secretos | Etapa 1 | Ninguno |
| Crear el proyecto de Firebase y el acceso con Google | Etapas 1 y 5 | Ninguno |
| Probar en su Android y en su iPhone con la lista de cada etapa | Cada etapa | Ninguno |
| Conseguir de 3 a 5 hostales para el piloto, con fotos reales | Antes de la etapa 9 | Ninguno |
| Sacar RUC y abrir cuenta en una pasarela | Antes de la etapa 8 | Comisión por venta |
| Definir con un contador cómo se emiten los comprobantes | Antes de cobrar dinero real | Por definir |
| Cuenta de Google Play | Antes de la etapa 9 | US$ 25, una vez |
| Cuenta de desarrollador de Apple | Antes de la etapa 8 | US$ 99 al año |

La Mac del instituto sirve para ver la versión de iPhone en el simulador o en el iPhone del dueño. Ninguna etapa depende de ella: iOS se compila en la nube.

---

## 17. Decisiones abiertas

| # | Decisión | Propuesta de partida |
|---|---|---|
| 1 | ¿"Noche" son 12 horas desde la llegada o un horario fijo? | 12 horas desde la llegada |
| 2 | ¿Se agrega un bloque de 3 horas? | No al inicio; queda configurable |
| 3 | ¿Con cuánta anticipación se puede reservar? | Hasta 7 días |
| 4 | ¿Cuánto se espera al cliente antes de marcar "no llegó"? | 30 minutos, sin reembolso |
| 5 | ¿Desde cuándo corre el tiempo de la estadía? | Desde la hora reservada, no desde la llegada |
| 6 | ¿Hasta cuándo se cancela con reembolso? | Hasta 1 hora antes; 5 minutos de gracia en reservas inmediatas |
| 7 | ¿Cuánto cobra la plataforma y a quién? | Porcentaje descontado al hostal en la liquidación; monto por definir |
| 8 | ¿Cada cuánto se liquida a los hostales? | Semanal, por transferencia registrada en el panel |
| 9 | ¿Se venden licores desde el inicio? | Apagado hasta validar reglas de tiendas y locales |
| 10 | Nombre e identificador de la app (no se cambia tras publicar) | "Al Paso", `pe.alpaso.app` |
| 11 | ¿El repositorio queda público o privado? | Privado. Público da automatización gratuita sin límite, pero expone el código |

---

## 18. Requisitos de tiendas y legales

Lista de control para las etapas 6 a 9. Hay que verificar cada punto en su fuente oficial al llegar ese momento y validar lo legal con asesoría.

- Eliminación de cuenta desde la app y desde una página web (lo exigen ambas tiendas).
- Si se ofrece inicio de sesión con Google en iPhone, Apple exige ofrecer también "Iniciar con Apple".
- El pago de servicios físicos como un hospedaje va por pasarela propia, no por el sistema de compras de las tiendas.
- Política de privacidad y términos publicados en una dirección web.
- Clasificación de edad para adultos en ambas tiendas.
- Google Play pide a las cuentas personales nuevas una prueba cerrada con varios participantes durante dos semanas antes de publicar.
- Ley de protección de datos personales del Perú (Ley 29733): aviso de privacidad y tratamiento de datos de ubicación y estadías.
- Libro de reclamaciones virtual, por el Código de Protección y Defensa del Consumidor.
- El registro del huésped y la verificación de su documento al ingresar son responsabilidad del hostal. La app avisa al cliente que lleve su DNI.
- Venta de licores: reglas de edad de las tiendas y normas locales, antes de activarla.
