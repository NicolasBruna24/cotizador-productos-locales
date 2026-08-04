# 🛒 Cotizador de Productos Locales

App full-stack multiplataforma (iOS, Android, Web) que conecta a productores y 
pequeños comerciantes locales con clientes cercanos.

**El problema:** muchos productores pequeños no tienen forma digital de mostrar 
su inventario ni de que los encuentren clientes cerca de ellos — todo sigue 
siendo boca a boca o redes sociales sin estructura.

**La solución:** los productores suben su catálogo, los clientes lo encuentran 
por geolocalización según cercanía, y pueden pagar directo desde la app con 
Mercado Pago.

Construido con Flutter en el frontend y Supabase (PostgreSQL + Edge Functions) 
en el backend.


![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white)

---

## 🏗️ Arquitectura y Flujo del Sistema

El proyecto implementa una arquitectura desacoplada utilizando un modelo **BaaS (Backend as a Service)** impulsado por Supabase para garantizar alta disponibilidad, sincronización en tiempo real y seguridad a nivel de datos.

## ⚡ Características Técnicas Destacadas

* **Geolocalización Inversa y Cercanía:** Implementación de consultas geoespaciales eficientes para determinar el radio de entrega y filtrar el catálogo dinámicamente según la ubicación en tiempo real del usuario.
* **Seguridad a Nivel de Fila (RLS) en PostgreSQL:** Configuración estricta de políticas de bases de datos para garantizar el cumplimiento de la privacidad, aislando por completo las operaciones CRUD de cada productor.
* **Procesamiento Serverless (Edge Functions):** Lógica de backend desacoplada en TypeScript ejecutada en el borde para procesos sensibles del sistema, optimizando el rendimiento global y la seguridad del ciclo de vida del usuario.
* **Pasarela de Pago e Integración de Webhooks:** Flujo de pago síncrono/asíncrono integrado con Mercado Pago y soporte para Deep Linking (`App Links`) para el retorno seguro del estado transaccional.
* **Validación de Identidad Local:** Lógica de negocio personalizada para la sanitización y validación algorítmica de RUT (Documento de identidad chileno).

---

## 🛠️ Stack Tecnológico

### Ecosistema Frontend
* **Core:** Flutter (Dart) para rendimiento nativo compilado.
* **Geolocalización:** `geolocator` & `geocoding` para el cálculo de coordenadas.
* **Performance:** `cached_network_image` para persistencia en caché de assets remotos y optimización de ancho de banda.
* **Navegación:** Soporte de enlaces universales para redirección de pasarelas de pago externas.

### Infraestructura Backend & DevOps
* **Motor de Base de Datos:** PostgreSQL en la nube de Supabase.
* **Serverless Compute:** Deno / Edge Functions (TypeScript).
* **Almacenamiento de Objetos:** Supabase Storage con políticas de acceso controlado.
* **Monetización:** Integración asíncrona de Google Mobile Ads.

---

## ⚙️ Configuración del Entorno de Desarrollo

### Prerrequisitos
* Flutter SDK (Versión estable más reciente).
* Cuenta activa y proyecto inicializado en Supabase.
* CLI de Supabase (Opcional, recomendado para testing de Edge Functions).

### Instrucciones de Despliegue Local

1. **Clonación del Repositorio:**
   ```bash
   git clone git@github.com:NicolasBruna24/cotizador-productos-locales.git
   cd cotizador-productos-locales
   ```

2. **Aprovisionamiento de Dependencias:**
   ```bash
   flutter pub get
   ```

3. **Inyección de Variables de Entorno:**
   Inicializa las variables de configuración de Supabase (`url` y `anonKey`) en tu punto de entrada de la aplicación (`lib/main.dart` o mediante archivo `.env` configurado).

4. **Ejecución de la Aplicación:**
   ```bash
   # Despliegue en Entorno Móvil (Android/iOS)
   flutter run

   # Despliegue en Entorno Web (Modo Debugger)
   flutter run -d chrome
   ```

---

## 📬 Contacto

¿Te interesó el proyecto o quieres conversar sobre alguna colaboración? 

- **LinkedIn:** [Nicolás Bruna Fuentealba](https://www.linkedin.com/in/nicolás-bruna-fuentealba-6086b8410?utm_source=share_via&utm_content=profile&utm_medium=member_android)
- **Email:** brunafuentealba@gmail.com
