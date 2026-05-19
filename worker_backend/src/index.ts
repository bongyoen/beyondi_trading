interface User {
  id: string;
  email: string;
  name: string;
  created_at: string;
}

interface Env {
  DB: D1Database;
  AUTH_SESSIONS: KVNamespace;
  BEYONDI_USERS: KVNamespace;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function errorResponse(message: string, status = 400): Response {
  return jsonResponse({ error: message }, status);
}

async function hashPassword(password: string): Promise<string> {
  const encoder = new TextEncoder();
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    encoder.encode(password),
    { name: 'PBKDF2' },
    false,
    ['deriveBits'],
  );
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' },
    keyMaterial,
    256,
  );
  const hash = Array.from(new Uint8Array(bits)).map(b => b.toString(16).padStart(2, '0')).join('');
  const saltHex = Array.from(salt).map(b => b.toString(16).padStart(2, '0')).join('');
  return `${saltHex}:${hash}`;
}

async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const [saltHex, hashHex] = stored.split(':');
  if (!saltHex || !hashHex) return false;
  const salt = new Uint8Array(saltHex.match(/.{2}/g)!.map(b => parseInt(b, 16)));
  const encoder = new TextEncoder();
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    encoder.encode(password),
    { name: 'PBKDF2' },
    false,
    ['deriveBits'],
  );
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' },
    keyMaterial,
    256,
  );
  const hash = Array.from(new Uint8Array(bits)).map(b => b.toString(16).padStart(2, '0')).join('');
  return hash === hashHex;
}

async function handleAuthRegister(request: Request, env: Env): Promise<Response> {
  try {
    const body = (await request.json()) as { email?: string; password?: string; name?: string };

    if (!body.email || !body.password || !body.name) {
      return errorResponse('email, password, and name are required');
    }

    const existing = await env.DB.prepare('SELECT id FROM users WHERE email = ?').bind(body.email).first();
    if (existing) {
      return errorResponse('A user with this email already exists', 409);
    }

    const id = crypto.randomUUID();
    const passwordHash = await hashPassword(body.password);

    await env.DB.prepare(
      'INSERT INTO users (id, email, name, password) VALUES (?, ?, ?, ?)',
    ).bind(id, body.email, body.name, passwordHash).run();

    return jsonResponse({ user: { id, name: body.name, email: body.email } }, 201);
  } catch {
    return errorResponse('Invalid request body', 400);
  }
}

async function handleAuthLogin(request: Request, env: Env): Promise<Response> {
  try {
    const body = (await request.json()) as { email?: string; password?: string };

    if (!body.email || !body.password) {
      return errorResponse('email and password are required');
    }

    const user = await env.DB.prepare(
      'SELECT id, email, name, password FROM users WHERE email = ?',
    ).bind(body.email).first<User & { password: string }>();

    if (!user) {
      return errorResponse('Invalid email or password', 401);
    }

    const valid = await verifyPassword(body.password, user.password);
    if (!valid) {
      return errorResponse('Invalid email or password', 401);
    }

    return jsonResponse({ user: { id: user.id, name: user.name, email: user.email } });
  } catch {
    return errorResponse('Invalid request body', 400);
  }
}

async function handleSeed(env: Env): Promise<Response> {
  const demoUsers = [
    { email: 'admin@demo.com', password: 'demo123', name: 'Admin' },
    { email: 'admin1@demo.com', password: 'demo123', name: 'Admin1' },
  ];

  let created = 0;
  for (const u of demoUsers) {
    const existing = await env.DB.prepare('SELECT id FROM users WHERE email = ?').bind(u.email).first();
    if (!existing) {
      const id = crypto.randomUUID();
      const passwordHash = await hashPassword(u.password);
      await env.DB.prepare(
        'INSERT INTO users (id, email, name, password) VALUES (?, ?, ?, ?)',
      ).bind(id, u.email, u.name, passwordHash).run();
      created++;
    }
  }

  return jsonResponse({ message: `Seeded ${created} users` });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    if (path === '/auth/register' && request.method === 'POST') {
      return handleAuthRegister(request, env);
    }

    if (path === '/auth/login' && request.method === 'POST') {
      return handleAuthLogin(request, env);
    }

    if (path === '/seed' && request.method === 'POST') {
      return handleSeed(env);
    }

    return jsonResponse({ message: 'Beyondi Trading API' });
  },
};
