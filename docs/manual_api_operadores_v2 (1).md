# 🌐 Documentación Oficial - API REST Móvil para Operadores SPB (v2.0 Clean Architecture)

Este manual detalla los **Endpoints RESTful JSON** y la **Arquitectura Modular Clean Code** para la **Aplicación Móvil del Operador** (Android / iOS / Flutter / React Native / PWA).

---

## 🏗️ Arquitectura Modular (Clean Code Pattern)

La arquitectura sigue el patrón **Domain-Driven Design / Clean Architecture**, desacoplando la capa de controladores (Endpoints HTTP), la capa de negocio (`Services`) y la capa de datos (`Repositories`):

```
c:\xampp\htdocs\SPB\
├── app/
│   └── Modules/
│       └── Operadores/
│           ├── Domain/
│           │   └── ApiResponse.php           <-- Formateador estandarizado JSON & CORS
│           ├── Application/
│           │   └── OperadorService.php       <-- Lógica de negocio de autenticación y entregas
│           └── Infrastructure/
│               └── OperadorRepository.php    <-- Consultas SQL y persistencia en BD
├── api/
│   ├── login.php                             <-- Endpoint Oficial de Autenticación Móvil
│   ├── me.php                                <-- Verificación de Token / Perfil
│   └── operadores/                           <-- Módulo de Operaciones y Entregas
│       ├── rutas.php
│       ├── detalles_ruta.php
│       ├── actualizar_entrega.php
│       └── estado_ruta.php
```

---

## 🔑 Estructura Base de los Endpoints

* **URL Base en Desarrollo:** `http://localhost/SPB/api/operadores/`
* **URL Base en Red Local / Staging:** `http://<IP_SERVIDOR>/SPB/api/operadores/`
* **Formato de Petición:** `POST` / `GET` con `Content-Type: application/json`
* **Formato de Respuesta:** `JSON` UTF-8
* **Soporte CORS:** Habilitado (`Access-Control-Allow-Origin: *`)

---

## 📋 Resumen de APIs Disponibles

| Método | Endpoint | Descripción | Clase Delegate |
| :--- | :--- | :--- | :--- |
| `POST` | `login.php` | Autenticación del operador con usuario y contraseña | `OperadorService::login()` |
| `GET` | `rutas.php?id_chofer={id}` | Obtener lista de rutas asignadas al operador | `OperadorService::obtenerRutas()` |
| `GET` | `detalles_ruta.php?id_ruta={id}&id_chofer={id}` | Consultar paquetes y estado de una ruta | `OperadorService::obtenerDetallesRuta()` |
| `POST` | `actualizar_entrega.php` | Registrar entrega exitosa/fallida con foto Base64 y GPS | `OperadorService::actualizarEntrega()` |
| `POST` | `estado_ruta.php` | Iniciar o finalizar una ruta | `OperadorService::actualizarEstadoRuta()` |

---

## 1. 🔑 Endpoint 1: Autenticación (`login.php`)

* **URL:** `POST api/operadores/login.php`
* **Headers:** `Content-Type: application/json`

### Petición JSON:
```json
{
  "usuario": "FranciscoGutiérrez",
  "password": "reW72Q9s0"
}
```

### Respuesta Exitosa (`200 OK`):
```json
{
  "success": true,
  "message": "Autenticación exitosa",
  "data": {
    "id_usuario": 15,
    "usuario": "FranciscoGutiérrez",
    "rol": "operador",
    "id_chofer": 116,
    "nombre_chofer": "FRANCISCO GUTIÉRREZ",
    "token": "7a3b4c9e8f1d2a3b4c5d6e7f8a9b0c1d",
    "fecha_login": "2026-08-18 20:25:00"
  }
}
```

---

## 2. 🚚 Endpoint 2: Rutas Asignadas (`rutas.php`)

* **URL:** `GET api/operadores/rutas.php?id_chofer=116`
* **Respuesta Exitosa (`200 OK`):**
```json
{
  "success": true,
  "message": "Rutas obtenidas correctamente",
  "total_rutas": 1,
  "rutas": [
    {
      "id_ruta": 261,
      "codigo_ruta": "234423",
      "destino": "LEON",
      "fecha": "2026-08-19",
      "rol_chofer": "Apoyo",
      "estado_chofer": "terminado",
      "estatus_general": "Completada",
      "paquetes_totales": 4,
      "paquetes_exitosos": 4,
      "paquetes_fallidos": 0,
      "paquetes_pendientes": 0,
      "progreso_porcentaje": 100.0
    }
  ]
}
```

---

## 3. 📦 Endpoint 3: Detalles y Lista de Paquetes (`detalles_ruta.php`)

* **URL:** `GET api/operadores/detalles_ruta.php?id_ruta=261&id_chofer=116`
* **Filtro Opcional:** `&codigo=9786079250614`
* **Respuesta Exitosa (`200 OK`):**
```json
{
  "success": true,
  "message": "Detalles de la ruta obtenidos correctamente",
  "ruta": {
    "id_ruta": 261,
    "codigo_ruta": "234423",
    "destino": "LEON",
    "fecha": "2026-08-19",
    "estatus": "Completada",
    "chofer_principal": "MARCO POLO MACIAS"
  },
  "resumen": {
    "total_paquetes": 4,
    "exitosos": 4,
    "fallidos": 0,
    "pendientes": 0
  },
  "paquetes": [
    {
      "id_paquete": 76,
      "id_chofer": 116,
      "codigo_paquete": "PK-R261-C29-001",
      "guia_fisica_supervisor": "9786079250614",
      "guia_fisica_operador": "9786079250614",
      "coincide_guia": true,
      "estatus": "exitoso",
      "foto_evidencia_url": "uploads/evidencias/evid_paq_76_1787094663.jpg",
      "motivo_fallo": null,
      "latitud": 21.121904,
      "longitud": -101.682531,
      "precision_m": 12.5,
      "fecha_escaneo": "2026-08-18 21:51:00"
    }
  ]
}
```

---

## 4. ⚡ Endpoint 4: Registrar Entrega en Campo (`actualizar_entrega.php`)

* **URL:** `POST api/operadores/actualizar_entrega.php`
* **Headers:** `Content-Type: application/json`

### Petición JSON:
```json
{
  "id_paquete": 76,
  "codigo_escaneado": "9786079250614",
  "id_ruta": 261,
  "id_chofer": 116,
  "estatus": "exitoso",
  "foto_evidencia": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQ...",
  "latitud": 21.121904,
  "longitud": -101.682531,
  "precision": 8.4
}
```

### Respuesta Exitosa (`200 OK`):
```json
{
  "success": true,
  "message": "Entrega registrada correctamente como EXITOSO",
  "paquete": {
    "id_paquete": 76,
    "codigo_paquete": "PK-R261-C29-001",
    "guia_supervisor": "9786079250614",
    "codigo_escaneado_operador": "9786079250614",
    "match_guia": true,
    "estatus": "exitoso",
    "foto_evidencia_url": "uploads/evidencias/evid_paq_76_1787094663.jpg",
    "latitud": 21.121904,
    "longitud": -101.682531,
    "fecha_escaneo": "2026-08-18 20:25:00"
  }
}
```

---

## 5. 🚩 Endpoint 5: Cambiar Estado de Ruta (`estado_ruta.php`)

* **URL:** `POST api/operadores/estado_ruta.php`
* **Headers:** `Content-Type: application/json`

### Petición JSON (Iniciar Ruta - Formato V1 o V2):
```json
{
  "id_ruta": 261,
  "id_chofer": 116,
  "accion": "iniciar_ruta",
  "kilometraje": 12450.5,
  "foto_odometro": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQ..."
}
```
*Nota: También se aceptan los nombres de campos Formato V1 (`km_inicial` y `foto_km_inicial`) así como aliases de chofer/operador (`id_operador`, `chofer_id`).*

### Petición JSON (Finalizar Ruta - Formato V1 o V2):
```json
{
  "id_ruta": 261,
  "id_chofer": 116,
  "accion": "finalizar_ruta",
  "kilometraje": 12580.0,
  "foto_odometro": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQ...",
  "foto_cierre": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQ...",
  "domicilios_visitados": 4
}
```

### Respuesta Exitosa (`200 OK`):
```json
{
  "success": true,
  "message": "Estado de la ruta actualizado a 'en_proceso' exitosamente.",
  "data": {
    "id_ruta": 261,
    "id_chofer": 116,
    "estado": "en_proceso",
    "kilometraje": 12450.5,
    "foto_km": "uploads/cierre/kmi_1724198400_a1b2c3.jpg",
    "foto_cierre": null,
    "updated_at": "2026-08-20 18:10:00"
  }
}
```
