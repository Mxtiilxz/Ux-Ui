# Kairos API — Integration Tests

Suite de tests de integración que golpean el backend real en `http://localhost:5001`.  
Tecnología: **Python 3 + pytest + requests**.

---

## Requisitos previos

1. **Backend corriendo** en `http://localhost:5001`  
   ```bash
   cd backend
   dotnet run --project src/Kairos.API --launch-profile Development
   ```

2. **Base de datos MySQL** con el seed aplicado (se ejecuta automáticamente en la primera corrida del backend en Development).

3. **Python 3** (ya incluido en el sistema).

---

## Instalar dependencias

```bash
cd __tests__
pip install -r requirements.txt
```

---

## Ejecutar los tests

```bash
# Todos los tests
pytest

# Solo un módulo
pytest test_auth.py
pytest test_posts.py
pytest test_storage.py
pytest test_reports.py
pytest test_signalr.py

# Con salida detallada
pytest -v

# Detener al primer fallo
pytest -x
```

> Si el backend no está corriendo, **todos los tests se omiten** (SKIPPED) con el mensaje  
> `Backend not running on http://localhost:5001 — start it first.`  
> Ningún test falla por error de conexión.

---

## Credenciales de prueba (seed)

| Email | Password | Rol |
|---|---|---|
| `kairos_user1@kairos.cl` | `Kairos2026!` | student |
| `staff1@kairos.cl` | `Kairos2026!` | staff |
| `empresa@kairos.cl` | `Kairos2026!` | company |

La lista completa de usuarios del seeder está en el [README raíz](../README.md).

---

## Cobertura

| Archivo | Endpoint(s) cubiertos | Tests |
|---|---|---|
| `test_auth.py` | `POST /api/auth/login`, `POST /api/auth/register` | 14 |
| `test_posts.py` | `GET /api/posts/feed`, `POST /api/posts` | 14 |
| `test_storage.py` | `POST /api/storage/upload` | 7 |
| `test_reports.py` | `GET /api/reports/me` | 8 |
| `test_signalr.py` | `POST /hubs/chat/negotiate` | 5 |
| **Total** | | **48** |

---

## Notas

- Los tests de **storage** aceptan 200 o 500 para la carga real de imágenes: 200 si Azurite está corriendo, 500 si no — lo que se verifica es que el endpoint existe y valida el tipo de contenido correctamente (400 para tipos no permitidos).
- Los tests de **reports** aceptan 200 o 404: 404 es válido si el usuario no tiene actividad en el período solicitado.
- Los tests de **SignalR** sólo verifican el endpoint de negociación HTTP; el flujo WebSocket completo requeriría una librería adicional (`websockets`).
