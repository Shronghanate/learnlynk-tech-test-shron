import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

type CreateTaskPayload = {
  application_id: string;
  task_type: string;
  due_at: string;
  title?: string;
  status?: string;
};

const VALID_TYPES = ["call", "email", "review"];
const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const body = (await req.json().catch(() => null)) as Partial<CreateTaskPayload> | null;

    if (!body) {
      return json({ error: "Invalid JSON body" }, 400);
    }

    const { application_id, task_type, due_at, title, status } = body;

    if (typeof application_id !== "string" || !UUID_REGEX.test(application_id)) {
      return json({ error: "Invalid or missing application_id (must be UUID)" }, 400);
    }

    if (typeof task_type !== "string" || !VALID_TYPES.includes(task_type)) {
      return json({ error: `Invalid task_type. Must be one of: ${VALID_TYPES.join(", ")}` }, 400);
    }

    if (typeof due_at !== "string") {
      return json({ error: "Invalid or missing due_at (ISO timestamp string expected)" }, 400);
    }

    const dueDate = new Date(due_at);
    if (Number.isNaN(dueDate.getTime())) {
      return json({ error: "Invalid due_at format. Use ISO 8601 timestamp." }, 400);
    }

    const now = new Date();
    if (dueDate.getTime() <= now.getTime()) {
      return json({ error: "due_at must be a future timestamp" }, 400);
    }

    const insertPayload: Record<string, unknown> = {
      application_id,
      type: task_type,
      due_at: dueDate.toISOString(),
    };

    if (typeof title === "string") insertPayload.title = title;
    if (typeof status === "string") insertPayload.status = status;

    const { data, error } = await supabase
      .from("tasks")
      .insert(insertPayload)
      .select()
      .single();

    if (error) {
      console.error("Supabase insert error:", error);
      return json({ error: "Failed to create task" }, 500);
    }

    return json({ success: true, task_id: data.id }, 200);
  } catch (err) {
    console.error("Unhandled error in create-task:", err);
    return json({ error: "Internal server error" }, 500);
  }
});
