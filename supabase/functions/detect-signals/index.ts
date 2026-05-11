import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    let workspaceIds: string[] = [];
    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      if (body.workspace_id) workspaceIds = [body.workspace_id];
    }
    if (!workspaceIds.length) {
      const { data } = await supabase
        .from("workspaces")
        .select("id")
        .eq("environment", "production");
      workspaceIds = (data || []).map((w: { id: string }) => w.id);
    }

    const results: Array<Record<string, unknown>> = [];
    for (const id of workspaceIds) {
      const { data, error } = await supabase.rpc("detect_workspace_signals", {
        p_workspace_id: id,
      });
      results.push({ workspace_id: id, result: data, error: error?.message });
    }

    return new Response(
      JSON.stringify({ ok: true, workspaces: results.length, results }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: (e as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
