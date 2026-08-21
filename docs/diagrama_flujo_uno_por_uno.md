# Plan de Arquitectura y Flujo de Trabajo: Módulo de Entregas "Uno por Uno" con Guía Física y Evidencia

## Resumen del Objetivo
Implementar una interfaz móvil fluida ("Uno por Uno") donde el operador entregue sus paquetes correlativamente. El sistema maneja dos códigos para cada paquete:
1. **`codigo_paquete`**: Código autogenerado del sistema (ej: `PK-R258-C29-004`).
2. **`codigo_barras_independiente`**: Código de barras físico o número de guía impreso en la caja (ej: `asdasd`, `27363ni234`).

Antes de marcar cada paquete como **Entregado**, el sistema permite vincular/escanear su **guía física** (`codigo_barras_independiente`), captura la **foto de evidencia** + **coordenadas GPS** y actualiza el registro en la base de datos, avanzando al siguiente paquete pendiente.

---

## Diagrama de Flujo del Sistema (Mermaid)

```mermaid
flowchart TD
    A[Inicio: Abre rutas_chofer_detalle.php] --> B{¿Ruta Iniciada?}
    
    %% Ruta No Iniciada
    B -- No --> C[Mostrar Botón 'Iniciar Ruta']
    C --> D[Ingresar KM Inicial + Foto KM]
    D --> E[Guardar Inicio de Ruta -> Estado: En Progreso]
    E --> F[Refrescar Pantalla]
    
    %% Ruta Iniciada
    B -- Sí --> G[Cargar Paquetes de spb_entregas.rutas_paquetes]
    G --> H[JS: Detectar y Posicionar en el PRIMER PAQUETE PENDIENTE]
    H --> I[Mostrar Tarjeta Única del Paquete Activo]
    
    %% Acciones del Paquete Activo
    I --> J{Acción del Operador}
    
    %% Vincular Código de Barras / Guía Física
    J -- Escanear / Ingresar Guía Física --> K0[Asociar Guía Física a codigo_barras_independiente]
    
    %% Opción 1: Entregar con Foto
    J -- Click 'Entregar con Foto' --> K[Abrir Modal de Evidencia #modalFotoEvidenciaPaquete]
    K0 --> K
    K --> L1[Opción A: Capturar Foto con Cámara en Vivo]
    K --> L2[Opción B: Seleccionar Imagen de Galería / Archivo]
    L1 --> M[Confirmar Entrega con Foto]
    L2 --> M
    M --> N[Obtener GPS + Enviar AJAX a actualizar_estatus_paquete.php]
    N --> O[Backend: Guardar Foto en uploads/evidencias/ + Guía Física + Marcar EXITOSO + Recalcular Conteos]
    O --> P[JS: Actualizar Card a EXITOSO + Avanzar al Siguiente Paquete Pendiente]
    
    %% Opción 2: Reportar Fallo
    J -- Click 'No Entregado / Fallo' --> Q[Abrir Modal de No Entrega #modalPaqueteFallido]
    Q --> R[Seleccionar Motivo + Visita Domiciliaria]
    R --> S[Obtener GPS + Enviar AJAX a actualizar_estatus_paquete.php]
    S --> T[Backend: Marcar FALLIDO + Recalcular Conteos]
    T --> U[JS: Actualizar Card a FALLIDO + Avanzar al Siguiente Paquete Pendiente]
    
    %% Opción 3: Escáner de Código
    J -- Escanear con Cámara / Lector Laser --> V[Buscar Paquete por codigo_paquete o codigo_barras_independiente]
    V --> W[Posicionar en la Tarjeta del Paquete Encontrado y Abrir Modal de Foto]
```

---

## Estructura de Datos en Base de Datos (`spb_entregas.rutas_paquetes`)

| Campo | Tipo | Descripción |
| :--- | :--- | :--- |
| `id_paquete` | `INT` | ID primario del paquete |
| `id_ruta` | `INT` | ID de la ruta (`gestion_ruta.id`) |
| `id_chofer` | `INT` | ID del operador asignado (`empleados.id`) |
| `numero_manifiesto` | `VARCHAR` | Número de manifiesto/ruta |
| `codigo_paquete` | `VARCHAR` | Código único del sistema (ej: `PK-R258-C29-004`) |
| **`codigo_barras_independiente`** | `VARCHAR` | Guía física escaneada/ingresada (ej: `asdasd`) |
| `estatus` | `ENUM` | `pendiente`, `exitoso`, `fallido` |
| `foto_evidencia` | `VARCHAR` | Ruta de la foto en `uploads/evidencias/` |
| `latitud_entrega` | `DECIMAL` | Latitud GPS al entregar |
| `longitud_entrega` | `DECIMAL` | Longitud GPS al entregar |
| `accuracy_m` | `DECIMAL` | Precisión en metros de la lectura GPS |

---

## Pasos de Aplicación en Código
1. **Lectura y Visualización en Tarjetas:**
   - Mostrar `codigo_paquete` en grande.
   - Mostrar campo o badge interactivo para `codigo_barras_independiente` (Guía Física escaneada).
2. **Asociación en AJAX (`marcarPaqueteExitoso`):**
   - Enviar `codigo_escaneado` junto a la foto de evidencia Base64 y GPS para guardarse en la columna `codigo_barras_independiente`.
3. **Control Anti-Bloqueos (Navegación e Interfaz):**
   - Definir `regresarSeguro()` y limpieza de `modal-backdrop` para que ningún cuadro transparente bloquee la pantalla o botones.
