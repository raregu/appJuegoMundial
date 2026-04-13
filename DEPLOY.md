# 🚀 Deploy a Vercel

## Archivos necesarios
- `index.html` — la app completa
- `vercel.json` — configuración de rutas y caché

## Pasos

### 1. Crear cuenta en Vercel
Andá a https://vercel.com y creá una cuenta gratuita (podés entrar con GitHub, GitLab o email).

### 2. Subir el proyecto

**Opción A — Sin GitHub (más rápido):**
1. Instalá Vercel CLI: `npm install -g vercel`
2. Desde la carpeta del proyecto: `vercel`
3. Seguí las preguntas (Project name, etc.)
4. Te da una URL pública tipo `https://prode-mundial.vercel.app`

**Opción B — Drag & Drop (sin instalar nada):**
1. Andá a https://vercel.com/new
2. Arrastrá la carpeta del proyecto al área de upload
3. Listo — te da la URL en segundos

**Opción C — GitHub (recomendado para actualizaciones):**
1. Subí la carpeta a un repositorio GitHub
2. En Vercel → New Project → Import from GitHub
3. Cada `git push` actualiza la app automáticamente

### 3. Configurar Supabase (OBLIGATORIO)

Sin este paso el login no va a funcionar en producción.

1. Andá a tu proyecto en https://supabase.com
2. **Authentication → URL Configuration**
3. En **"Site URL"** poné tu URL de Vercel: `https://tu-app.vercel.app`
4. En **"Redirect URLs"** agregá: `https://tu-app.vercel.app`
5. Guardá

### 4. Listo 🎉

Compartí la URL con tus usuarios. Cada empresa/grupo puede registrarse,
crear su juego y compartir el código de invitación.

---

## Actualizaciones futuras

Si usaste la Opción C (GitHub), solo hacé `git push` y Vercel redeploya solo.
Si usaste drag & drop, repetí el proceso de subida con los archivos nuevos.

## Notas
- El servidor `servidor.js` ya NO se usa en producción (era solo para desarrollo local)
- Vercel maneja HTTPS automáticamente, sin configuración extra
- El plan gratuito de Vercel soporta tráfico ilimitado para archivos estáticos
