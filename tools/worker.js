// خادم سَنَد الوسيط (Cloudflare Worker).
// 1) /t/...  يمرّر الطلبات إلى api.turath.io ويضيف ترويسات CORS ليعمل البحث من المتصفح.
// 2) /ai/understand و /ai/arrange  يستدعيان Gemini (المفتاح في المتغيّر السري GEMINI_KEY).
// متغيّر اختياري MODEL لاسم النموذج.

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

async function gemini(env, system, user) {
  const model = env.MODEL || 'gemini-2.5-flash-lite';
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_KEY}`;
  const r = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: 'user', parts: [{ text: user }] }],
      generationConfig: { temperature: 0, responseMimeType: 'application/json', maxOutputTokens: 500 },
    }),
  });
  if (!r.ok) throw new Error('gemini ' + r.status);
  const d = await r.json();
  const text = d?.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
  return JSON.parse(text);
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
      return json({ error: String(e).slice(0, 200) }, 502);
    }
  },
};
