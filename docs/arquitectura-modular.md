# Arquitectura orientada a módulos (SPB)

## Dominios funcionales y módulos

- Autenticación y sesiones
- Usuarios y roles/permisos
- Empleados (RRHH)
- Vehículos
- Mantenimientos
- Rutas y logística
- Paquetes y entregas
- Clientes y proveedores
- Predial/escáner
- Reportes y exportaciones
- Dashboard/estadísticas/notificaciones

## Estructura modular base

Cada módulo usa la misma estructura:

- `Presentation/` páginas/controladores HTTP
- `Application/` casos de uso
- `Domain/` reglas de negocio y validaciones
- `Infrastructure/` acceso a BD, archivos e integraciones

## Núcleo compartido (`app/Core` y `app/Shared`)

- `Config.php`: carga de configuración global reutilizable
- `DatabaseManager.php`: acceso unificado a `mysqli` y `PDO`
- `SessionAuth.php`: autenticación y timeout de sesión
- `JsonResponse.php`: respuestas JSON estandarizadas
- `ErrorHandler.php`: manejo centralizado de excepciones
- `Shared/Support`: utilidades de fechas y rutas
- `Shared/UI/Layout.php`: plantilla estándar con `templates/header3.php`

## Contratos y desacoplamiento

- Contrato común de módulo: `app/Contracts/ModuleInterface.php`
- Catálogo de módulos y fases: `app/Modules/ModuleRegistry.php`
- Los endpoints legacy ahora delegan a controladores por módulo (sin lógica cruzada directa)

## Migración incremental

- **Fase 1 (implementada):** Vehículos + Mantenimientos
  - `database/guardar_vehiculo.php` -> módulo `Vehiculos`
  - `database/actualizar_vehiculo.php` -> módulo `Vehiculos`
  - `database/guardar_mantenimiento.php` -> módulo `Mantenimientos`
  - `database/api_mantenimientos.php` -> módulo `Mantenimientos`
  - `api_mantenimientos.php` (raíz) agregado para compatibilidad
- **Fase 2:** Empleados + Usuarios/Roles
- **Fase 3:** Paquetes/Rutas/Clientes/Proveedores
- **Fase 4:** Reportes/Dashboard/Predial

## Gobernanza técnica mínima

### Convenciones
- Mantener estructura por capas por módulo
- Evitar lógica de negocio en scripts HTTP
- Reutilizar `app/Core` para capacidades transversales

### Seguridad
- Validar método HTTP y entradas requeridas
- Centralizar respuestas JSON de error
- Mantener controles de sesión/permisos por módulo
- Sanitizar entradas antes de persistir

### Pruebas funcionales sugeridas
- Crear/editar vehículo (con y sin fotos)
- Alta/edición de mantenimiento
- Consulta JSON de mantenimientos
- Pruebas de compatibilidad de rutas legacy
