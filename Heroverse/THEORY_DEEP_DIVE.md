# Theory Deep Dive: Heroverse — the "Why" Behind Each Layer

This is the conceptual companion to [`BUILD_GUIDE.md`](./BUILD_GUIDE.md). The build
guide shows **what** to write and **how**; this file explains **why** each layer, each
pattern, and each decision exists. It follows the exact same 12 layers so you can read
the two documents side by side.

### How to use this file

- **Do not read it alone.** Read it *while* building: for each layer in
  `BUILD_GUIDE.md`, first write the code, then read this file's matching section to
  understand what you just wrote.
- Each section is 1-to-1 with a build layer (Layer 1 → Layer 12), so jumping to the
  right section is always easy.
- The concepts here are the same ones that power the **⑤ The Gotcha** boxes in the
  build guide — that is why the bugs happened, and why the fixes work.
- If you want a quick recap of *everything* at the end, read the **Theory for Layer
  12** section and the final wiring summary last.

---

## Theory for Layer 1 — The Skeleton (server, router, handler)

### What is a "server" really?
A server is a program that runs forever, waiting for network connections. Each
connection carries HTTP requests (method + path + headers + body). The server must:
parse the request, decide who handles it, and write a response. We never write the
HTTP parser — Gin does. We write **handlers** (functions that respond) and a **router**
(the table mapping `METHOD /path` → handler).

### Why a factory function (`HealthHandler() gin.HandlerFunc`)?
A plain function would be fine for `HealthHandler`, but the factory shape is the same
shape used everywhere else (`Authenticate(jwtSecret)` returns a handler that has
"captured" the secret). Closures let a handler remember values from the place it was
created. Learning the factory pattern early means Layer 11 is easy.

### Why `gin.H`?
`gin.H` is `map[string]any` — a shortcut to hand-build a small JSON object. `c.JSON`
sets `Content-Type: application/json`, picks a status code, serializes, and writes.

### Why the `err != http.ErrServerClosed` check?
`ListenAndServe` blocks forever. When you eventually add graceful shutdown, it returns
`http.ErrServerClosed`, which is *expected* — not a crash. The check treats every other
error as fatal but shuts down quietly.

---

## Theory for Layer 2 — Configuration

### Why not hard-code?
The same binary must run on a laptop and in production with different ports, secrets,
and database addresses. Configuration changes per environment; code does not.

### What are struct tags doing?
`env:"SERVER_PORT" envDefault:"8080"` is metadata. `caarlos0/env` uses **reflection**
— it inspects your struct at runtime, reads the tags, finds the environment variables,
parses them into the right Go types, and fills the struct. Reflection is the same
mechanism GORM uses for database models and `encoding/json` uses for JSON — one idea,
three libraries.

### Why does the config package have a `Validate()`?
**Fail-fast.** A misconfigured production server (empty DB password, default JWT
secret) is a security hole. Validate at startup so the error is loud and immediate,
not a silent vulnerability weeks later.

### Why `%w` in `fmt.Errorf`?
Wrapping (`%w`) preserves the original error in a chain. `errors.Is` can walk that
chain to match a sentinel error. Every layer uses this so the final log message
contains the whole story while still being machine-matchable.

---

## Theory for Layer 3 — Database connection

### What is a connection pool?
Opening a Postgres connection costs a TCP handshake + auth. A pool reuses connections:
borrow, use, return. The three knobs:
- **MaxOpenConns** — hard cap on simultaneous connections (25). Requests beyond that
  queue.
- **MaxIdleConns** — warm connections kept ready (10), avoiding re-handshakes.
- **ConnMaxLifetime** — recycle connections after 15 min so stale ones die.

### Why `TranslateError: true`?
GORM normally returns raw driver errors (Postgres `SQLSTATE 23505` for a unique
violation). Translation converts them into portable Go sentinels:
`gorm.ErrDuplicatedKey`, `gorm.ErrRecordNotFound`. Our `errors.Is` checks depend on it.

### Why `Ping()`?
To fail at startup, not on the first request. If the database is down, we want
"server didn't start with a clear message", not "server started and every request 500s".

### Why is migration a separate function with `...any`?
`AutoMigrate` reflects over structs to create tables. `models ...any` accepts any
number of models. It's idempotent (safe to run each startup).

### The driver/DSN matching rule (Bug #7)
The dialector (`postgres.Open`) and the DSN must agree. Originally the project used
`sqlite.Open` with a Postgres DSN — SQLite treated the connection string as a
*filename* and silently used a garbage file, bypassing the real database.

---

## Theory for Layer 4 — Models

### One struct, two consumers
GORM reads `gorm:"..."` tags to build the table; `encoding/json` reads `json:"..."`
tags to name API fields. Add a field once — both the schema and the JSON gain it.

### The meaning of each constraint
- `primaryKey` — auto-increment primary key.
- `uniqueIndex` — a unique index; the database enforces "no duplicate emails"
  *atomically* (race-safe, unlike check-then-insert).
- `not null` — column cannot be NULL.
- `json:"-"` — never serialize: the password hash can never appear in an API response.
- `type:varchar(20);default:'user'` — column type and a database-level default.
- `CreatedAt`/`UpdatedAt` — GORM fills these automatically by name.

### Why `UserRole` is its own type
`type UserRole string` with constants means the compiler rejects
`user.Role = "banana"`. Domain vocabulary enforced at compile time.

### Why `Hero.UserID` has `index`
The `user_id` column answers "who owns this hero?" fast (B-tree, O(log n) lookups).
We keep it a plain indexed column and enforce ownership in code (Layer 11) rather than
with a database foreign key.

---

## Theory for Layer 5 — Security

### Hashing vs encryption
Encryption is reversible with a key. Hashing is one-way. Passwords are hashed so a
leaked database yields no plaintext.

### Why bcrypt?
bcrypt is deliberately slow (2^cost iterations). Fast hashes (MD5/SHA) are crackable at
billions of guesses/sec. bcrypt's slowness makes brute-force economically infeasible.
It also embeds a random **salt** and the **cost** in the output string, so identical
passwords produce different hashes (defeating rainbow tables) and you never store the
salt separately.

### JWT structure
`header.payload.signature`, three base64url segments. Header says the algorithm;
payload holds claims (`user_id`, `role`, `exp`, `iat`); the signature is an HMAC of
header+payload with the secret. Base64 is **not** encryption — the payload is readable
by anyone, so we only put non-secret data in it.

### HS256 vs ES256 (Bug #3)
HS256 (HMAC) is symmetric — the same string secret signs and verifies. ES256 (ECDSA)
needs an `*ecdsa.PrivateKey` object; passing a `[]byte` secret crashes at signing time.
Since config holds a string secret, we use HS256 — and the validator **forces** HMAC in
the keyfunc callback (algorithm-confusion defense: an attacker's `alg:none` or other
algorithm token is rejected).

---

## Theory for Layer 6 — Repository

### Why a repository layer?
The repository is the only code that knows about SQL. Swap databases and only this
layer changes. Services and handlers never import GORM — so they can be tested with a
fake repository.

### `WithContext(ctx)`
Attaches the request context to the query. If the client disconnects, the context is
cancelled and the query aborts. Without it, dropped connections leave SQL running.

### Duplicate detection
`errors.Is(err, gorm.ErrDuplicatedKey)` relies on `TranslateError` (Layer 3). We turn
the database sentinel into a domain message the service matches by string.

### Parameterized queries
`Where("email = ?", email)` sends the value as a **parameter**, never as SQL text.
That is the complete defense against SQL injection.

---

## Theory for Layer 7 — Service (business logic)

### Why services exist
Handlers are HTTP glue; repositories are SQL. The business rules — "email must be
valid", "password ≥ 8 chars", "sort only by known columns" — live in the service,
where they can be reused and unit-tested without HTTP or a database.

### Sentinel errors
`ErrInvalidEmail`, `ErrHeroNotFound`, etc., are named, shared `errors.New` values.
They are the **contract** between service and handler: the handler maps each to an HTTP
status. They must be created once at package level — never at the comparison site.

### Why `errors.Is(err, errors.New("..."))` is dead code (Bug #4)
`errors.New` creates a fresh value every call; two distinct values are never equal.
The fix was to compare `err.Error()` strings when the sentinel lives in another
package.

### Anti user-enumeration
Both "unknown email" and "wrong password" return the same `ErrInvalidCredentials`.
If login answered differently, attackers could harvest registered emails.

### Order of operations
Sanitize (trim/lowercase) → cheap validation → expensive work (bcrypt). Never hash
garbage.

---

## Theory for Layer 8 — Handlers

### The response envelope
Every success is `{"data": ...}`; lists add `"meta"`. Clients write one generic
unwrapper. The envelope also allows future evolution without breaking clients.

### The error envelope
`{"code": "...", "message": "..."}`. `code` is stable and machine-checkable; `message`
is human-readable. Clients branch on `code`, never on `message` text.

### Status codes as a contract
- `400` — client sent something invalid.
- `401` — unauthenticated (missing/bad token).
- `403` — authenticated but not allowed.
- `404` — resource missing.
- `500` — our fault; client gets a generic message, the real error goes to the log.
Getting these right is the API contract — clients build retry/login logic on them.

### Why we mask internal errors
The `default` case in `RespondWithError` logs the real error server-side and returns
`INTERNAL_ERROR` to the client. Never leak SQL, file paths, or stack traces.

---

## Theory for Layer 9 — Hero Repository

### Interface vs concrete type
`HeroRepository` is an interface; `gormHeroRepository` is the unexported
implementation. The service depends on the interface → testable with fakes. (The user
repository uses a concrete value — both work; the interface is the more testable
pattern.)

### The query builder
`Where(...).Where(...)` ANDs conditions; an inner `.Where(...).Or(...)` ORs them.
`ILIKE '%term%'` is a case-insensitive contains-match. `?` placeholders keep input as
data.

### Count before fetch
`Count(&total)` runs on the same filtered query (before Order/Limit/Offset) so the
total matches the page. Order/Limit/Offset then produce the page.

### Deterministic ordering
`ORDER BY col dir, id ASC` — the `id ASC` tie-breaker keeps rows from appearing on two
pages (stable pagination).

---

## Theory for Layer 10 — Hero Service

### Trim → check
`strings.TrimSpace` turns `"  "` into `""`, which then correctly fails the empty
check. Without trimming, whitespace-only input would pass.

### The sort whitelist — validation as a security control
`sort_by` and `order` become SQL fragments in the repository. Only whitelisted values
are allowed, so injection through those parameters is impossible.

### `offset := (page-1) * limit`
Converts a 1-based page number to a 0-based SQL offset. Page 1 → offset 0.

### GORM error translation (Bug #8)
`errors.Is(err, gorm.ErrRecordNotFound)` → `ErrHeroNotFound` in `GetByID`, `Update`,
and `Delete`. Without it, missing heroes returned `500`; with it, the handler maps the
sentinel to `404`.

---

## Theory for Layer 11 — Handler & Middleware

### The middleware chain (onion model)
Middleware runs before the handler. It can stop the chain (`c.Abort()`) or continue
(`c.Next()`). Requests pass through middleware inward and responses outward.

### Context values
The middleware stores `user_id` and `role` with `c.Set`; handlers read them with
`c.Get` plus a **type assertion** (`.(uint)`), always checking `ok`.

### Mass-assignment defense
`Create` overwrites `hero.UserID = userID` after binding, so a client can never claim
ownership of someone else's hero. `Update` copies only `Name`/`Power` onto the
existing record (field allow-listing).

### IDOR defense (Bug #9)
`isOwnerOrAdmin` compares the authenticated user against the *stored* owner. Fetch-
then-authorize: missing hero → `404` (don't reveal existence); unauthorized → `403`.
Delete originally skipped this check — any authenticated user could delete any hero.

### Import-cycle discipline (Bug #2)
Middleware must not import `handlers` (handlers import middleware). A cycle is a Go
compile error and a design smell. Middleware writes plain `gin.H` instead.

---

## Theory for Layer 12 — Docker & wiring

### Containers
A container is an isolated process sharing the host kernel. `postgres:17-alpine`
guarantees the same database everywhere.

### Named volumes
`postgres_data:/var/lib/postgresql/data` persists database files. Containers are
ephemeral; without the volume, `docker compose down` destroys your data.

### Healthchecks
`pg_isready` probes readiness — dependent services wait for "ready", not just
"started".

### Final wiring order (dependency injection)
Config → Database → Migrate → Repositories → Services → Handlers → Router → Server.
`main.go` read top-to-bottom *is* the dependency diagram. `log.Fatalf` on every
startup error is fail-fast.

---

## How to use these two documents together

1. Read a layer's **Build** section in `BUILD_GUIDE.md` — write the code.
2. Read the matching **Theory** section here — understand why.
3. When you hit a **The Gotcha** box in the guide, the theory section explains the
   underlying principle (that's how real bugs are diagnosed).
