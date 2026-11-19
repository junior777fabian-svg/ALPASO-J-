# Páginas públicas de Al Paso

Sitio estático, sin compilación: términos, privacidad, cómo eliminar la cuenta y el Libro de Reclamaciones. Las tiendas exigen que la eliminación de cuenta y la política de privacidad estén en una dirección web.

| Archivo | Qué es |
|---|---|
| `index.html` | Portada con los enlaces |
| `terminos.html`, `privacidad.html` | **Borradores** para revisión legal |
| `eliminar-cuenta.html` | Cómo eliminar la cuenta, con y sin la app |
| `libro-de-reclamaciones.html` | Formulario que registra en `submit_complaint` y muestra el número |
| `config.js` | Dirección del servidor y llave publicable. Vacío en el repositorio |

Para probarlo con el servidor local, desde la raíz: `node e2e/site.cjs`. Se publica en cualquier hosting estático cuando el dueño tenga dominio (etapa 8).
