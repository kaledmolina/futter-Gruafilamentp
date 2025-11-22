# App para Técnicos - Sistema Offline-First

Aplicación Flutter desarrollada para técnicos de campo con arquitectura **offline-first**, permitiendo trabajar sin conexión a internet y sincronizar automáticamente cuando se restablece la conectividad.

## 🎯 Características Principales

- ✅ **Funcionamiento completo sin conexión**: La app funciona completamente sin internet
- ✅ **Sincronización automática**: Las operaciones se sincronizan automáticamente cuando hay conexión
- ✅ **Almacenamiento local persistente**: Base de datos SQLite para almacenar órdenes y datos
- ✅ **Indicadores visuales**: El usuario siempre sabe el estado de conexión y sincronización
- ✅ **Feedback inmediato**: Los cambios se reflejan instantáneamente en la interfaz

---

## 📐 Arquitectura Offline-First

### Concepto General

La aplicación utiliza una arquitectura **offline-first**, lo que significa que:

1. **La base de datos local es la fuente de verdad principal**: Todas las operaciones se ejecutan primero en la base de datos local
2. **Las operaciones se encolan cuando no hay conexión**: Las acciones del usuario se guardan localmente y se sincronizan automáticamente cuando hay internet
3. **Sincronización bidireccional**: Se descargan datos del servidor y se suben operaciones pendientes cuando hay conexión

### Componentes Arquitectónicos

#### 1. **DatabaseService** (`lib/services/database_service.dart`)

Servicio central que gestiona la base de datos SQLite local. Utiliza `sqflite` para crear y administrar las siguientes tablas:

**Tablas principales:**

- **`orders`**: Almacena todas las órdenes de servicio con todos sus campos (ID, número de orden, cliente, direcciones, estado, etc.)
- **`pending_operations`**: Cola de operaciones pendientes de sincronizar (aceptar, cerrar, rechazar, actualizar detalles)
- **`pending_photos`**: Lista de fotos que están esperando ser subidas al servidor
- **`pending_inspections`**: Inspecciones preoperacionales pendientes de enviar
- **`sync_metadata`**: Metadatos de sincronización (última sincronización, estado actual, contadores)

**Funcionalidades clave:**

```dart
// Guardar órdenes localmente
await _dbService.saveOrders(orders);

// Obtener órdenes locales (funciona offline)
final orders = await _dbService.getOrders(status: 'en proceso');

// Agregar operación pendiente a la cola
await _dbService.addPendingOperation(
  operationType: 'accept',
  orderNumber: 'ORD-123',
  operationData: {},
);
```

#### 2. **OrderRepository** (`lib/repositories/order_repository.dart`)

Capa de abstracción que implementa el patrón **Repository**. Decide automáticamente si usar la API o datos locales:

**Lógica de decisión:**

```dart
Future<List<Orden>> getOrders({int page = 1, String status = 'todas'}) async {
  final hasConnection = await _hasConnection();
  
  if (hasConnection) {
    try {
      // 1. Intentar obtener desde la API
      final response = await _apiService.getOrders(page: page, status: status);
      final orders = response['data'] as List;
      
      // 2. Guardar en base de datos local para uso offline
      await _saveOrdersToLocal(orders);
      
      return orders;
    } catch (e) {
      // 3. Si falla la API, usar datos locales
      return await _getOrdersFromLocal(status: status);
    }
  }
  
  // 4. Sin conexión: usar datos locales
  return await _getOrdersFromLocal(status: status);
}
```

**Operaciones con encolado offline:**

- **Aceptar orden**: Actualiza el estado local inmediatamente y encola la operación si no hay conexión
- **Cerrar orden**: Cambia el estado local a "cerrada" y sincroniza cuando hay conexión
- **Actualizar detalles**: Los cambios se guardan localmente y se sincronizan después
- **Subir fotos**: Las fotos se guardan en el dispositivo y se suben automáticamente cuando hay conexión

#### 3. **SyncService** (`lib/services/sync_service.dart`)

Servicio de sincronización que se ejecuta automáticamente cuando detecta conexión a internet.

**Proceso de sincronización:**

1. **Monitoreo de conectividad**: Escucha cambios en el estado de conexión usando `connectivity_plus`
2. **Descarga de órdenes actualizadas**: Obtiene las últimas órdenes del servidor y actualiza la base de datos local
3. **Subida de operaciones pendientes**: Procesa la cola de operaciones pendientes (`pending_operations`)
4. **Subida de inspecciones**: Envía inspecciones preoperacionales pendientes
5. **Coordinación con UploadService**: Orquesta la subida de fotos pendientes

**Flujo de sincronización:**

```dart
Future<void> sync() async {
  // 1. Descargar órdenes actualizadas del servidor
  await _syncOrdersFromServer();
  
  // 2. Subir operaciones pendientes (aceptar, cerrar, etc.)
  await _syncPendingOperations();
  
  // 3. Subir inspecciones pendientes
  await _syncPendingInspections();
  
  // 4. Subir fotos pendientes
  await UploadService.instance.syncPendingUploads();
}
```

**Inicio automático:**

El servicio se inicia automáticamente al arrancar la aplicación:

```dart
// En main.dart
void main() async {
  // ...
  SyncService.instance.start();
  UploadService.instance.start();
  // ...
}
```

#### 4. **UploadService** (`lib/services/upload_service.dart`)

Servicio dedicado a la subida de fotos. Maneja la cola de fotos pendientes y notifica el estado de cada foto mediante streams.

**Características:**

- Escucha cambios de conectividad para iniciar subidas automáticamente
- Procesa fotos una por una desde la tabla `pending_photos`
- Emite eventos de estado (uploading, uploaded, error) mediante `StreamController`
- Elimina fotos locales después de subirlas exitosamente
- Maneja errores y reintentos automáticos

#### 5. **ApiService** (`lib/services/api_service.dart`)

Capa de comunicación con la API REST del servidor. Todas las peticiones HTTP pasan por este servicio, que maneja:

- Autenticación mediante tokens Bearer
- Manejo de respuestas y errores
- Endpoints para órdenes, fotos, inspecciones y perfiles

---

## 🔄 Flujo de Trabajo Offline-First

### Escenario 1: Usuario trabaja sin conexión

1. **El técnico abre la app sin internet**
   - La app carga las órdenes desde la base de datos local
   - Se muestra un indicador rojo "Sin conexión" en la barra superior

2. **El técnico acepta una orden**
   - El estado de la orden se actualiza inmediatamente a "en proceso" en la base de datos local
   - La orden aparece como "en proceso" en la interfaz (feedback inmediato)
   - Se crea un registro en `pending_operations` con tipo "accept"

3. **El técnico sube fotos**
   - Las fotos se guardan en el almacenamiento local del dispositivo
   - Se registran en la tabla `pending_photos` con estado "pending"
   - Las fotos aparecen en la galería de la orden inmediatamente

4. **El técnico cierra la orden**
   - El estado se actualiza localmente a "cerrada"
   - Se agrega una operación "close" a la cola de pendientes

5. **Se restablece la conexión**
   - `SyncService` detecta automáticamente la conexión
   - Comienza a sincronizar:
     - Descarga órdenes actualizadas del servidor
     - Sube la operación "accept" → el servidor confirma la orden como aceptada
     - Sube la operación "close" → el servidor confirma la orden como cerrada
     - `UploadService` sube las fotos pendientes una por una
   - Se eliminan las operaciones de la cola después de sincronizarlas exitosamente
   - El indicador cambia a verde "Sincronizado"

### Escenario 2: Conexión intermitente

1. **El usuario intenta una operación con conexión inestable**
   - El `OrderRepository` intenta primero usar la API
   - Si falla la petición, automáticamente recurre a guardar localmente y encolar
   - El usuario ve el cambio inmediatamente en la UI
   - La operación se sincroniza automáticamente cuando se restablece la conexión

2. **Validaciones locales**
   - Antes de aceptar una orden, se verifica localmente si ya hay otra orden en proceso
   - Se consultan tanto las órdenes con estado "en proceso" como las operaciones pendientes de "accept"
   - Esto previene aceptar múltiples órdenes incluso sin conexión

---

## 👤 Experiencia del Usuario (Técnicos)

### Indicadores Visuales

La app proporciona feedback constante sobre el estado de conexión y sincronización mediante el componente `ConnectionStatusIndicator`:

#### 🔴 **Sin Conexión**
```
[Icono wifi_off] Sin conexión
```
- Color: Rojo
- Significado: No hay conexión a internet
- Comportamiento: La app funciona completamente con datos locales

#### 🔵 **Sincronizando**
```
[Spinner] Sincronizando...
```
- Color: Azul
- Significado: Hay conexión y se están sincronizando datos
- Comportamiento: Las operaciones pendientes se están enviando al servidor

#### 🟠 **Pendientes**
```
[Icono cloud_upload] X pendiente(s)
```
- Color: Naranja
- Significado: Hay conexión pero hay operaciones esperando ser sincronizadas
- Comportamiento: Se muestra el número de operaciones en cola

#### 🟢 **Sincronizado**
```
[Icono cloud_done] Sincronizado
```
- Color: Verde
- Significado: Todo está sincronizado correctamente
- Comportamiento: No hay operaciones pendientes

### Cambios en la Experiencia del Usuario

#### ✅ Lo que NO cambia (funciona igual offline y online):

1. **Ver órdenes**: Las órdenes se muestran siempre desde la base de datos local
2. **Aceptar órdenes**: El botón funciona igual, el estado cambia inmediatamente
3. **Ver detalles**: Todos los detalles de la orden están disponibles offline
4. **Tomar fotos**: Se pueden tomar y ver fotos sin conexión
5. **Actualizar información**: Los campos de celular y observaciones se pueden editar sin internet
6. **Cerrar órdenes**: El proceso de cierre funciona igual

#### 🔄 Lo que cambia (comportamiento adaptativo):

1. **Carga inicial de órdenes**:
   - **Online**: Descarga las últimas órdenes del servidor y actualiza la base local
   - **Offline**: Muestra solo las órdenes guardadas previamente en el dispositivo

2. **Feedback de sincronización**:
   - **Online**: Los cambios se reflejan inmediatamente en el servidor
   - **Offline**: Los cambios se guardan localmente y se sincronizan después (indicador naranja muestra cuántas operaciones están pendientes)

3. **Actualización de órdenes**:
   - **Online**: Las órdenes se actualizan automáticamente desde el servidor durante la sincronización
   - **Offline**: Solo se ven las últimas órdenes descargadas (pueden estar desactualizadas)

4. **Estado de las fotos**:
   - **Online**: Las fotos se suben inmediatamente y se pueden ver en el servidor
   - **Offline**: Las fotos se guardan localmente y muestran un indicador de "pendiente" hasta sincronizarse

### Ventajas para los Técnicos

1. **Trabajo ininterrumpido**: Pueden trabajar en zonas sin señal sin preocuparse por la conexión
2. **Feedback inmediato**: Ven sus cambios reflejados instantáneamente, sin esperar confirmación del servidor
3. **Transparencia**: El indicador de estado les informa claramente qué está pasando con sus datos
4. **Sincronización automática**: No necesitan hacer nada manualmente, todo se sincroniza cuando hay conexión
5. **Datos siempre disponibles**: Las órdenes guardadas están disponibles incluso después de reiniciar la app

---

## 🛠️ Tecnologías Utilizadas

- **Flutter**: Framework de desarrollo multiplataforma
- **sqflite**: Base de datos SQLite para Flutter
- **sqflite_common_ffi**: Soporte SQLite para plataformas desktop (Windows, Linux, macOS)
- **connectivity_plus**: Monitoreo de estado de conexión a internet
- **http**: Cliente HTTP para comunicación con la API REST
- **shared_preferences**: Almacenamiento de preferencias y tokens de autenticación
- **path_provider**: Obtención de rutas para almacenamiento de archivos
- **image_picker**: Selección y captura de imágenes
- **Firebase**: Servicios de notificaciones push (FCM)

---

## 📦 Estructura de Base de Datos Local

### Tabla: `orders`
Almacena todas las órdenes de servicio sincronizadas desde el servidor.

**Campos principales:**
- `id`, `numero_orden`, `nombre_cliente`
- `ciudad_origen`, `direccion_origen`, `ciudad_destino`, `direccion_destino`
- `status` (abierta, programada, en proceso, cerrada, fallida, anulada)
- `updated_at`, `synced_at`

### Tabla: `pending_operations`
Cola de operaciones que deben sincronizarse con el servidor.

**Campos:**
- `operation_type`: "accept", "close", "reject", "update_details"
- `order_number`: Número de la orden afectada
- `operation_data`: JSON con datos adicionales de la operación
- `retry_count`: Contador de reintentos fallidos
- `last_error`: Último error si la sincronización falló

### Tabla: `pending_photos`
Fotos esperando ser subidas al servidor.

**Campos:**
- `order_number`: Orden asociada
- `image_path`: Ruta local de la foto en el dispositivo
- `sync_status`: Estado de sincronización (pending, uploading, error)

### Tabla: `pending_inspections`
Inspecciones preoperacionales pendientes de enviar.

**Campos:**
- `inspection_data`: JSON con los datos de la inspección
- `retry_count`, `last_error`

### Tabla: `sync_metadata`
Metadatos sobre el estado de sincronización.

**Claves:**
- `last_sync_orders`: Timestamp de última sincronización de órdenes
- `sync_status`: Estado actual ("idle", "syncing", "error")
- `pending_operations_count`: Número de operaciones pendientes

---

## 🔧 Mantenimiento y Extensión

### Agregar nuevas operaciones offline

1. **Agregar el método en `ApiService`** para la petición HTTP
2. **Implementar en `OrderRepository`** con lógica offline-first:
   ```dart
   if (hasConnection) {
     try {
       await _apiService.nuevaOperacion();
     } catch (e) {
       await _queueOperation('nueva_operacion', orderNumber, data);
     }
   } else {
     await _queueOperation('nueva_operacion', orderNumber, data);
   }
   ```
3. **Agregar caso en `SyncService._syncPendingOperations()`** para sincronizar la nueva operación
4. **Actualizar el estado local** inmediatamente para feedback al usuario

### Modificar esquema de base de datos

1. **Incrementar `_databaseVersion`** en `DatabaseService`
2. **Implementar `_onUpgrade()`** con las migraciones necesarias
3. **Probar la migración** en dispositivos con datos existentes

---

## 📝 Notas de Implementación

- La sincronización es **unidireccional para órdenes** (servidor → cliente) y **bidireccional para operaciones** (cliente → servidor)
- Las operaciones se procesan en orden FIFO (First In, First Out) desde la cola
- Los errores de sincronización incrementan el contador de reintentos pero no eliminan la operación de la cola
- Las fotos se eliminan del dispositivo después de subirlas exitosamente para ahorrar espacio
- La validación de "solo una orden en proceso" funciona completamente offline consultando la base de datos local

---

## 🚀 Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
