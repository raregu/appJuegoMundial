// Servidor local simple para Prode Mundial 2026
// Ejecutar con: node servidor.js
// Luego abrir: http://localhost:3000

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3000;
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css':  'text/css',
  '.js':   'application/javascript',
  '.json': 'application/json',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.ico':  'image/x-icon',
};

const server = http.createServer((req, res) => {
  // Servir index por defecto
  let filePath = '.' + req.url;
  if (filePath === './' || filePath === '.') filePath = './index.html';

  const ext = path.extname(filePath);
  const contentType = MIME[ext] || 'text/plain';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      if (err.code === 'ENOENT') {
        // Si pide cualquier ruta, devolver el HTML principal (SPA)
        fs.readFile('./index.html', (e, c) => {
          res.writeHead(200, {
            'Content-Type': 'text/html; charset=utf-8',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0'
          });
          res.end(c || 'Archivo no encontrado');
        });
      } else {
        res.writeHead(500);
        res.end('Error: ' + err.code);
      }
      return;
    }
    res.writeHead(200, {
      'Content-Type': contentType,
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0'
    });
    res.end(content);
  });
});

server.listen(PORT, () => {
  console.log('');
  console.log('  🏆 Prode Mundial 2026 - Servidor local');
  console.log('  ─────────────────────────────────────');
  console.log(`  ✅ Corriendo en: http://localhost:${PORT}`);
  console.log('  📋 Copia esa URL y ábrela en tu navegador');
  console.log('  ⛔ Para detener: Ctrl + C');
  console.log('');
});
