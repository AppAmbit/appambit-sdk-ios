/*
 * AppAmbit Cloud Code examples catalog.
 *
 * Each function below is a deployable handler body. To deploy one example,
 * copy its function body to index.js and export it as `handler`:
 *
 * export const handler = async (ctx) => { ... };
 *
 * The catalog is intentionally not deployed as one function because Cloud
 * Code deploys one handler per function and each handler has its own slug.
 */

// cloud-demo-setup-database | POST | Requires an existing linked Database.
// Creates the tables used by the Database examples without destroying data.
export const cloudDemoSetupDatabase = async (ctx) => {
  const { results } = await ctx.appambit.batch([
    {
      sql: `CREATE TABLE IF NOT EXISTS cloud_demo_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )`,
    },
    {
      sql: `CREATE TABLE IF NOT EXISTS cloud_demo_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        idempotency_key TEXT NOT NULL,
        amount INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE (user_id, idempotency_key)
      )`,
    },
  ], true);

  return {
    ok: true,
    tables: ['cloud_demo_tasks', 'cloud_demo_orders'],
    statements: results.length,
  };
};

// cloud-demo-create-task | POST | Requires cloud_demo_tasks.
export const cloudDemoCreateTask = async (ctx) => {
  const userId = ctx.consumer?.id;
  const title = String(ctx.req?.body?.title ?? '').trim();
  if (!userId || !title) return { status: 400, body: { error: 'title_required' } };

  const { results } = await ctx.appambit.db(
    'INSERT INTO cloud_demo_tasks (user_id, title, created_at) VALUES (?, ?, ?) RETURNING *',
    [userId, title, new Date().toISOString()],
  );
  const result = results[0];
  const row = result.rows[0];
  const task = Object.fromEntries(result.columns.map((column, index) => [column, row[index]]));
  return { status: 201, body: { task } };
};

// cloud-demo-list-tasks | GET | Requires cloud_demo_tasks.
export const cloudDemoListTasks = async (ctx) => {
  const userId = ctx.consumer?.id;
  if (!userId) return { status: 401, body: { error: 'consumer_required' } };

  const requestedLimit = Number(ctx.req?.query?.limit ?? 20);
  const limit = Math.min(Math.max(Number.isFinite(requestedLimit) ? requestedLimit : 20, 1), 50);
  const { results } = await ctx.appambit.db(
    'SELECT id, title, completed, created_at FROM cloud_demo_tasks WHERE user_id = ? ORDER BY created_at DESC LIMIT ?',
    [userId, limit],
  );
  const result = results[0];
  const tasks = result.rows.map((row) => Object.fromEntries(result.columns.map((column, index) => [column, row[index]])));
  return { tasks };
};

// cloud-demo-complete-task | PATCH | Requires cloud_demo_tasks and task_id.
export const cloudDemoCompleteTask = async (ctx) => {
  const userId = ctx.consumer?.id;
  const taskId = Number(ctx.req?.body?.task_id);
  if (!userId || !Number.isInteger(taskId) || taskId < 1) return { status: 400, body: { error: 'task_id_required' } };

  const { results } = await ctx.appambit.batch([
    { sql: 'UPDATE cloud_demo_tasks SET completed = 1 WHERE id = ? AND user_id = ?', params: [taskId, userId] },
    { sql: 'INSERT INTO cloud_demo_tasks (user_id, title, created_at) VALUES (?, ?, ?)', params: [userId, 'Transaction audit', new Date().toISOString()] },
  ], true);
  if ((results[1]?.rows_written ?? 0) === 0) return { status: 404, body: { error: 'task_not_found' } };
  return { ok: true, transaction: true, statements: results.length };
};

// cloud-demo-delete-task | DELETE | Requires cloud_demo_tasks, task_id and confirmation.
export const cloudDemoDeleteTask = async (ctx) => {
  const userId = ctx.consumer?.id;
  const taskId = Number(ctx.req?.body?.task_id);
  if (!userId || !Number.isInteger(taskId) || taskId < 1) return { status: 400, body: { error: 'task_id_required' } };

  const { results } = await ctx.appambit.db(
    'DELETE FROM cloud_demo_tasks WHERE id = ? AND user_id = ?',
    [taskId, userId],
  );
  if ((results[0]?.rows_written ?? 0) === 0) return { status: 404, body: { error: 'task_not_found' } };
  return { status: 204, body: null };
};

// cloud-demo-create-order | POST | Requires cloud_demo_orders.
export const cloudDemoCreateOrder = async (ctx) => {
  const userId = ctx.consumer?.id;
  const key = String(ctx.req?.body?.idempotency_key ?? '').trim();
  const amount = Number(ctx.req?.body?.amount);
  if (!userId || !key || !Number.isInteger(amount) || amount < 1) return { status: 400, body: { error: 'order_input_required' } };

  const existing = await ctx.appambit.db(
    'SELECT id, user_id, idempotency_key, amount, status, created_at FROM cloud_demo_orders WHERE user_id = ? AND idempotency_key = ?',
    [userId, key],
  );
  if (existing.results[0].rows.length > 0) return { idempotent: true, order: existing.results[0].rows[0] };

  try {
    const { results } = await ctx.appambit.db(
      'INSERT INTO cloud_demo_orders (user_id, idempotency_key, amount, status, created_at) VALUES (?, ?, ?, ?, ?) RETURNING id, user_id, idempotency_key, amount, status, created_at',
      [userId, key, amount, 'created', new Date().toISOString()],
    );
    return { idempotent: false, order: results[0].rows[0] };
  } catch (error) {
    return { status: 409, body: { error: 'idempotency_conflict', message: error.message } };
  }
};

// cloud-demo-dashboard-summary | GET | Requires Database and CMS setup.
export const cloudDemoDashboardSummary = async (ctx) => {
  const userId = ctx.consumer?.id;
  if (!userId) return { status: 401, body: { error: 'consumer_required' } };

  const [{ results: dbResults }, posts] = await Promise.all([
    ctx.appambit.db('SELECT COUNT(*) AS task_count FROM cloud_demo_tasks WHERE user_id = ?', [userId]),
    ctx.appambit.cms.list('cloud_code_demo_posts', { status: 'published', per_page: 5 }),
  ]);
  return { task_count: dbResults[0].rows[0][0], posts: posts.data ?? [] };
};

// cloud-demo-read-posts | GET | Requires cloud_code_demo_posts.
export const cloudDemoReadPosts = async (ctx) => {
  const uuid = ctx.req?.query?.uuid;
  if (uuid) return await ctx.appambit.cms.get('cloud_code_demo_posts', uuid);
  return await ctx.appambit.cms.list('cloud_code_demo_posts', { status: 'published', per_page: 5 });
};

// cloud-demo-publish-post | POST | Requires a CMS Content Type with title and body fields.
export const cloudDemoPublishPost = async (ctx) => {
  const title = String(ctx.req?.body?.title ?? '').trim();
  const body = String(ctx.req?.body?.body ?? '').trim();
  if (!title || !body) return { status: 400, body: { error: 'title_and_body_required' } };

  const post = await ctx.appambit.cms.publish('cloud_code_demo_posts', { title, body });
  return { status: 201, body: { post } };
};

// cloud-demo-send-push | POST | Requires configured APNs/FCM credentials.
export const cloudDemoSendPush = async (ctx) => {
  const change = ctx.event ?? {};
  ctx.log('start new order', change);

  try {
    await ctx.appambit.push({
      title: 'New order!',
      body: 'You just received a new order.',
    });

    ctx.log('finish new order', change);
    return { notified: true };
  } catch (error) {
    const errorDetails = error instanceof Error
      ? { name: error.name, message: error.message, stack: error.stack ?? null }
      : { value: String(error) };
    ctx.log('push failed', { change, error: errorDetails });
    throw error;
  }
};

// cloud-demo-http-inspector | POST | Requires an HTTP trigger.
export const cloudDemoHttpInspector = async (ctx) => ({
  context: {
    method: ctx.req?.method ?? null,
    slug: ctx.req?.slug ?? null,
    query: ctx.req?.query ?? {},
    headers: ctx.req?.headers ?? {},
    body: ctx.req?.body ?? {},
    consumer_id: ctx.consumer?.id ?? null,
  },
});

// cloud-demo-json-values | POST | Requires an HTTP trigger.
export const cloudDemoJsonValues = async () => ({
  object: { ok: true },
  array: [1, 'two', true],
  string: 'hello',
  number: 7,
  boolean: true,
});

// cloud-demo-null-contract | GET | Requires an HTTP trigger.
export const cloudDemoNullContract = async () => ({
  raw: null,
  explicit: { value: null },
});

// cloud-demo-response-shapes | POST | Requires an HTTP trigger.
export const cloudDemoResponseShapes = async (ctx) => {
  if (ctx.req?.query?.empty === 'true') return { status: 204, body: null };
  return { status: 201, headers: { 'X-Custom': 'yes' }, body: { created: true, status_example: 201 } };
};

// cloud-demo-error-response | POST | Requires an HTTP trigger.
export const cloudDemoErrorResponse = async (ctx) => {
  if (!ctx.req?.body?.valid) return { status: 400, body: { error: 'validation_failed', message: 'Set valid=true to pass validation.' } };
  return { ok: true };
};

// cloud-demo-timeout-10s | GET | Requires a 10 second function timeout.
export const cloudDemoTimeout = async () => {
  await new Promise((resolve) => setTimeout(resolve, 12000));
  return { completed_after_seconds: 12 };
};

// cloud-demo-runtime-context | GET | Requires DEMO_REGION and DEMO_SECRET configuration.
export const cloudDemoRuntimeContext = async (ctx) => {
  const region = ctx.env?.DEMO_REGION ?? null;
  const hasSecret = Boolean(ctx.secrets?.DEMO_SECRET);
  ctx.log('Cloud Code context demo', { has_region: Boolean(region), has_secret: hasSecret });
  return { region, has_secret: hasSecret };
};

// cloud-demo-task-event | Event trigger | Runs after cloud_demo_tasks changes.
export const cloudDemoTaskEvent = async (ctx) => {
  const change = ctx.event ?? {};
  ctx.log('cloud_demo_tasks changed', { operation: change.operation, table: change.table });
  return { handled: true, operation: change.operation ?? null };
};

// cloud-demo-manual-report | Manual trigger | Runs from the Dashboard.
export const cloudDemoManualReport = async (ctx) => {
  const input = ctx.req ?? {};
  ctx.log('manual demo run', input);
  return { ran: true, input };
};
