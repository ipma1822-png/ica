import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const origins = new Set(["https://ipma1822-png.github.io", "https://ipma.kr"]);
const json = (body: unknown, status: number, origin: string) => new Response(JSON.stringify(body), {
  status,
  headers: {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    ...(origins.has(origin) ? {"Access-Control-Allow-Origin": origin, "Vary": "Origin"} : {}),
  },
});

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin") || "";
  if (req.method === "OPTIONS") return new Response(null, {
    status: 204,
    headers: {
      ...(origins.has(origin) ? {"Access-Control-Allow-Origin": origin, "Vary": "Origin"} : {}),
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "content-type",
    },
  });
  if (req.method !== "POST" || !origins.has(origin)) return json({error:"Not allowed"},403,origin);

  let name: unknown, birth_date: unknown;
  try { ({name, birth_date} = await req.json()); }
  catch { return json({error:"Invalid request"},400,origin); }
  if (typeof name !== "string" || name !== name.trim() || !name || name.length > 100 ||
      typeof birth_date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(birth_date) ||
      Number.isNaN(Date.parse(birth_date))) {
    return json({error:"Invalid identity"},400,origin);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const key = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}").default || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return json({error:"Unavailable"},503,origin);
  const query = new URL(url + "/rest/v1/gn24_junior_reporters");
  query.searchParams.set("select","real_name,reporter_id,status");
  query.searchParams.set("real_name","eq."+name);
  query.searchParams.set("birth_date","eq."+birth_date);
  query.searchParams.set("status","eq.ACTIVE");
  query.searchParams.set("limit","2");
  const response = await fetch(query, {headers:{"apikey":key}});
  if (!response.ok) return json({error:"Unavailable"},503,origin);
  const rows = await response.json();
  if (rows.length !== 1) return json({reporter:null},200,origin);
  return json({reporter:{
    name:rows[0].real_name,
    reporter_id:rows[0].reporter_id,
    status:"ACTIVE",
  }},200,origin);
});
