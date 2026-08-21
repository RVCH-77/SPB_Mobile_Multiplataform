# Diagrama de Arquitectura y Flujo de Entregas

Este documento ilustra la arquitectura exacta de las tablas de la base de datos `spb` (`gestion_ruta`, `rutas_chofer_detalle`) y la extensión de `spb_entregas` (`rutas_paquetes`, `ubicaciones`).

> 📌 **Ver también:** [Diagrama de Flujo Módulo Uno por Uno](file:///c:/xampp/htdocs/SPB/docs/diagrama_flujo_uno_por_uno.md) para el detalle del flujo del operador en campo, escaneo de guía física y captura de evidencia.

---

## 1. Diagrama de Arquitectura de Datos (Campos Exactos de `spb` vs `spb_entregas`)

```mermaid
erDiagram
    %% BASE DE DATOS PRINCIPAL (spb)
    EMPLEADOS ||--o{ GESTION_RUTA : "es chofer principal"
    CLIENTES ||--o{ GESTION_RUTA : "pertenece a"
    GESTION_RUTA ||--o{ RUTAS_CHOFER_DETALLE : "contiene desglose choferes"
    EMPLEADOS ||--o{ RUTAS_CHOFER_DETALLE : "asignado como chofer/apoyo"

    %% BASE DE DATOS DEDICADA (spb_entregas)
    GESTION_RUTA ||--o{ RUTAS_PAQUETES : "paquetes individuales"
    RUTAS_CHOFER_DETALLE ||--o{ RUTAS_PAQUETES : "escaneos de paquetes"
    EMPLEADOS ||--o{ UBICACIONES_TELEMETRIA : "pings GPS en vivo"

    GESTION_RUTA {
        int id PK
        string destino
        date fecha
        int total_paquetes
        int vehiculo_id FK
        int cliente FK
        longblob manifiesto_pdf
        string ruta
        int chofer_principal_id FK
        int chofer_principal_pq
        int remisiones
        text notas
        enum estatus "'Activa'|'En Progreso'|'Completada'"
        timestamp created_at
        string usuario_guardado
        timestamp modified_at
        string usuario_modificado
        string tipo_ruta
        string zona
        int id_usuario_supervisor FK
    }

    RUTAS_CHOFER_DETALLE {
        int id_detalle PK
        int id_ruta FK
        int id_chofer FK
        enum rol "'principal'|'apoyo'"
        enum estado "'pendiente'|'en_proceso'|'terminado'"
        int paquetes_asignados
        int paquetes_exitosos
        int paquetes_fallidos
        decimal km_inicial
        decimal km_final
        string foto_km_inicial
        string foto_km_final
        string foto_cierre
        time hora_inicio
        time hora_final
        int domicilios_visitados
    }

    RUTAS_PAQUETES {
        bigint id_paquete PK
        int id_ruta FK
        int id_chofer FK
        string numero_manifiesto
        string codigo_paquete
        string descripcion
        enum estatus "'pendiente'|'exitoso'|'fallido'"
        string motivo_fallo
        decimal latitud_entrega
        decimal longitud_entrega
        float accuracy_m
        string foto_evidencia
        datetime fecha_escaneo
        timestamp created_at
    }

    UBICACIONES_TELEMETRIA {
        bigint id_ubicacion PK
        int id_usuario
        int id_operador
        decimal latitud
        decimal longitud
        float accuracy
        datetime fecha_reporte
        timestamp created_at
    }
```

---

## 2. Diagrama de Flujo Operativo Integrado

```mermaid
flowchart TD
    subgraph SUPERVISION["1. Panel de Supervisión (menu_supervisor.php - BD spb)"]
        A["Crear Registro en gestion_ruta (destino, fecha, tipo_ruta, zona, chofer_principal, cliente)"] --> B["Crear Detalle en rutas_chofer_detalle (paquetes_asignados por chofer)"]
        B --> C["Opcional: Cargar Lista de Paquetes en spb_entregas.rutas_paquetes"]
        C --> D["Generar y Descargar Manifiesto PDF (manifiesto_pdf)"]
    end

    subgraph CAMPO["2. Operación del Chofer (rutas_chofer.php & API Movil)"]
        E["Chofer Inicia Ruta: guarda hora_inicio, km_inicial, foto_km_inicial"] --> F["Ruta cambia a estado='en_proceso' y estatus='En Progreso'"]
        F --> G["Llegada al Punto de Entrega"]
        G --> H["Escaneo de Código/QR de Paquete"]
        
        H --> I{"¿Resultado de la Entrega?"}
        
        %% Exitoso
        I -- "Exitoso" --> J1["Capturar Foto de Evidencia"]
        J1 --> K1["Obtener GPS Automático (Lat, Lng, Accuracy)"]
        K1 --> L1["Guardar en spb_entregas.rutas_paquetes (estatus='exitoso')"]
        
        %% Fallido
        I -- "Fallido / No visitado" --> J2["Seleccionar Motivo de Fallo"]
        J2 --> K2["Capturar Foto de Fachada/Lugar"]
        K2 --> L2["Obtener GPS Automático (Lat, Lng, Accuracy)"]
        L2 --> M2["Guardar en spb_entregas.rutas_paquetes (estatus='fallido')"]
        
        L1 --> N["Cálculo Automático en BD spb"]
        M2 --> N
    end

    subgraph AUTO["3. Conteo Automático en rutas_chofer_detalle"]
        N --> O["Incrementar +1 a paquetes_exitosos o paquetes_fallidos"]
        O --> P{"¿(paquetes_exitosos + paquetes_fallidos) == paquetes_asignados?"}
        P -- "No" --> G
        P -- "Sí" --> Q["Habilitar Formulario de Cierre de Ruta"]
        Q --> R["Chofer registra hora_final, km_final, foto_km_final, foto_cierre"]
        R --> S["Ruta Cambia a estado='terminado' en rutas_chofer_detalle"]
        S --> T["Ruta Cambia a estatus='Completada' en gestion_ruta"]
    end

    style SUPERVISION fill:#f9f9f9,stroke:#333,stroke-width:2px
    style CAMPO fill:#e1f5fe,stroke:#0288d1,stroke-width:2px
    style AUTO fill:#e8f5e9,stroke:#388e3c,stroke-width:2px
```

---

## 3. Resumen de Campos de `gestion_ruta` Integrados

| Campo en `gestion_ruta` | Tipo | Descripción |
| :--- | :--- | :--- |
| `id` | `int (PK)` | ID único autoincrementable de la ruta |
| `destino` | `varchar(255)` | Destino (ej: "LEON", "GDL", "MTY") |
| `fecha` | `date` | Fecha programada de la ruta (`YYYY-MM-DD`) |
| `total_paquetes` | `int` | Total general de paquetes en la ruta |
| `vehiculo_id` | `int (FK)` | ID del vehículo asignado en `empleados_vehiculo` |
| `cliente` | `int (FK)` | ID del cliente en `clientes` |
| `manifiesto_pdf` | `longblob` | Archivo o datos del manifiesto en PDF |
| `ruta` | `varchar(500)` | Nombre o folio de la ruta (ej: "01", "02") |
| `chofer_principal_id` | `int (FK)` | ID del chofer titular en `empleados` |
| `chofer_principal_pq` | `int` | Paquetes asignados al chofer principal |
| `remisiones` | `int` | Número o cantidad de remisiones |
| `notas` | `text` | Observaciones adicionales de la ruta |
| `estatus` | `enum` | `'Activa'`, `'En Progreso'`, `'Completada'` |
| `tipo_ruta` | `varchar(45)` | `'Local'`, `'Foránea'` |
| `zona` | `varchar(500)` | Zona o sector delimitado |
| `id_usuario_supervisor` | `int (FK)` | ID del supervisor que creó la ruta |

---

## 4. Resumen de Campos de `rutas_chofer_detalle` Integrados

| Campo en `rutas_chofer_detalle` | Tipo | Descripción |
| :--- | :--- | :--- |
| `id_detalle` | `int (PK)` | ID único del detalle de asignación por chofer |
| `id_ruta` | `int (FK)` | Clave foránea referenciando `gestion_ruta.id` (`CASCADE DELETE`) |
| `id_chofer` | `int (FK)` | ID del chofer/operador o apoyo en `empleados` |
| `rol` | `enum` | `'principal'` (titular de la ruta) o `'apoyo'` (apoyo asignado) |
| `estado` | `enum` | `'pendiente'`, `'en_proceso'`, `'terminado'` |
| `paquetes_asignados` | `int` | Paquetes asignados individualmente a este chofer (`mis_paquetes`) |
| `paquetes_exitosos` | `int` | Conteo en tiempo real de entregas exitosas |
| `paquetes_fallidos` | `int` | Conteo en tiempo real de entregas fallidas |
| `km_inicial` | `decimal(10,2)` | Kilometraje al iniciar la ruta |
| `km_final` | `decimal(10,2)` | Kilometraje al finalizar la ruta |
| `foto_km_inicial` | `varchar(255)` | Ruta del archivo de foto KM inicial |
| `foto_km_final` | `varchar(255)` | Ruta del archivo de foto KM final |
| `foto_cierre` | `varchar(255)` | Ruta del archivo de foto de evidencia de cierre |
| `hora_inicio` | `time` | Hora de inicio de ruta |
| `hora_final` | `time` | Hora de finalización de ruta |
| `domicilios_visitados` | `int` | Cantidad de domicilios visitados en entregas fallidas |
