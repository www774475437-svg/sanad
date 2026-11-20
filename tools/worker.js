// خادم سَنَد الوسيط (Cloudflare Worker).
// 1) /t/...  يمرّر الطلبات إلى api.turath.io ويضيف ترويسات CORS ليعمل البحث من المتصفح.
// 2) /ai/understand و /ai/arrange  يستدعيان Gemini (المفتاح في المتغيّر السري GEMINI_KEY).
// متغيّر اختياري MODEL لاسم النموذج الأول؛ وإن تعذّر انتقل تلقائيًا إلى البدائل.

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' },
  });

const FALLBACK_MODELS = ['gemini-3.6-flash', 'gemini-3.5-flash', 'gemini-flash-latest', 'gemini-flash-lite-latest'];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function modelsOf(env) {
  const list = [];
  for (const m of [env.MODEL, ...FALLBACK_MODELS]) {
    const name = String(m || '').trim();
    if (name && !list.includes(name)) list.push(name);
  }
  return list;
}

// محاولة واحدة لنموذج واحد
async function callModel(env, model, system, user) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  let r;
  try {
    r = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': env.GEMINI_KEY },
      signal: AbortSignal.timeout(25000),
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents: [{ role: 'user', parts: [{ text: user }] }],
        generationConfig: { temperature: 0, responseMimeType: 'application/json', maxOutputTokens: 2048 },
      }),
    });
  } catch (e) {
    return { ok: false, status: 0, message: 'timeout' };
  }
  if (!r.ok) {
    let message = '';
    try { message = (await r.json())?.error?.message || ''; } catch (_) {}
    return { ok: false, status: r.status, message: message.slice(0, 160) };
  }
  const d = await r.json();
  const parts = d?.candidates?.[0]?.content?.parts || [];
  const text = parts.filter((p) => !p.thought).map((p) => p.text || '').join('').trim();
  try {
    return { ok: true, data: JSON.parse(text.replace(/^```(?:json)?\s*|\s*```$/g, '')) };
  } catch (_) {
    return { ok: false, status: 200, message: 'bad json' };
  }
}

async function gemini(env, system, user) {
  const errors = [];
  for (const model of modelsOf(env)) {
    for (let attempt = 0; attempt < 2; attempt++) {
      const res = await callModel(env, model, system, user);
      if (res.ok) return res.data;
      errors.push(`${model}: ${res.status} ${res.message}`.trim());
      // المفتاح مرفوض: لا فائدة من نموذج آخر
      if (res.status === 401 || res.status === 403 || (res.status === 400 && /api key/i.test(res.message))) {
        throw new Error(errors.join(' | '));
      }
      // مشغول أو مهلة: أعد المحاولة مرة بعد لحظة؛ وإلا انتقل للنموذج التالي
      if (attempt === 0 && (res.status === 503 || res.status === 500 || res.status === 0)) {
        await sleep(1200);
        continue;
      }
      break;
    }
  }
  throw new Error(errors.join(' | '));
}

const UNDERSTAND = `أنت مساعد بحث في كتب العلماء. يصلك سؤال شرعي بأي صياغة أو لهجة.
لا تُجب عن السؤال ولا تذكر حكمًا. استخرج فقط:
- issue: عنوان المسألة الفقهية بعبارة قصيرة فصيحة (مثل: تأخير الصلاة عن وقتها).
- terms: من كلمتين إلى أربع كلمات مفتاحية مفردة فصيحة تصلح للبحث في كتب الفقه والفتاوى، كل عنصر كلمة واحدة بلا تشكيل.
أعد JSON فقط بالشكل: {"issue":"...","terms":["...","..."]}`;

const ARRANGE = `يصلك سؤال، ومعه نقول مرقّمة من كلام الشيخ ابن عثيمين.
- order: أرقام النقول التي تجيب عن السؤال فعلًا، مرتبة من الأنسب. اترك ما لا علاقة له.
- summary: خلاصة الحكم في جملة أو جملتين، مأخوذة من النقول المختارة وحدها وبألفاظها ما أمكن.
  لا تضف حكمًا ولا دليلًا ولا رأيًا ليس في النقول. وإن لم يكن في النقول جواب صريح للسؤال فاجعلها نصًّا فارغًا "".
أعد JSON فقط بالشكل: {"order":[0,2],"summary":"..."}`;

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { headers: CORS });
    const url = new URL(request.url);
    try {
      if (url.pathname.startsWith('/t/') && request.method === 'GET') {
        const target = 'https://api.turath.io/' + url.pathname.slice(3) + url.search;
        const r = await fetch(target, { headers: { Accept: 'application/json' }, cf: { cacheTtl: 3600, cacheEverything: true } });
        return new Response(r.body, {
          status: r.status,
          headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'public, max-age=3600' },
        });
      }
      if (request.method === 'POST' && url.pathname.startsWith('/ai/')) {
        if (!env.GEMINI_KEY) return json({ error: 'no key' }, 503);
        const body = await request.json();
        const q = String(body.q || '').slice(0, 1500);
        if (!q) return json({ error: 'empty' }, 400);
        if (url.pathname === '/ai/understand') {
          return json(await gemini(env, UNDERSTAND, q));
        }
        if (url.pathname === '/ai/arrange') {
          const quotes = (body.quotes || []).slice(0, 6)
            .map((x) => `[${x.i}] ${String(x.title || '')}\n${String(x.text || '').slice(0, 1200)}`)
            .join('\n\n');
          return json(await gemini(env, ARRANGE, `السؤال: ${q}\n\nالنقول:\n${quotes}`));
        }
      }
      return json({ ok: true, name: 'sanad-proxy' });
    } catch (e) {
      return json({ error: String(e).slice(0, 600) }, 502);
    }
  },
};
