/**
 * Sube contenido educativo a Firestore usando la REST API.
 * Lee el token de acceso del Firebase CLI (firebase login).
 *
 * Uso: node upload_educational_content.js
 */

const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'oncuidar-v1';
const COLLECTION = 'educationalContent';
const SEED_FILE = path.join(__dirname, 'educational_content.json');

// ── Leer seed data ──
const items = JSON.parse(fs.readFileSync(SEED_FILE, 'utf-8'));
console.log(`📄 Leídos ${items.length} items desde ${SEED_FILE}\n`);

// ── Convertir item al formato Firestore REST ──
function toFirestoreDocument(item) {
  const fields = {};

  for (const [key, value] of Object.entries(item)) {
    if (key === 'createdAt') {
      // Timestamp
      fields[key] = { timestampValue: new Date().toISOString() };
    } else if (key === 'fileSizeBytes') {
      // Integer
      fields[key] = { integerValue: value };
    } else {
      // String (title, category, topic, body, fileUrl, fileType, imageUrl, thumbnailUrl)
      fields[key] = { stringValue: String(value) };
    }
  }

  // Agregar createdAt si no viene en el JSON
  if (!fields['createdAt']) {
    fields['createdAt'] = { timestampValue: new Date().toISOString() };
  }

  return { fields };
}

// ── Obtener token del Firebase CLI ──
function getAccessToken() {
  const configPath = path.join(
    process.env.USERPROFILE || process.env.HOME,
    '.config',
    'configstore',
    'firebase-tools.json'
  );

  if (!fs.existsSync(configPath)) {
    throw new Error(
      'No se encuentra firebase-tools.json. Ejecuta: firebase login'
    );
  }

  const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
  const token = config.tokens?.access_token;

  if (!token) {
    throw new Error('No hay access_token en firebase-tools.json. Ejecuta: firebase login');
  }

  return token;
}

// ── Subir un documento a Firestore ──
async function uploadItem(accessToken, item, index) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${COLLECTION}`;

  // ID legible: categoria_titulo (ej: video-fiebre-como-medir)
  const cleanTitle = item.title
    .toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '') // quitar acentos
    .replace(/[^a-z0-9]+/g, '-') // espacios y símbolos a guión
    .replace(/^-|-$/g, ''); // quitar guiones al inicio/final
  const docId = `${item.category.toLowerCase()}-${cleanTitle}`;

  const body = toFirestoreDocument(item);

  const response = await fetch(`${url}?documentId=${docId}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const err = await response.text();
    // Si el documento ya existe (409 Conflict) lo saltamos
    if (response.status === 409) {
      console.log(`  ⏭️  [${index}/${items.length}] ${docId} — ya existe`);
      return;
    }
    throw new Error(`HTTP ${response.status} para ${docId}: ${err}`);
  }

  console.log(`  ✅ [${index}/${items.length}] ${docId}`);
}

// ── Main ──
async function main() {
  try {
    const accessToken = getAccessToken();

    console.log(`🚀 Subiendo ${items.length} items a ${PROJECT_ID}/${COLLECTION}...\n`);

    for (let i = 0; i < items.length; i++) {
      await uploadItem(accessToken, items[i], i + 1);
      await new Promise((r) => setTimeout(r, 150));
    }

    console.log(`\n✅ ¡Todo el contenido educativo subido exitosamente!`);
  } catch (error) {
    console.error(`\n❌ Error: ${error.message}`);
    process.exit(1);
  }
}

main();
