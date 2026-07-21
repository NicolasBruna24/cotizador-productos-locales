# cotizador_de_productos_locales

Una aplicación multiplataforma (iOS, Android y Web) diseñada para conectar a productores locales con consumidores finales, fomentando el comercio de cercanía y la economía regional.

## 🚀 ¿Qué hace el proyecto?

Esta plataforma permite a los productores digitalizar su catálogo y gestionar sus ventas de forma integral:

*   **Catálogo Dinámico:** Los usuarios pueden explorar productos filtrados por cercanía geográfica y categorías.
*   **Gestión de Productores:** Perfiles comerciales personalizables con datos de contacto (WhatsApp) y configuración de pagos (Transferencia y Mercado Pago).
*   **Sistema de Inventario:** Carga de productos con campos dinámicos por categoría, gestión de stock y soporte para sincronización offline.
*   **Pagos Integrados:** Soporta pagos en línea a través de Mercado Pago y gestión de pedidos mediante transferencias bancarias con envío de comprobantes.
*   **Herramientas de Marketing:** Generación de códigos QR para catálogos, integración con anuncios (AdMob), compartir productos y sistema de favoritos.
*   **Seguridad:** Autenticación robusta con Supabase, validación de RUT (Chile) y eliminación segura de cuentas mediante Edge Functions.

## 🛠️ Tecnologías utilizadas

### Frontend
*   **Flutter & Dart:** Desarrollo multiplataforma.
*   **Geolocator & Geocoding:** Para la detección automática de la región del usuario.
*   **Cached Network Image:** Optimización de carga de imágenes.
*   **Tutorial Coach Mark:** Guía interactiva para nuevos usuarios.
*   **App Links:** Soporte para Deep Linking (retorno de pagos y navegación).

### Backend (BaaS)
*   **Supabase:**
    *   **PostgreSQL:** Base de datos relacional con RLS (Row Level Security).
    *   **Auth:** Gestión de sesiones y recuperación de contraseñas.
    *   **Storage:** Almacenamiento optimizado de imágenes de productos.
    *   **Edge Functions (TypeScript):** Lógica de servidor para procesos sensibles como la eliminación de cuentas.

### Integraciones
*   **Mercado Pago:** Pasarela de pagos.
*   **Google Mobile Ads:** Monetización mediante banners.

## ⚙️ Instalación y Ejecución

### Prerrequisitos
*   Flutter SDK (última versión estable).
*   Un proyecto configurado en [Supabase](https://supabase.com/).

### Pasos para ejecutar

1.  **Clonar el repositorio:**
    ```bash
    git clone <tu-url-del-repositorio>
    cd cotizador-productos-locales
    ```

2.  **Instalar dependencias:**
    ```bash
    flutter pub get
    ```

3.  **Configurar Supabase:**
    Asegúrate de inicializar Supabase en tu `main.dart` con tu `url` y `anonKey`.

4.  **Ejecutar la aplicación:**
    ```bash
    # Para Android/iOS
    flutter run
    # Para Web
    flutter run -d chrome
    ```
