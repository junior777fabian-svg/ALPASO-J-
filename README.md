# Al Paso

App móvil para Android y iPhone que permite encontrar y reservar cuartos en hostales y hospedajes de Lima: por horas (4, 6 u 8), por 12 horas o por 24 horas. El cliente ve antes las fotos reales del cuarto, agrega extras que lo esperan en la habitación, paga en la app y entra con un código.

**Estado actual: Etapa 0, estructura.** Todavía no hay código.

El plano completo del proyecto está en [`docs/ESTRUCTURA.md`](docs/ESTRUCTURA.md): producto, pantallas por rol, reglas, datos, conectores, carpetas, pruebas y etapas.

## Etapas

| # | Etapa | Estado |
|---|---|---|
| 0 | Estructura | Propuesta, pendiente de aprobación |
| 1 | Cimientos | Pendiente |
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
- En el PC se descarga con `git pull` para ejecutar y probar.
- Los cambios entran a `main` por rama y Pull Request, con las pruebas en verde.
- Ningún secreto (llaves, contraseñas, archivos de firma) se guarda en el repositorio.

Las reglas completas para agentes y colaboradores están en [`AGENTS.md`](AGENTS.md).
