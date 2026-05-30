interface User {
  id: string;
  email: string;
  name: string;
  created_at: string;
}

interface KisAuth {
  user_id: string;
  app_key: string;
  app_secret: string;
  access_token: string | null;
  token_expiry: string | null;
  is_paper: number;
  connected_at: string;
}

interface Env {
  DB: D1Database;
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

// ── KIS Auth ────────────────────────────────────────────────────────

async function handleKisAuthSave(request: Request, env: Env): Promise<Response> {
  try {
    const body = (await request.json()) as {
      user_id?: string;
      app_key?: string;
      app_secret?: string;
      access_token?: string;
      token_expiry?: string;
      is_paper?: boolean;
    };

    if (!body.user_id || !body.app_key || !body.app_secret) {
      return errorResponse('user_id, app_key, and app_secret are required');
    }

    const now = new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO kis_auth (user_id, app_key, app_secret, access_token, token_expiry, is_paper, connected_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         app_key = excluded.app_key,
         app_secret = excluded.app_secret,
         access_token = excluded.access_token,
         token_expiry = excluded.token_expiry,
         is_paper = excluded.is_paper,
         connected_at = excluded.connected_at`,
    ).bind(
      body.user_id,
      body.app_key,
      body.app_secret,
      body.access_token || null,
      body.token_expiry || null,
      body.is_paper === false ? 0 : 1,
      now,
    ).run();

    return jsonResponse({ message: 'KIS credentials saved', connected_at: now });
  } catch {
    return errorResponse('Invalid request body', 400);
  }
}

async function handleKisAuthGet(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const userId = url.searchParams.get('user_id');

  if (!userId) {
    return errorResponse('user_id query parameter is required');
  }

  const auth = await env.DB.prepare(
    'SELECT * FROM kis_auth WHERE user_id = ?',
  ).bind(userId).first<KisAuth>();

  if (!auth) {
    return jsonResponse({ connected: false });
  }

  return jsonResponse({
    connected: true,
    app_key: auth.app_key,
    access_token: auth.access_token,
    token_expiry: auth.token_expiry,
    is_paper: auth.is_paper === 1,
    connected_at: auth.connected_at,
  });
}

async function handleKisAuthDelete(request: Request, env: Env): Promise<Response> {
  try {
    const body = (await request.json()) as { user_id?: string };
    if (!body.user_id) {
      return errorResponse('user_id is required');
    }

    await env.DB.prepare('DELETE FROM kis_auth WHERE user_id = ?').bind(body.user_id).run();
    return jsonResponse({ message: 'KIS credentials deleted' });
  } catch {
    return errorResponse('Invalid request body', 400);
  }
}

// ── Router ──────────────────────────────────────────────────────────

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    // Auth
    if (path === '/auth/register' && request.method === 'POST') {
      return handleAuthRegister(request, env);
    }
    if (path === '/auth/login' && request.method === 'POST') {
      return handleAuthLogin(request, env);
    }
    if (path === '/seed' && request.method === 'POST') {
      return handleSeed(env);
    }

    // KIS Auth
    if (path === '/kis/auth' && request.method === 'POST') {
      return handleKisAuthSave(request, env);
    }
    if (path === '/kis/auth' && request.method === 'GET') {
      return handleKisAuthGet(request, env);
    }
    if (path === '/kis/auth' && request.method === 'DELETE') {
      return handleKisAuthDelete(request, env);
    }

    return jsonResponse({ message: 'Beyondi Trading API' });
  },
};
