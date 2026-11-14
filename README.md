# Al Paso

App móvil para Android y iPhone que permite encontrar y reservar cuartos en hostales y hospedajes de Lima: por horas (4, 6 u 8), por 12 horas o por 24 horas. El cliente ve antes las fotos reales del cuarto, agrega extras que lo esperan en la habitación, paga en la app y entra con un código.

**Estado actual: Etapa 0, estructura.** Todavía no hay código.

El plano completo del proyecto está en [`docs/ESTRUCTURA.md`](docs/ESTRUCTURA.md): producto, pantallas por rol, reglas, datos, conectores, carpetas, pruebas y etapas.

## Etapas

| # | Etapa | Estado |
|---|---|---|
| 0 | Estructura | Entregada |
| 1 | Cimientos | En curso (partes 1A, 1B, 1C) |
| 2 | Negocio publica | Pendiente |
| 3 | Cliente descubre | Pendiente |
| 4 | Reserva y pago demo | Pendiente |
| 5 | Recepción | Pendiente |
| 6 | Admin, dinero y legales | Pendiente |
| 7 | Endurecimiento | Pendiente |
| 8 | Conexión de servicios reales | Pendiente |
| 9 | Piloto y publicación | Pendiente |

## Tecnologías previstas

- **App:** Flutter, un solo código para Android y iPhone (decidido).
- **Servidor:** Supabase con Postgres y PostGIS (propuesto).
- **Mapa:** OpenStreetMap (propuesto).
- **Servicios de pago:** detrás de conectores. Funcionan en modo demo hasta que se adquiera el servicio real (decidido).

## Cómo se trabaja

- El agente de la nube escribe el código y las pruebas, y sube los cambios a este repositorio.
- El agente local, en la laptop, trae los cambios, ejecuta las pruebas en la laptop y en el teléfono, y sube su reporte a [`reportes/`](reportes/).
- El trabajo se divide en partes cortas. Al terminar cada una hay instrucciones para el agente local en [`docs/pruebas-locales/`](docs/pruebas-locales/).
- `main` solo avanza con trabajo probado.
- Ningún secreto ni dato personal se guarda en el repositorio.

Las reglas completas para agentes y colaboradores están en [`AGENTS.md`](AGENTS.md).
