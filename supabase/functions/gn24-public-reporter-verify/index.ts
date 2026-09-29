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
      "Access-Control-Allow-Headers": "content-type, apikey, authorization, x-client-info",
    },
  });
  if (req.method !== "POST" || !origins.has(origin)) return json({error:"Not allowed"},403,origin);

  let number: unknown;
  try { ({reporter_number:number} = await req.json()); }
  catch { return json({error:"Invalid request"},400,origin); }
  if (typeof number !== "string" || !/^GN24-[0-9]{4}-[0-9]{4,}$/.test(number)) {
    return json({error:"Invalid reporter number"},400,origin);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return json({error:"Unavailable"},503,origin);
  const query = new URL(url + "/rest/v1/gn24_reporters");
  query.searchParams.set("select","id,name,reporter_number,role,affiliation,region,official_appointed_at,appointed_at,status,photo_url");
  query.searchParams.set("reporter_number","eq."+number);
  query.searchParams.set("status","eq.active");
  query.searchParams.set("limit","1");
  const response = await fetch(query, {headers:{"apikey":key,"Authorization":"Bearer "+key}});
  if (!response.ok) return json({error:"Unavailable"},503,origin);
  const rows = await response.json();
  const r = rows[0];
  if (!r || !r.name || /편집부|시스템|운영팀/.test(r.name) || r.id === "gn24-editorial") {
    return json({reporter:null},200,origin);
  }
  const photo = String(r.photo_url || "");
  const photo_url = /^(https:\/\/news24\.ai\.kr\/assets\/reporters\/|https:\/\/ipma1822-png\.github\.io\/ica\/assets\/reporters\/)[a-zA-Z0-9_-]+\.webp$/.test(photo) ? photo : "";
  return json({reporter:{
    name:r.name, reporter_number:r.reporter_number, role:r.role,
    affiliation:r.affiliation, region:r.region,
    appointed_at:r.official_appointed_at || r.appointed_at,
    status:"active", photo_url,
  }},200,origin);
});
