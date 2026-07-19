/**
 * Sube las reglas de orientación a Firestore usando la REST API.
 * Lee el token de acceso del Firebase CLI (firebase login).
 *
 * Uso: node upload_rules.js
 */

const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'oncuidar-v1';
const COLLECTION = 'orientationRules';
const SEED_FILE = path.join(__dirname, 'orientation_rules.json');

// ── Leer seed data ──
const rules = JSON.parse(fs.readFileSync(SEED_FILE, 'utf-8'));
console.log(`📄 Leídas ${rules.length} reglas desde ${SEED_FILE}\n`);

// ── Convertir regla al formato Firestore REST ──
function toFirestoreDocument(rule) {
  const fields = {};
  for (const [key, value] of Object.entries(rule)) {
    if (key === 'tags') {
      fields[key] = {
        arrayValue: {
          values: value.map((v) => ({ stringValue: v })),
        },
      };
    } else {
      fields[key] = { stringValue: String(value) };
    }
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
async function uploadRule(accessToken, rule, index) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${COLLECTION}`;

  // ID legible: categoria_numero (ej: fiebre_1, emergencia_2)
  const cleanCategory = rule.category.replace(/[^a-zA-Z0-9_-]/g, '_').toLowerCase();
  const docId = `${cleanCategory}_${index}`;

  const body = toFirestoreDocument(rule);

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
      console.log(`  ⏭️  [${index}/25] ${docId} — ya existe`);
      return;
    }
    throw new Error(`HTTP ${response.status} para ${docId}: ${err}`);
  }

  console.log(`  ✅ [${index}/25] ${docId}`);
}

// ── Main ──
async function main() {
  try {
    const accessToken = getAccessToken();

    console.log(`🚀 Subiendo ${rules.length} reglas a ${PROJECT_ID}/${COLLECTION}...\n`);

    for (let i = 0; i < rules.length; i++) {
      await uploadRule(accessToken, rules[i], i + 1);
      await new Promise((r) => setTimeout(r, 150));
    }

    console.log(`\n✅ ¡Todas las reglas subidas exitosamente!`);
  } catch (error) {
    console.error(`\n❌ Error: ${error.message}`);
    process.exit(1);
  }
}

main();
