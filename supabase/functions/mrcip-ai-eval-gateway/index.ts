import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(() => new Response(
  JSON.stringify({
    error: "DECOMMISSIONED",
    message: "Stage 13 evaluation execution is consolidated into mrcip-ai-gateway action=evaluate_case."
  }),
  {
    status: 410,
    headers: { "content-type": "application/json; charset=utf-8" }
  }
));
