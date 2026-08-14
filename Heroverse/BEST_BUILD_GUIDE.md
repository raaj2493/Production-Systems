# Best Build Guide: The Unified HeroAPI Tutorial

This is the **complete, unified** tutorial. It merges the step-by-step build
instructions, the deep theory, Go language concepts, real request traces, the actual
SQL GORM generates, and a full endpoint reference into **one single document**. Read
one layer at a time with a terminal open next to you. **Type the code yourself** — that
is how the mental map gets built.

## The workflow — every layer follows the same rhythm

```
①  THE OBJECTIVE    → what are we building right now, and why does it come at this point?
②  THE THEORY       → the concept we are applying, in plain words.
   + GO CONCEPTS    → every Go language feature used in this layer, explained.
   + DEEP DIVE      → the deeper "why" behind the decisions.
③  THE BUILD        → the code, line by line, with runtime traces.
④  FLOW CHECK       → a diagram + a real request walked through this layer.
⑤  RUN IT          → the command to verify the layer, plus troubleshooting.
⑤  THE GOTCHA      → the real bug that happened here when this project was being made.
```

> **Setup requirement before Layer 1:** Go 1.25+, Docker (for PostgreSQL), and a
> terminal. Every command is shown. Do not skip the `RUN IT` steps — each layer must
> compile and run before you move on.

> **Three other documents exist:** `BUILD_GUIDE.md` (the short "what to type" version),
> `THEORY_DEEP_DIVE.md` (theory only), and `TESTING.md` (endpoint test results + the 9
> real bugs). This file is everything, in order.

## Table of Contents

- [Layer 1 — The Skeleton: server, router, health endpoint](#layer-1)
- [Layer 2 — Configuration: environment variables](#layer-2)
- [Layer 3 — Database connection & migrations](#layer-3)
- [Layer 4 — Models: User and Hero](#layer-4)
- [Layer 5 — Security: bcrypt & JWT](#layer-5)
- [Layer 6 — User Repository](#layer-6)
- [Layer 7 — Auth Service (business logic)](#layer-7)
- [Layer 8 — Response helpers & Auth Handler](#layer-8)
- [Layer 9 — Hero Repository](#layer-9)
- [Layer 10 — Hero Service](#layer-10)
- [Layer 11 — Hero Handler & Auth Middleware](#layer-11)
- [Layer 12 — Docker, `.env`, and full test run](#layer-12)
- [Appendix — Complete Endpoint Reference](#appendix)

---
# <a id="layer-1"></a>Layer 1 — The Skeleton: server, router, health endpoint

## ① The Objective

We build the smallest possible running web server: a Gin engine with one route
`GET /health` that answers `{"status":"ok"}`.

**Success checklist — when this layer is done:**
- [ ] `go run cmd/api/main.go` starts a server with no errors
- [ ] `curl http://localhost:8080/health` prints `{"status":"ok"}`
- [ ] You understand the difference between a *handler* and a *router*

This proves the whole toolchain (Go, Gin, your folder layout, your `go.mod`) works
before we add any real logic. Every later layer will assume this skeleton is solid.

## ② The Theory

A web server is just an **infinite loop** that:
1. listens on a port for incoming network connections,
2. reads the HTTP request (method, path, headers, body),
3. decides which code should handle it (routing),
4. writes back an HTTP response.

We will not write the HTTP parser ourselves — that is what the **Gin** framework does.
Our job is to tell Gin *which path maps to which handler*.

Two terms you must know from now on:

- **Handler** — a function that receives a request and produces a response. Think of
  it as the *worker*.
- **Router** — the table that maps `METHOD /path` to a handler. Think of it as the
  *receptionist*.

### Go concepts used in this layer

| Concept | Where it appears | Plain-English meaning |
|---|---|---|
| Package | `package handlers` | A folder of `.go` files that share a name. The name is the first line of every file. |
| Import | `import "github.com/gin-gonic/gin"` | "Pull in code from elsewhere." Go only lets you use what you explicitly import. |
| `main` package | `package main` | The special package that Go compiles into a *runnable program* (not a library). |
| Function literal / anonymous function | `func(c *gin.Context) { ... }` | A function with no name, defined inline. In Go these are often called **closures** because they can "capture" variables from the surrounding scope. |
| Return type `gin.HandlerFunc` | `func HealthHandler() gin.HandlerFunc` | A function type. `gin.HandlerFunc` is exactly `func(*gin.Context)`. |
| `*gin.Context` | `c *gin.Context` | A *pointer* to Gin's context object. It carries everything about one request: the URL, headers, body, and the response writer. The `*` means "pointer to" — we pass the same object around instead of copying it. |
| `gin.H` | `gin.H{...}` | A type alias for `map[string]any`. `any` is the modern name for `interface{}` — "this value can be of any type". |
| `:=` | `engine := router.SetupRouter(...)` | Short variable declaration. Go *infers* the type. `engine := x` means "declare engine and set it to x". |

### Deep Dive — what is actually happening on the wire

When you run `curl http://localhost:8080/health`, curl opens a **TCP connection** to
your machine on port 8080 and sends this exact text:

```
GET /health HTTP/1.1
Host: localhost:8080
User-Agent: curl/8.x
Accept: */*
```

This is the raw HTTP request. Your Go program — via Gin — parses this text into a
structured object: method = `GET`, path = `/health`, version = `HTTP/1.1`, headers = a
map. Then it consults the router: "who handles `GET /health`?" Gin finds the handler we
registered and calls it, passing the `*gin.Context`. The handler writes a response.
Gin formats the response into raw bytes and sends them back over the same TCP
connection:

```
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8

{"status":"ok"}
```

That entire loop repeats forever — that is what "the server is running" means.

## ③ The Build

### Step 1 — Create the project folder and module

```bash
mkdir -p Heroverse/cmd/api
mkdir -p Heroverse/internals/{config,database,models,security,repository,services,handlers,middleware,router}
cd Heroverse
go mod init github.com/raaj2493/production-systems/heroverse
```

**Line by line:**

- `mkdir -p Heroverse/cmd/api` — creates the directory that will hold the executable
  program. `cmd` is the Go convention for "runnable programs"; `api` is the name of our
  program. The `-p` flag creates parent directories if needed and never complains if
  the directory already exists.
- `mkdir -p Heroverse/internals/{...}` — creates *every* package folder at once. The
  braces are shell expansion: `{a,b,c}` becomes `a b c`, so this one line makes nine
  folders. `internals` is a special Go directory: **only this module can import from
  it**. It is how we keep our architecture private — external code cannot accidentally
  reach in.
- `go mod init github.com/raaj2493/production-systems/heroverse` — creates `go.mod`.
  The path is not a real website; it is just a unique name that becomes the root of
  every import statement. Because the path ends in `heroverse`, the import for the
  router package is `github.com/raaj2493/production-systems/heroverse/internals/router`.

**What you should see:**

```
go: creating new go.mod: module github.com/raaj2493/production-systems/heroverse
```

### Step 2 — Install Gin

```bash
go get github.com/gin-gonic/gin
```

`go get` downloads the library, records its version in `go.mod`, and writes checksums
into `go.sum`. If you open `go.mod` now you will see a `require` block:

```text
require github.com/gin-gonic/gin v1.12.0
```

The version is pinned so builds are reproducible: the same code compiles the same way
today and in a year.

### Step 3 — Write the health handler

File: `internals/handlers/health-handler.go`

```go
package handlers

import (
	"github.com/gin-gonic/gin"
)

func HealthHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status": "ok",
		})
	}
}
```

**Line by line:**

- `package handlers` — this file belongs to the `handlers` package (the folder is
  `internals/handlers`). The package name does not have to match the folder name, but
  here it does, which is the convention. All files in the same folder must use the same
  package name or compilation fails.
- `import "github.com/gin-gonic/gin"` — we need Gin's `*gin.Context` and `gin.H`.
  Notice Go imports the *full path* of the package; `gin` is just the last segment used
  in code.
- `func HealthHandler() gin.HandlerFunc {` — this is a **factory function**. It does
  not handle a request itself; it *returns* a handler. Why a factory? Two reasons:
  1. Consistency: look at Layer 11 — `middleware.Authenticate(jwtSecret)` is also a
     factory that *captures* a value (the secret). Factories are how Gin lets us pass
     configuration into a handler.
  2. Readability: `r.GET("/health", handlers.HealthHandler())` reads like English.
- `return func(c *gin.Context) { ... }` — this inner function is the actual handler.
  It is a **closure**: even though it will run later (when a request arrives), it
  remembers the scope in which it was created. `c` is Gin's context — it carries the
  request *and* the response writer.
- `c.JSON(200, gin.H{"status": "ok"})` — two things happen:
  1. `gin.H{...}` is shorthand for `map[string]any`. We are building the JSON object.
     `gin.H{"status": "ok"}` is literally `map[string]any{"status": "ok"}`.
  2. `c.JSON(code, value)` sets the HTTP status code to `200`, sets the header
     `Content-Type: application/json`, serializes the value to JSON using
     `encoding/json`, and writes it to the response. The client receives exactly
     `{"status":"ok"}`.

**Runtime trace — what happens when this handler is hit:**

```
curl GET /health
   │  TCP connection opens
   ▼
Gin parses "GET /health HTTP/1.1"
   │  router matches path "/health" → this handler
   ▼
HealthHandler() is called (the factory), returns the closure
   │
   ▼
closure runs with c = {request: GET /health, response: (empty)}
   │  c.JSON(200, gin.H{"status":"ok"})
   │    → sets status 200
   │    → json.Marshal(map) → {"status":"ok"}
   │    → writes to TCP socket
   ▼
curl prints: {"status":"ok"}
```

### Step 4 — Write the router

File: `internals/router/routes.go`

> ⚠ **Important for Layer 1:** this is the *final* router used later. For now, write the
> minimal version below so it compiles with only the health handler.

```go
package router

import (
	"github.com/gin-gonic/gin"

	"github.com/raaj2493/production-systems/heroverse/internals/handlers"
)

func SetupRouter(env string) *gin.Engine {
	r := gin.New()
	r.GET("/health", handlers.HealthHandler())
	return r
}
```

**Line by line:**

- `func SetupRouter(env string) *gin.Engine {` — the router is also a factory. It
  returns a `*gin.Engine` (the whole application). We pass `env` so it can decide
  debug vs release mode later.
- `r := gin.New()` — creates a bare engine. `gin.Default()` would also add the Logger
  and Recovery middleware; we use `New()` so we control exactly what middleware runs
  (we add authentication middleware ourselves in Layer 11).
- `r.GET("/health", handlers.HealthHandler())` — **route registration**. It says:
  "when an HTTP GET arrives on path `/health`, run the handler returned by
  `HealthHandler()`." Note the `()` — we call the factory *now* and hand Gin the
  resulting function. Gin stores it in an internal radix tree keyed by method + path.
- `return r` — hand the fully-configured engine back to `main`.

**Runtime trace — route registration:**

```
SetupRouter("development")
   │
   ▼
gin.New() → empty engine
   │
   ▼
r.GET("/health", handler)
   │  Gin inserts the route into an internal tree:
   │  method=GET, path=/health, handlers=[closure]
   ▼
return engine (the whole app, ready to serve)
```

### Step 5 — Write the entry point

File: `cmd/api/main.go`

```go
package main

import (
	"log"
	"net/http"

	"github.com/raaj2493/production-systems/heroverse/internals/router"
)

func main() {
	engine := router.SetupRouter("development")

	server := &http.Server{
		Addr:    ":8080",
		Handler: engine,
	}

	log.Println("Starting server on port 8080...")
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
```

**Line by line:**

- `package main` — only `cmd/api` has this. A `main` package is a program; every other
  package is a library.
- `func main() {` — the starting point Go executes when you run the binary. There is
  exactly one `main` in a runnable program.
- `engine := router.SetupRouter("development")` — ask the router for the Gin engine.
- `server := &http.Server{ Addr: ":8080", Handler: engine }` — build a real HTTP
  server. `Addr` is the listen address (`:8080` means "all interfaces, port 8080").
  `Handler` is everything that will process requests — our Gin engine. The `&` makes a
  *pointer* to the struct; `http.Server` methods need the pointer so they can mutate
  shared state.
- `log.Println("Starting server on port 8080...")` — log so a human knows the app is
  up. Logs go to stdout with a timestamp.
- `server.ListenAndServe()` — **this call blocks forever**, serving requests until the
  process is killed. The `err != http.ErrServerClosed` check means: when the server is
  shut down gracefully, the returned error is *expected*, so we do not treat it as a
  crash.

**Runtime trace — the full boot sequence:**

```
go run cmd/api/main.go
   │  Go compiles all packages, links the binary, runs it
   ▼
main()
   │
   ▼
SetupRouter("development") → *gin.Engine with /health registered
   │
   ▼
&http.Server{Addr: ":8080", Handler: engine}
   │
   ▼
ListenAndServe()
   │  binds TCP socket on :8080
   │  blocks forever, accepting connections
   │  (Ctrl+C kills the process — no graceful shutdown yet)
```

## ④ Flow Check

```
curl GET /health
   │
   ▼
http.Server (port 8080)
   │
   ▼
Gin engine ── matches GET "/health"
   │
   ▼
handlers.HealthHandler → writes {"status":"ok"} (200)
```

**Walk one real request through the layer (narrative):**

1. curl opens a TCP socket to `localhost:8080` and sends `GET /health HTTP/1.1`.
2. `http.Server` (the standard library part) accepts the connection, reads bytes, and
   parses them into an `*http.Request`.
3. Because `server.Handler` is our Gin engine, the request is handed to Gin.
4. Gin inspects the method (`GET`) and path (`/health`), walks its route tree, finds
   the handler we registered in `SetupRouter`, and invokes it with a fresh
   `*gin.Context`.
5. The handler calls `c.JSON(200, ...)`.
6. Gin writes the HTTP response line, headers, and body back over the socket.
7. curl receives it and prints `{"status":"ok"}`.
8. The server loops back to step 1 and waits for the next connection.

## ⑤ Run it

```bash
go run cmd/api/main.go
# another terminal:
curl http://localhost:8080/health
# → {"status":"ok"}
```

**Troubleshooting:**

| Symptom | Cause | Fix |
|---|---|---|
| `port is already allocated` | Something already listens on 8080 | Use a different port: change `Addr` to `:8081` |
| `no required module provides package` | Missing Gin or wrong module path | Re-run `go get github.com/gin-gonic/gin`; check the module path in `go.mod` matches your imports |
| `undefined: handlers` | The import path or package name is wrong | Imports must end in the folder name; the package line must say `handlers` |
| `command not found: go` | Go is not installed / not on PATH | Install Go 1.25+ and restart your terminal |

## ⑤ The Gotcha

There is **no bug** in this layer yet — the project was fine up to here. Every real bug
(Bug #1 through #9) happens in later layers, when we start combining things. That is
the point: bugs here tend to come from *interactions*, not from single files. Keep the
skeleton working — you will need it as the test bed for every later layer.

---
# <a id="layer-2"></a>Layer 2 — Configuration: environment variables

## ① The Objective

Replace hard-coded values (port, env, later database credentials and JWT secret) with
values read from environment variables and a `.env` file. The same binary must run on
any machine without recompiling.

**Success checklist:**
- [ ] `.env` exists with `SERVER_PORT=8080`
- [ ] Changing `SERVER_PORT` in `.env` changes the port the server binds
- [ ] You understand what **struct tags** and **reflection** are
- [ ] `config.Validate()` exists and you know why it is there

## ② The Theory

Configuration lives outside the code because it **changes by environment**: your laptop
uses `localhost:5432`, production uses a managed database URL; production must use a
different JWT secret. Code should never change between environments — configuration
does. This is one of the **Twelve-Factor App** principles.

Two libraries do the work:

- **`godotenv`** — loads a `.env` file into the process environment (only if present).
  It reads the file once at startup, parses `KEY=VALUE` lines, and calls the real
  `os.Setenv` for each.
- **`caarlos0/env`** — reads environment variables into a typed Go struct using
  **struct tags** (`env:"PORT"`), applying defaults from `envDefault:"8080"`. It also
  does type conversion: it sees the field is an `int` and parses the string `"8080"`
  into the number `8080`.

### Go concepts used in this layer

| Concept | Where it appears | Plain-English meaning |
|---|---|---|
| Struct tag | `env:"PORT" envDefault:"8080"` | A string of metadata attached to a struct field, written in backticks. Libraries read it with **reflection** to change behavior. Tags never affect normal code — only reflectors use them. |
| Reflection | `env.Parse(&cfg)` | The ability of a program to inspect itself at runtime: "what fields does this struct have, what types, what tags?" You write the struct; the library walks it programmatically. |
| Pointer receiver | `func (c *Config) Validate() error` | A method declared on `*Config` (pointer). It can modify the original struct and avoids copying the whole thing on every call. |
| Value receiver | `func (db DatabaseConfig) DSN() string` | A method declared on `DatabaseConfig` (value). It gets a *copy* — safe to use when you only read fields. |
| `%w` in `fmt.Errorf` | `fmt.Errorf("...: %w", err)` | Error **wrapping**: keeps the original error inside the new one so `errors.Is`/`errors.As` can unwrap the chain later. `%v` would just format the text and lose the original. |
| Multiple return values | `func Load() (*Config, error)` | Go functions return any number of values. Returning `(result, error)` is the idiomatic way to signal failure. |

### Deep Dive — how reflection actually works

`env.Parse(&cfg)` receives a pointer to our `Config` struct. Inside, the library:

```
1. reflect.ValueOf(&cfg).Elem()  → gets the runtime representation of Config
2. For each field (App, Server, Database, JWT):
     - reads the field's tags → finds `env:"..."`, `envDefault:"..."`
     - looks up the environment variable by that name
     - if missing, uses the default
     - converts the string to the field's Go type
     - stores the value into the field
3. Repeats recursively for each nested struct
```

This is the *same* mechanism GORM uses to read `gorm:"..."` tags (Layer 4) and
`encoding/json` uses to read `json:"..."` tags. One idea — three libraries. Once you
understand reflection, tags across the whole ecosystem make sense.

## ③ The Build

### Step 1 — Install the libraries

```bash
go get github.com/joho/godotenv
go get github.com/caarlos0/env/v11
```

### Step 2 — Write the config package

File: `internals/config/config.go`

```go
package config

import (
	"fmt"
	"log"

	"github.com/caarlos0/env/v11"
	"github.com/joho/godotenv"
)

type AppConfig struct {
	Env string `env:"APP_ENV" envDefault:"development"`
}

type ServerConfig struct {
	Port int `env:"SERVER_PORT" envDefault:"8080"`
}

type DatabaseConfig struct {
	Host     string `env:"DATABASE_HOST" envDefault:"localhost"`
	Port     int    `env:"DATABASE_PORT" envDefault:"5432"`
	User     string `env:"DATABASE_USER" envDefault:"postgres"`
	Password string `env:"DATABASE_PASSWORD"`
	Name     string `env:"DATABASE_NAME" envDefault:"heroverse"`
}

type JWTConfig struct {
	Secret string `env:"JWT_SECRET" envDefault:"super-secret-default-key-change-in-production"`
}

type Config struct {
	App      AppConfig
	Server   ServerConfig
	Database DatabaseConfig
	JWT      JWTConfig
}

func (db DatabaseConfig) DSN() string {
	return fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=disable",
		db.Host, db.Port, db.User, db.Password, db.Name,
	)
}

func (c *Config) Validate() error {
	if c.App.Env == "production" {
		if c.Database.Password == "" {
			return fmt.Errorf("DATABASE_PASSWORD cannot be empty in production environment")
		}
		if c.JWT.Secret == "" || c.JWT.Secret == "super-secret-default-key-change-in-production" {
			return fmt.Errorf("JWT_SECRET must be explicitly set to a strong key in production environment")
		}
	}
	return nil
}

func Load() (*Config, error) {
	if err := godotenv.Load(); err != nil {
		log.Println("config: no .env file found, using system environment variables")
	}

	var cfg Config

	if err := env.Parse(&cfg); err != nil {
		return nil, fmt.Errorf("config: failed to parse environment variables: %w", err)
	}

	if err := cfg.Validate(); err != nil {
		return nil, fmt.Errorf("config: validation failed: %w", err)
	}

	return &cfg, nil
}
```

**Line by line:**

- **The four sub-structs** (`AppConfig`, `ServerConfig`, `DatabaseConfig`,
  `JWTConfig`) — configuration grouped by concern. Each field has two tags:
  - `env:"APP_ENV"` — which environment variable to read.
  - `envDefault:"development"` — the fallback if the variable is missing.
  - `DatabaseConfig.Password` has **no default** — this forces production to provide
    it (see `Validate`). In development it is just empty and we do not care.
- **`func (db DatabaseConfig) DSN() string`** — a **method with a value receiver**.
  It returns the **Data Source Name**: the one string the PostgreSQL driver needs.
  `fmt.Sprintf` formats with `%s` (string) and `%d` (int). The result looks like:

  ```
  host=localhost port=5432 user=postgres password=secretpassword dbname=heroverse sslmode=disable
  ```

  `sslmode=disable` disables TLS (fine for local dev; production would use `require`).
- **`func (c *Config) Validate() error`** — a **method with a pointer receiver**.
  It only enforces rules in `production`: the database password must exist and the JWT
  secret must not be the default. This is **fail-fast**: a misconfigured production
  build refuses to boot instead of running with a known-secret.
- **`func Load() (*Config, error)`** — the only function in the entire project that
  talks to environment variables:
  1. `godotenv.Load()` — read `.env` into the environment. If it fails (no `.env`),
     that is fine in development; we log a note and continue.
  2. `var cfg Config` — an empty struct.
  3. `env.Parse(&cfg)` — reflection fills every field from env vars + defaults.
  4. `cfg.Validate()` — enforce production rules.
  5. `return &cfg, nil` — return a pointer (shared, not copied).
- **The `%w` in `fmt.Errorf`** — wraps the original error so the message keeps its
  chain (`errors.Is` can still match it). This pattern appears in every layer.

### Step 3 — Update `main.go` to use config

Change the minimal `main.go` to call `config.Load()` and build the server address
from config:

```go
cfg, err := config.Load()
if err != nil {
	log.Fatalf("Failed to load config: %v", err)
}
```

Then use `fmt.Sprintf(":%d", cfg.Server.Port)` for the `Addr`:

```go
server := &http.Server{
	Addr:    fmt.Sprintf(":%d", cfg.Server.Port),
	Handler: engine,
}
```

### Step 4 — Create `.env`

File: `.env`

```bash
APP_ENV=development
SERVER_PORT=8080
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USER=postgres
DATABASE_PASSWORD=secretpassword
DATABASE_NAME=heroverse
JWT_SECRET=super-secret-default-key-change-in-production
```

**Important:** add `.env` to `.gitignore`. Secrets belong in the environment, never in
version control.

## ④ Flow Check

```
go run cmd/api/main.go
   │
   ▼
config.Load()
   ├─ godotenv.Load()      ← reads .env into process env
   ├─ env.Parse(&cfg)      ← tags + env vars + defaults → typed Config
   ├─ cfg.Validate()       ← production guard
   ▼
cfg.Server.Port → ":8080"
```

**Walk one real request through the layer (narrative):**

1. You run `go run cmd/api/main.go`.
2. `config.Load()` runs as the very first statement in `main`.
3. `godotenv.Load()` opens `.env`, reads `SERVER_PORT=8080`, and calls `os.Setenv("SERVER_PORT", "8080")`.
4. `env.Parse(&cfg)` reflects over `Config`, reaches `ServerConfig.Port`, finds tag
   `env:"SERVER_PORT"`, looks up the environment variable — now present — converts the
   string `"8080"` to the int `8080`, and stores it.
5. `cfg.Validate()` passes (we are in `development`).
6. `main` builds `Addr: fmt.Sprintf(":%d", cfg.Server.Port)` → `":8080"`.
7. The server binds port 8080. Later layers read `cfg.Database`, `cfg.JWT` the same way.

## ⑤ Run it

```bash
go run cmd/api/main.go
# → Starting server on port 8080...
curl http://localhost:8080/health   # still works, port now from config
```

**Prove config is live:** edit `.env`, change `SERVER_PORT=9090`, restart, and the log
now says `Starting server on port 9090...`. No recompile — that is the point.

**Troubleshooting:**

| Symptom | Cause | Fix |
|---|---|---|
| Logs say "no .env file found" | `.env` is not in the working directory | Run the server from `Heroverse/` (the folder holding `.env`) |
| Server still on 8080 after editing `.env` | You did not restart the process | Ctrl+C, then run again |
| `failed to parse environment variables` | A var is unset and has no default (e.g. `DATABASE_PASSWORD` in strict mode) | Provide the variable in `.env` or the shell |

## ⑤ The Gotcha — Why config must come first

`config.Load()` is the very first call in `main`. If you hard-code anything, you can't
change behaviour without recompiling. And because `Validate()` fails fast, a missing
production password is reported at startup — not after a week of silent 500 errors.

**Related real-world failure mode:** the JWT default secret here is
`super-secret-default-key-change-in-production`. If production ever runs with that
value, anyone who reads this repo can forge admin tokens. `Validate()` is the guard
that makes that impossible — it refuses to start. This is exactly the class of bug that
gets headlines when it is missing.

---
# <a id="layer-3"></a>Layer 3 — Database connection & migrations

## ① The Objective

Open a PostgreSQL connection with a connection pool, and write a migration helper that
creates tables from our models.

**Success checklist:**
- [ ] `database.Connect(&cfg.Database)` returns without error
- [ ] The log prints `Database connected successfully.`
- [ ] You know what `TranslateError: true` does and why it matters
- [ ] You can explain the three pool knobs

## ② The Theory

Three important ideas:

1. **Connection pool** — opening a database connection costs a TCP handshake + auth.
   We keep a pool of reusable connections: `MaxOpen` (upper cap), `MaxIdle` (kept
   warm), `MaxLifetime` (recycle stale ones). The app borrows a connection, uses it,
   returns it. Without a pool, every request would pay the full connection cost and
   you would eventually exhaust the server's file descriptors.
2. **ORM + `TranslateError`** — GORM turns Go structs into SQL and SQL results back
   into structs. `TranslateError: true` makes GORM convert database-specific errors
   (e.g. Postgres `23505` for a unique violation) into portable Go sentinels like
   `gorm.ErrDuplicatedKey`. Without it, duplicate-email detection cannot work — the
   error would arrive as a raw Postgres string.
3. **AutoMigrate** — reads our model struct tags and generates `CREATE TABLE IF NOT
   EXISTS`. It is idempotent, so it is safe to run at every startup. Run it once and
   again; nothing breaks.

### Go concepts used in this layer

| Concept | Where it appears | Plain-English meaning |
|---|---|---|
| Variadic parameter | `func Migrate(db *gorm.DB, models ...any) error` | `...any` means "zero or more values of any type". Inside the function, `models` is a slice. GORM reflects over each one. |
| Method chaining | `db.WithContext(ctx).Where(...).First(&user)` | Each method returns the same `*gorm.DB`, so you can call methods one after another. If a query has already errored, later calls short-circuit to the error. |
| Pointer parameter | `cfg *config.DatabaseConfig` | Passing a pointer means the callee reads the *same* struct; we do not copy the whole config. |
| Type alias / third-party types | `*gorm.DB` | We store and pass around types owned by GORM. `*gorm.DB` is a handle to the ORM engine. |
| `time.Duration` | `15 * time.Minute` | A named int64 type holding nanoseconds. `15 * time.Minute` is the Go way to write "15 minutes". |

### Deep Dive — what is a connection pool at the database level?

Postgres, like every database, is a server with its own process model. Every new
connection requires:

```
1. TCP handshake (3 packets)
2. SSL/TLS negotiation (if enabled)
3. Authentication exchange (e.g. password challenge-response)
4. Backend process spawn in Postgres (fork + memory)
5. `SET` statements GORM issues per connection (session config)
```

That can be 5–20 ms of pure overhead per connection. A pool amortizes it: the first
request pays the cost, the next 24 reuse warm connections. The three knobs:

- **MaxOpenConns** — hard cap on simultaneous connections (25). Requests beyond that
  queue in Go instead of piling up connections on the server.
- **MaxIdleConns** — warm connections kept ready (10). Idle ones are kept, not closed.
- **ConnMaxLifetime** — recycle connections after 15 min so stale ones die. This
  prevents "connection has gone away" errors when a database restarts or a proxy
  closes long-lived connections.

### Deep Dive — `TranslateError` and Postgres error codes

Postgres reports errors with an SQLSTATE code — a 5-character string. The ones you
will meet in this project:

| SQLSTATE | Meaning | GORM sentinel (with TranslateError) |
|---|---|---|
| `23505` | unique_violation | `gorm.ErrDuplicatedKey` |
| `02000` / `P0002` | no data / record not found | `gorm.ErrRecordNotFound` |
| `23503` | foreign_key_violation | `gorm.ErrForeignKeyViolated` |
| `42P01` | undefined_table | (no sentinel — wrapped) |

With `TranslateError: false`, `errors.Is(err, gorm.ErrDuplicatedKey)` never matches
and duplicates return `500`. With it, the match works and we can return a clean `400`.

## ③ The Build

### Step 1 — Install GORM and the Postgres driver

```bash
go get gorm.io/gorm
go get gorm.io/driver/postgres
```

### Step 2 — Write the database package

File: `internals/database/db.go`

```go
package database

import (
	"fmt"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"github.com/raaj2493/production-systems/heroverse/internals/config"
)

func Connect(cfg *config.DatabaseConfig) (*gorm.DB, error) {

	db, err := gorm.Open(postgres.Open(cfg.DSN()), &gorm.Config{
		TranslateError: true,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to open database connection: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("failed to get underlying sql.DB instance: %w", err)
	}

	sqlDB.SetMaxOpenConns(25)
	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetConnMaxLifetime(15 * time.Minute)

	if err := sqlDB.Ping(); err != nil {
		return nil, fmt.Errorf("database ping failed: %w", err)
	}

	return db, nil
}

func Migrate(db *gorm.DB, models ...any) error {
	if err := db.AutoMigrate(models...); err != nil {
		return fmt.Errorf("failed to auto-migrate database schema: %w", err)
	}
	return nil
}
```

**Line by line:**

- `func Connect(cfg *config.DatabaseConfig) (*gorm.DB, error)` — takes config, returns
  a GORM handle.
- `gorm.Open(postgres.Open(cfg.DSN()), &gorm.Config{ TranslateError: true })` —
  `postgres.Open(...)` creates the *dialector* (the Postgres adapter); `gorm.Open`
  builds the ORM layer on top. `TranslateError: true` is the line that makes later
  `errors.Is(err, gorm.ErrDuplicatedKey)` checks work.
- `db.DB()` — returns the underlying `*sql.DB` (Go's standard database handle) so we
  can tune the pool.
- The three `SetMax*` calls — pool tuning (25 open, 10 idle, recycle after 15 min).
- `sqlDB.Ping()` — **fail-fast**: verify we can actually reach Postgres *now*, not on
  the first request. `Ping` opens a connection from the pool if needed and issues a
  trivial round-trip (Postgres answers `SELECT 1`).
- `func Migrate(db *gorm.DB, models ...any) error` — `...any` means "any number of
  values of any type". `AutoMigrate` reflects over them and creates/updates tables.

**Runtime trace — what `Connect` does:**

```
Connect(&cfg.Database)
   │
   ▼
postgres.Open("host=localhost port=5432 ...")
   │  builds a dialector that knows how to speak Postgres protocol
   ▼
gorm.Open(dialector, {TranslateError: true})
   │  gorm opens its first connection lazily (not yet — that's what Ping is for)
   ▼
db.DB() → *sql.DB with a fresh pool
   │
   ▼
SetMaxOpenConns(25) / SetMaxIdleConns(10) / SetConnMaxLifetime(15m)
   │
   ▼
sqlDB.Ping()
   │  borrows a connection
   │  sends: SELECT 1
   │  Postgres replies: 1
   │  returns connection to pool
   ▼
return db, nil   ← "database connected successfully"
```

### Step 3 — Wire into `main.go`

In the final `main.go`, after `config.Load()`:

```go
db, err := database.Connect(&cfg.Database)
if err != nil {
	log.Fatalf("Failed to connect to database: %v", err)
}
log.Println("Database connected successfully.")
```

> At this point we do not have models yet, so call `Migrate` with an empty slice or
> skip it; the next layer adds the models.

## ④ Flow Check

```
config.Load()
   │
   ▼
database.Connect(&cfg.Database)
   ├─ postgres.Open(cfg.DSN())        ← the one connection string
   ├─ gorm.Open(..., {TranslateError})← ORM + translated errors
   ├─ pool tuning                     ← 25/10/15min
   ├─ Ping()                          ← fail-fast
   ▼
*gorm.DB  →  used by repositories (Layer 6)
```

**Walk one real connection through the layer (narrative):**

1. `main` calls `database.Connect(&cfg.Database)`.
2. `cfg.Database.DSN()` produces the one-string connection spec.
3. `postgres.Open` wraps it in a dialector (the Postgres driver's entry point).
4. `gorm.Open` initializes the ORM but does not connect yet — GORM is lazy.
5. `db.DB()` exposes the standard `*sql.DB` pool; we tune it.
6. `Ping()` forces the first real connection: TCP → auth → `SELECT 1`. If Postgres is
   down, Ping fails and `main` calls `log.Fatalf` — the server never starts.
7. Later layers receive this same `*gorm.DB` handle through constructors
   (`NewUserRepository(db)`, `NewHeroRepository(db)`).

## ⑤ Run it

```bash
docker compose up -d postgres   # (Layer 12 has the compose file; for now run Postgres any way you like)
go run cmd/api/main.go
# → Database connected successfully.
```

**Troubleshooting:**

| Symptom | Cause | Fix |
|---|---|---|
| `database ping failed: connection refused` | Postgres is not running / wrong port | `docker compose up -d postgres`; check `DATABASE_PORT` in `.env` |
| `password authentication failed` | Wrong user/password | Fix `DATABASE_USER`/`DATABASE_PASSWORD` in `.env` |
| `database "heroverse" does not exist` | DB not created | It is created automatically by the compose file's `POSTGRES_DB`; if running Postgres manually, run `CREATE DATABASE heroverse;` |
| `failed to open database connection: ... TLS` | SSL mismatch | Keep `sslmode=disable` in the DSN for local dev |
| A file named `host=localhost port=5432 ...` appears in the folder | The old SQLite bug (see Gotcha) | Delete the garbage file; switch to the Postgres driver |

## ⑤ The Gotcha — Two real bugs happened right here

**Bug #7 (wrong driver):** the project originally opened the connection with the
**SQLite** driver (`sqlite.Open(cfg.DSN())`) while the DSN was a PostgreSQL connection
string. SQLite silently treated that string as a *filename* and created a garbage file
on disk — bypassing Postgres entirely. The dialector and the DSN must always match.

**Bug #6 (missing `TranslateError`):** with `TranslateError: false`, duplicate email
errors surfaced as raw `SQLSTATE` strings, so `errors.Is(err, gorm.ErrDuplicatedKey)`
never matched and duplicates returned `500` instead of `400`. Both fixed by the two
lines shown above.

**How you would debug these:** after a "duplicate email" call, check the response body
— a raw error like `ERROR: duplicate key value violates unique constraint
"idx_users_email" (SQLSTATE 23505)` leaking to the client means translation is off.
Check the project folder for a suspicious file named like the DSN — that is SQLite's
tell-tale sign.

---
# <a id="layer-4"></a>Layer 4 — Models: User and Hero

## ① The Objective

Define the two database tables as Go structs. The structs are the **single source of
truth** for both the SQL schema (GORM tags) and the JSON API shape (json tags).

**Success checklist:**
- [ ] Both models exist: `User` in `user-model.go`, `Hero` in `hero-model.go`
- [ ] `database.Migrate(db, &models.Hero{}, &models.User{})` is called in `main.go`
- [ ] The log prints `Database schema auto-migrated successfully.`
- [ ] You can read a struct tag out loud ("gorm primaryKey, json id")

## ② The Theory

A **struct tag** is metadata attached to a field. Three different libraries read these
tags:

- `gorm:"..."` — GORM reads these to build the table.
- `json:"..."` — `encoding/json` reads these to name the fields in API responses.
- `env:"..."` — `caarlos0/env` read these in Layer 2.

The killer feature: **one struct, two consumers**. Add a field once and both the table
and the JSON automatically gain it. If you later rename a column, you change one line.

### Go concepts used in this layer

| Concept | Where it appears | Plain-English meaning |
|---|---|---|
| Struct tag | backticks after a field | Raw string metadata; `reflect` reads it. The backtick (not a quote) is required. |
| Named type | `type UserRole string` | A brand-new type whose underlying representation is `string`. It is distinct from `string` for the compiler. |
| Constant | `const RoleUser UserRole = "user"` | A compile-time fixed value. Grouped constants share the type and get sequential values when using `iota` (not used here). |
| Embedded struct / promotion | `jwt.RegisteredClaims` (Layer 5) | A field with no name embeds the type; its fields are "promoted" to the outer struct. |
| Zero value | `ID uint` when new | Every field starts at its zero value (0, "", nil) before you set it. GORM uses `0` to decide "new record". |
| `time.Time` | `CreatedAt time.Time` | Go's standard timestamp type. GORM fills `CreatedAt`/`UpdatedAt` automatically *by field name* — no tag needed. |
| `json:"-"` | `PasswordHash string` | "Never serialize this field to JSON." The field exists in memory and DB, but never in an API response. |

### Deep Dive — the meaning of each constraint

- `primaryKey` — GORM creates an auto-incrementing integer primary key. Postgres uses
  `BIGSERIAL` (or `IDENTITY`): the DB assigns the value on insert.
- `uniqueIndex` — creates a unique index; the **database** enforces "no duplicate
  emails" *atomically*. This matters: a check-then-insert race (two requests read "no
  email" at the same time) is only prevented by the unique constraint, which rejects
  the second insert at the DB level with `23505`.
- `not null` — column cannot be NULL.
- `type:varchar(20)` — the column is `VARCHAR(20)`; `default:'user'` gives the column
  a database-level default applied when no value is provided.
- `json:"-"` — never serialize: the password hash can never appear in an API response.
- `CreatedAt`/`UpdatedAt` — GORM fills these automatically by name. `CreatedAt` is set
  on insert; `UpdatedAt` is refreshed on update.

### Deep Dive — the exact SQL GORM generates

When `AutoMigrate(&models.Hero{}, &models.User{})` runs, GORM builds roughly this DDL:

```sql
CREATE TABLE IF NOT EXISTS users (
  id            BIGSERIAL PRIMARY KEY,
  email         VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role          VARCHAR(20) NOT NULL DEFAULT 'user',
  created_at    TIMESTAMPTZ,
  updated_at    TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users (email);

CREATE TABLE IF NOT EXISTS heroes (
  id         BIGSERIAL PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  user_id    BIGINT NOT NULL,
  power      VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_heroes_user_id ON heroes (user_id);
```

Observations worth internalizing:

- **`BIGSERIAL`** — an 8-byte auto-incrementing integer. GORM maps Go `uint` to it.
- **`VARCHAR(255)` vs `VARCHAR(100)`** — GORM picks 255 for unbounded `string`, and
  honors `gorm:"size:100"` when given. Not-null columns reject NULL rows.
- **The unique index on email** is a separate `CREATE UNIQUE INDEX` statement, not a
  column constraint — that is how GORM implements `uniqueIndex`.
- **`TIMESTAMPTZ`** — Postgres stores timestamps with timezone. Good default.
- **`idx_heroes_user_id`** — a plain (non-unique) index on `user_id`, because the
  column carries `gorm:"index"`. Ownership lookups ("heroes owned by user 3") use this
  index; Postgres can answer with an index scan instead of a full table scan.

### Why `Hero.UserID` has no foreign key

The `user_id` column references `users.id` conceptually, but we deliberately keep it a
plain indexed column — no `REFERENCES users(id)` constraint. Ownership is enforced in
code at Layer 11 (`isOwnerOrAdmin`). Trade-offs:

- **Pro of FK:** the DB guarantees a hero always points at a real user.
- **Con of FK:** deletes of users get blocked (or cascade) and schema becomes rigid.
  For this tutorial, code-level enforcement keeps the schema simple and the ownership
  rule explicit and testable.

## ③ The Build

### Step 1 — User model

File: `internals/models/user-model.go`

```go
package models

import (
	"time"
)

type UserRole string

const (
	RoleUser  UserRole = "user"
	RoleAdmin UserRole = "admin"
)

type User struct {
	ID           uint      `json:"id" gorm:"primaryKey"`
	Email        string    `json:"email" gorm:"uniqueIndex;not null"`
	PasswordHash string    `json:"-" gorm:"not null"`
	Role         UserRole  `json:"role" gorm:"type:varchar(20);not null;default:'user'"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}
```

**Line by line:**

- `type UserRole string` — a *named type*. `RoleUser` and `RoleAdmin` are constants
  of this type. Because the field `Role UserRole` is typed, the compiler rejects
  `user.Role = "banana"`. This is compile-time domain modeling: invalid roles are
  impossible to express.
- `ID uint \`json:"id" gorm:"primaryKey"\`` — `uint` is a positive integer;
  `primaryKey` makes GORM create an auto-increment primary key. `uint` (unsigned) means
  negative IDs are not expressible, which is correct for an ID.
- `Email string \`json:"email" gorm:"uniqueIndex;not null"\`` — `uniqueIndex` creates
  a unique index: the **database** guarantees no two rows share an email (this is what
  detects duplicates atomically). `not null` adds a `NOT NULL` constraint.
- `PasswordHash string \`json:"-"\`` — **`json:"-"` means "never serialize this
  field"**. The hash exists in the database but can never appear in an API response.
- `Role UserRole \`json:"role" gorm:"type:varchar(20);not null;default:'user'"\`` —
  column type, not-null, and a database default of `'user'`.
- `CreatedAt`/`UpdatedAt time.Time` — GORM **automatically** fills these on insert and
  update because of their names. No gorm tag needed.

### Step 2 — Hero model

File: `internals/models/hero-model.go`

```go
package models

import (
	"time"
)

type Hero struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Name      string    `gorm:"size:100;not null" json:"name"`
	UserID    uint      `json:"user_id" gorm:"not null;index"`
	Power     string    `gorm:"size:255;not null" json:"power"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
```

**Line by line:**

- `Name string \`gorm:"size:100;not null"\`` — column width 100 + not null.
- `UserID uint \`json:"user_id" gorm:"not null;index"\`` — this is the **owner** of
  the hero (a reference to `users.id`). `index` creates an index so ownership lookups
  are fast. We deliberately keep it a plain indexed column (no database foreign key);
  ownership is enforced in code at Layer 11.
- `Power string \`gorm:"size:255;not null"\`` — column width 255 + not null.

### Step 3 — Migrate both models

Update `main.go` to migrate **both** models:

```go
if err := database.Migrate(db, &models.Hero{}, &models.User{}); err != nil {
	log.Fatalf("Failed to auto-migrate database: %v", err)
}
```

The `&models.Hero{}` syntax creates a *pointer to an empty struct*. GORM uses the
pointer only to introspect the type — the values inside are irrelevant for migration.

## ④ Flow Check

```
models.Hero  ──AutoMigrate──▶  heroes table
models.User  ──AutoMigrate──▶  users table
      │
      └── both passed to database.Migrate in main.go
```

**Walk one migration through the layer (narrative):**

1. `main.go` calls `database.Migrate(db, &models.Hero{}, &models.User{})`.
2. `Migrate` passes the models to `AutoMigrate`.
3. GORM reflects over `Hero`: reads every field, its type, and its `gorm:` tags.
4. GORM builds `CREATE TABLE IF NOT EXISTS heroes (...)`, sends it, and executes it.
5. GORM does the same for `User` (including the unique index on email).
6. Both statements are wrapped in a transaction by default, so a failure rolls back
   cleanly.
7. `main.go` logs `Database schema auto-migrated successfully.`

**Verify it directly:** open a psql prompt and inspect:

```bash
docker exec -it heroverse_db psql -U postgres -d heroverse -c "\d heroes"
docker exec -it heroverse_db psql -U postgres -d heroverse -c "\d users"
```

## ⑤ Run it

```bash
docker compose up -d postgres
go run cmd/api/main.go
# → Database schema auto-migrated successfully.
```

**Troubleshooting:**

| Symptom | Cause | Fix |
|---|---|---|
| `failed to auto-migrate database: ... relation "heroes" already exists` | Migration ran twice with conflicting state | AutoMigrate is idempotent; this error usually means a stale table with a mismatched shape — `DROP TABLE heroes CASCADE;` and re-run |
| No `users` table in psql | Migration did not include the User model | Check the `Migrate` call includes `&models.User{}` (this exact mistake was Bug #5) |

## ⑤ The Gotcha — Bug #5: only the Hero was migrated

Originally `main.go` called `database.Migrate(db, &models.Hero{})` — the `User` model
was missing. The app started fine, but `/register` crashed with
`relation "users" does not exist` because the table was never created. Migration must
receive **every** model the app uses.

**Why this is sneaky:** the server *starts* fine — `heroes` migrates, nothing crashes
at boot. The failure only appears at runtime, the first time a request touches the
`users` table. That is why the success checklist includes checking `\d users` in psql:
a boot that succeeds is not proof the schema is complete.

---
# <a id="layer-5"></a>Layer 5 — Security: bcrypt & JWT

## ① The Objective

Build the two security primitives: password hashing (bcrypt) and token
create/validate (JWT). These are pure functions — they know nothing about HTTP or the
database.

**Success checklist:**
- [ ] A scratch `main()` can generate a token and validate it back
- [ ] You can decode a JWT by hand (see the Deep Dive)
- [ ] You can explain why passwords are hashed, not encrypted
- [ ] You know why we force HMAC in the validator

## ② The Theory

### Hashing vs encryption
- **Encryption** is two-way (you decrypt with a key).
- **Hashing** is one-way (you cannot recover the input). Passwords are *hashed*, never
  encrypted, so even a leaked database yields no passwords.

### bcrypt
- A deliberately slow hash function. Slow = expensive to brute-force.
- It embeds a random **salt** and the **cost** in the output string, so identical
  passwords produce different hashes, defeating rainbow tables.
- You never store the salt separately — it is part of the stored hash string.

### JWT
A token is three base64url segments separated by dots: `header.payload.signature`.
- **header** — `{"alg":"HS256","typ":"JWT"}`.
- **payload** — our claims (`user_id`, `role`, `exp`, `iat`). Base64 is NOT encryption;
  anyone can read it. So we only put non-secret data in it.
- **signature** — an HMAC of header+payload using the secret key. Only the secret
  holder can produce it, so a tampered token fails verification.

### Why HS256 and not ES256
HS256 (HMAC-SHA256) is **symmetric** — the same string secret signs and verifies.
ES256 (ECDSA) needs an `*ecdsa.PrivateKey` object, not a string. Passing a `[]byte`
secret to ES256 fails at runtime. Our config holds a string, so we use HS256 — and we
*must* tell the validator to accept only HS256 (algorithm-confusion defense).

### Go concepts used in this layer

| Concept | Where it appears | Plain-English meaning |
|---|---|---|
| Sentinel error | `ErrInvalidToken = errors.New(...)` | A named, shared error value. Match it with `errors.Is` — never compare with `==` against a freshly-created error. |
| Error wrapping | `fmt.Errorf("%w: %v", ErrInvalidToken, err)` | Keeps the sentinel in the chain (so `errors.Is` works) *and* includes the detailed cause text. |
| Type assertion | `token.Method.(*jwt.SigningMethodHMAC)` | At runtime, "check this interface value and if it is really a `*jwt.SigningMethodHMAC`, give it to me as that type". The `ok` form (`x, ok := ...`) is the safe version. |
| Interfaces | `token.Method` | A value's *behaviour*, not its concrete type. The JWT library stores the signing method behind an interface; we check what it actually is. |
| `[]byte` conversion | `[]byte(secretKey)` | A `string` and a `[]byte` are different types; crypto functions want bytes. Conversion is explicit and cheap (a copy). |
| Time arithmetic | `time.Now().Add(24 * time.Hour)` | `time.Time` supports `Add(Duration)`. 24h is a `time.Duration` constant. |

### Deep Dive — decode a JWT by hand

Take a real token produced by `GenerateJWT`:

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJyb2xlIjoidXNlciIsImV4cCI6MTc1MDAwMDAwMCwiaWF0IjoxNzQ5OTEzNjAwfQ.abc123signature...
```

Three dot-separated segments. Decode segment 1 and 2 with base64url:

```bash
echo -n "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" | base64 -d
# → {"alg":"HS256","typ":"JWT"}

echo -n "eyJ1c2VyX2lkIjoxLCJyb2xlIjoidXNlciIsImV4cCI6MTc1MDAwMDAwMCwiaWF0IjoxNzQ5OTEzNjAwfQ" | base64 -d
# → {"user_id":1,"role":"user","exp":1750000000,"iat":1749913600}
```

Notice: anyone can read this. `exp` (expiry) and `iat` (issued at) are Unix
timestamps. The third segment is an **HMAC-SHA256** of `header.payload` keyed with the
secret. Without the secret you cannot forge it; if you change one byte of the payload,
verification fails because the signature no longer matches.

### Deep Dive — what is inside a bcrypt hash

```
$2a$10$WvJvQmO3rXpZ3kYxYQ3Ee.7l1B2wQ2e8lJ2kYvHx1wZ6iE9tXf0Pa
 │  │  └───────────────────┬────────────────────┘
 │  │                      └── 53 chars: first 22 = salt (base64), rest = hash
 │  └── cost (2^10 = 1024 rounds)
 └── algorithm identifier ($2a$ = bcrypt)
```

`bcrypt.CompareHashAndPassword` extracts the salt and cost *from the stored hash*,
recomputes with the presented password, and compares — all in constant time to avoid
timing attacks.

## ③ The Build

### Step 1 — Install the libraries

```bash
go get github.com/golang-jwt/jwt/v5
go get golang.org/x/crypto
```

### Step 2 — Password hashing

File: `internals/security/password.go`

```go
package security

import (
	"errors"
	"fmt"

	"golang.org/x/crypto/bcrypt"
)

func HashedPassword(password string) (string, error) {
	if password == "" {
		return "", errors.New("password cant be empty")
	}

	hashedByte, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", fmt.Errorf("security: failed to hash password: %w", err)
	}

	return string(hashedByte), nil
}

func CheckPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}
```

**Line by line:**

- `if password == "" { return "", errors.New("password cant be empty") }` — guard
  against hashing an empty string (an empty password would produce a valid-but-weak
  hash). The error is returned, not panicked.
- `bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)` — hashes.
  `DefaultCost` (10) means ~2^10 = 1024 iterations — the deliberate slowness. A round
  of bcrypt at cost 10 typically takes 50–100 ms, which is fine for a login but
  crippling for a brute-forcer.
- Returns the self-contained hash string like
  `$2a$10$...salt...hash...`. It embeds salt + cost, so we only ever store one string.
- `bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))` — recomputes and
  compares in constant time. Returns `nil` on match → our function returns `true`.

### Step 3 — JWT

File: `internals/security/jwt.go`

```go
package security

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type Claims struct {
	UserID uint   `json:"user_id"`
	Role   string `json:"role"`
	jwt.RegisteredClaims
}

var (
	ErrInvalidToken = errors.New("invalid or expired token")
)

func GenerateJWT(userID uint, role string, secretKey string) (string, error) {
	expirationTime := time.Now().Add(24 * time.Hour)

	claims := &Claims{
		UserID: userID,
		Role:   role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

	tokenString, err := token.SignedString([]byte(secretKey))
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

func ValidateJWT(tokenString string, secretKey string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(secretKey), nil
	})

	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidToken, err)
	}
	if !token.Valid {
		return nil, ErrInvalidToken
	}

	claims, ok := token.Claims.(*Claims)
	if !ok {
		return nil, ErrInvalidToken
	}

	return claims, nil
}
```

**Line by line:**

- `type Claims struct { UserID uint; Role string; jwt.RegisteredClaims }` — our custom
  claims plus the standard ones (expiry, issued-at) **embedded**. Because
  `jwt.RegisteredClaims` is embedded (no field name), its fields (`ExpiresAt`,
  `IssuedAt`) are promoted and accessible directly.
- `ErrInvalidToken = errors.New(...)` — a **sentinel error** (a named, shared error
  value). Middleware will match it with `errors.Is`.
- `GenerateJWT`:
  - `expirationTime := time.Now().Add(24 * time.Hour)` — tokens live 24 hours.
  - Builds `Claims`, signs with `jwt.SigningMethodHS256`, calls
    `token.SignedString([]byte(secretKey))`.
- `ValidateJWT`:
  - `jwt.ParseWithClaims(tokenString, &Claims{}, keyfunc)` — parses and verifies.
  - The **keyfunc** is the critical security line: `token.Method.(*jwt.SigningMethodHMAC)`
    forces the algorithm to be HMAC. Anything else (e.g. an attacker sending
    `"alg":"none"`) is rejected. Then it returns the secret key.
  - On error we wrap `ErrInvalidToken` with the underlying reason via `%w`.
  - `token.Valid` false → invalid. Then a **type assertion** `token.Claims.(*Claims)`
    converts the parsed claims back to our type.

**Runtime trace — GenerateJWT:**

```
GenerateJWT(1, "user", "super-secret...")
   │
   ▼
expirationTime = now + 24h
   │
   ▼
claims = {user_id:1, role:"user", exp:<24h from now>, iat:<now>}
   │
   ▼
jwt.NewWithClaims(HS256, claims) → unsigned token (2 segments)
   │
   ▼
SignedString(secret)
   │  computes HMAC-SHA256("header.payload", secret)
   │  base64url-encodes the signature
   ▼
return "eyJhbGci...eyJ1c2Vy...<signature>"
```

**Runtime trace — ValidateJWT:**

```
ValidateJWT(token, "super-secret...")
   │
   ▼
ParseWithClaims splits on "." → 3 segments
   │  header {"alg":"HS256"} → callback checks: is Method an *HMAC? yes
   │  → returns the secret key
   │  recomputes HMAC over segment1+2 and compares with segment3
   │  verifies exp/iat claims (exp is in the future? iat not in the future?)
   │  token.Valid = true
   ▼
type assertion token.Claims.(*Claims) → our claims
   │
   ▼
return &Claims{UserID:1, Role:"user", ...}, nil
```

## ④ Flow Check

```
AuthService.Create ──▶ security.HashedPassword  → hash to store
AuthService.Login   ──▶ security.GenerateJWT     → token for the client
Middleware          ──▶ security.ValidateJWT     → verify + extract user_id/role
```

## ⑤ Run it

Write a temporary scratch `main()` that generates a token and validates it (then
delete it):

```go
func main() {
	tok, _ := security.GenerateJWT(1, "user", "secret")
	claims, err := security.ValidateJWT(tok, "secret")
	fmt.Println(claims.UserID, err) // 1 <nil>
}
```

**Troubleshooting:**

| Symptom | Cause | Fix |
|---|---|---|
| `key is of invalid type` at signing | ES256 signing with a string secret (Bug #3) | Sign with `jwt.SigningMethodHS256` |
| `unexpected signing method` at validation | A non-HMAC algorithm was presented | Force HMAC in the keyfunc (already done) |
| Token validates with the wrong secret | Both secrets are in the HMAC family | Use a distinct secret per environment; the signature only matches the exact secret |
| `token is expired` | You waited past `exp` | Set 24h again or increase for tests |

## ⑤ The Gotcha — Bug #3: ES256 vs HS256 mismatch

The project originally *signed* with `jwt.SigningMethodES256` while passing a
`[]byte` string secret. ECDSA signing crashed with
`key is of invalid type: ECDSA sign expects *ecdsa.PrivateKey`, and the validator
expected HMAC anyway — so even correct tokens failed. Fix: sign and verify with
**HS256**, and force HMAC in the validator callback.

**Why this is a classic:** JWT libraries offer many algorithms. The error message is
cryptic, and the *signing* side and the *verifying* side can be out of sync (one fixed,
one not). The lesson: decide the algorithm once, and make the validator refuse anything
else — the type assertion `.(*jwt.SigningMethodHMAC)` does exactly that.

---
# <a id="layer-6"></a>Layer 6 — User Repository

## ① The Objective

Create the only code that talks to the `users` table: create a user, fetch by ID,
fetch by email.

**Success checklist:**
- [ ] `Create`, `GetByID`, `GetByEmail` exist on `UserRepository`
- [ ] You can say what SQL each method generates
- [ ] You understand why `Where("email = ?", email)` is SQL-injection-safe
- [ ] You know why the duplicate check relies on `TranslateError` (Layer 3)

## ② The Theory

The **repository** layer isolates the database. Nothing above it (services, handlers)
should ever write SQL or import GORM. Consequences:

- If we swap databases, only this layer changes.
- The service layer can be unit-tested with a fake repository.

Key techniques used here:

- **`WithContext(ctx)`** — ties the query to the request's context. If the client
  disconnects, the query is cancelled.
- **`errors.Is(err, gorm.ErrDuplicatedKey)`** — the duplicate-email check, which only
  works because of `TranslateError` (Layer 3).
- **Parameterized queries** — `Where("email = ?", email)` uses `?` placeholders, so
  input can never become SQL text (SQL-injection safe).

### Go concepts used in this layer

| Concept | Where it appears | Plain-English meaning |
|---|---|---|
| Method with pointer receiver | `func (r *UserRepository) Create(...)` | The method reads/writes through the same `*gorm.DB` held by the struct. |
| Constructor | `func NewUserRepository(db *gorm.DB) UserRepository` | The idiomatic way to create a ready-to-use instance. Go has no `new` keyword semantics here — constructors are just functions. |
| Context | `ctx context.Context` | A request-scoped object carrying cancellation and deadlines. Pass it down: HTTP → service → repository → SQL driver. |
| `errors.Is` | `errors.Is(err, gorm.ErrDuplicatedKey)` | Walks an error chain and reports whether the sentinel appears anywhere in it. The `%w` wrapping in Layers 2–3 makes this work. |
| Pointers in/out | `user *models.User`, `return &user, nil` | Pass structs by pointer to let the callee fill them; return pointers so callers can `nil`-check. |

### Deep Dive — the exact SQL each method generates

`Create` (GORM `Create(user)`) produces an `INSERT` and returns the generated columns:

```sql
INSERT INTO "users" ("email","password_hash","role","created_at","updated_at")
VALUES ($1,$2,$3,$4,$5)
RETURNING "id"
-- $1='alice@example.com'  $2='$2a$10$...'  $3='user'  $4='<now>'  $5='<now>'
```

Note the **`RETURNING "id"`** — Postgres hands back the auto-generated primary key and
GORM writes it into `user.ID`. GORM also sets `user.CreatedAt`/`UpdatedAt` in memory.

`GetByID` (GORM `First(&user, id)`) produces:

```sql
SELECT * FROM "users" WHERE "users"."id" = $1 ORDER BY "users"."id" LIMIT 1
-- $1=<id>
```

`GetByEmail` (GORM `Where("email = ?", email).First(&user)`) produces:

```sql
SELECT * FROM "users" WHERE email = $1 ORDER BY "users"."id" LIMIT 1
-- $1='alice@example.com'
```

**Why `?` / `$n` matters (SQL injection):** if we instead built
`fmt.Sprintf("email = '%s'", email)`, an attacker sending
`x' OR '1'='1` would turn the query into
`WHERE email = 'x' OR '1'='1'` — matching every row. With parameter binding, the value
is sent to Postgres as *data* in a separate protocol channel; it can never be parsed as
SQL. This one habit eliminates an entire vulnerability class.

## ③ The Build

File: `internals/repository/user-repository.go`

```go
package repository

import (
	"context"
	"errors"
	"fmt"

	"gorm.io/gorm"

	"github.com/raaj2493/production-systems/heroverse/internals/models"
)

type UserRepository struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) UserRepository {
	return UserRepository{
		db: db,
	}
}

func (r *UserRepository) Create(ctx context.Context, user *models.User) error {
	err := r.db.WithContext(ctx).Create(user).Error
	if err != nil {
		if errors.Is(err, gorm.ErrDuplicatedKey) {
			return errors.New("user with this email already exists")
		}
		return fmt.Errorf("failed to create user: %w", err)
	}
	return nil
}

func (r *UserRepository) GetByID(ctx context.Context, id uint) (*models.User, error) {
	var user models.User
	err := r.db.WithContext(ctx).First(&user, id).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("user not found")
		}
		return nil, fmt.Errorf("failed to get user by id %d: %w", id, err)
	}
	return &user, nil
}

func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
	var user models.User
	if err := r.db.WithContext(ctx).Where("email = ?", email).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("user not found")
		}
		return nil, fmt.Errorf("failed to get user by email %s: %w", email, err)
	}
	return &user, nil
}
```

**Line by line:**

- `type UserRepository struct { db *gorm.DB }` — holds the connection handle.
- `NewUserRepository(db *gorm.DB) UserRepository` — constructor. Note: it returns the
  *value* (not a pointer) here; the hero repository (Layer 9) uses an interface — both
  patterns are fine, we'll discuss the difference there.
- `Create`:
  - `r.db.WithContext(ctx).Create(user)` — generates
    `INSERT INTO users (email, password_hash, role, ...) VALUES ($1, $2, $3, ...) RETURNING "id"`.
    GORM writes the auto-generated `ID` and timestamps back into the `user` pointer.
  - `errors.Is(err, gorm.ErrDuplicatedKey)` — detects the unique-index violation
    (SQLSTATE `23505`). We convert it into a *domain* message
    ("user with this email already exists"). The service (Layer 7) compares this exact
    string.
- `GetByID` / `GetByEmail`:
  - `First(&user, id)` → `SELECT * FROM users WHERE id = $1 LIMIT 1`.
  - `First(&user).Where("email = ?", email)` → same, filtered by email.
  - `errors.Is(err, gorm.ErrRecordNotFound)` → translate to the domain message
    `"user not found"` so the service can distinguish "unknown user" from a real
    database failure.
  - `fmt.Errorf("... %w", err)` for anything else — wraps with context, keeps the
    chain.

**Runtime trace — successful create:**

```
POST /register  (body: {"email":"alice@example.com","password":"password123"})
   │
   ▼
UserRepository.Create(ctx, user{Email:"alice@example.com", PasswordHash:"$2a$10$...", Role:"user"})
   │  r.db.WithContext(ctx).Create(user)
   │    → INSERT ... RETURNING id
   │    → Postgres replies: id=1, created_at=<now>, updated_at=<now>
   │    → GORM writes those into the user pointer
   ▼
return nil  (user.ID == 1 now, timestamps filled)
```

**Runtime trace — duplicate create:**

```
POST /register  (same email again)
   │
   ▼
UserRepository.Create(ctx, user{...})
   │  INSERT ... RETURNING id
   │  Postgres: ERROR duplicate key value violates unique constraint
   │            "idx_users_email" (SQLSTATE 23505)
   │  GORM translates (TranslateError: true) → gorm.ErrDuplicatedKey
   │
   ▼
errors.Is(err, gorm.ErrDuplicatedKey) == true
   ▼
return errors.New("user with this email already exists")
```

## ④ Flow Check

```
AuthService ──▶ UserRepository
                  ├─ Create(INSERT ...)
                  ├─ GetByID(SELECT by pk)
                  └─ GetByEmail(SELECT by email)
```

## ⑤ Run it

Not yet callable — it needs the AuthService + handler. Proceed to Layer 7. (You can
sanity-check compilation with `go build ./...` — it should succeed.)

## ⑤ The Gotcha — the string-comparison trap is one layer away

The repository returns `errors.New("user with this email already exists")` and
`errors.New("user not found")` — freshly created values, not shared sentinels. This is
*intentional here*: they cross a package boundary, and Layer 7 compares them by
`err.Error()` string. The classic mistake is to try `errors.Is(err, errors.New(...))`
at the comparison site — that is Bug #4 and is covered in the next layer.

---
# <a id="layer-7"></a>Layer 7 — Auth Service (business logic)

## ① The Objective

Implement the business rules of registration and login: validate input, hash
passwords, check credentials, issue JWTs.

**Success checklist:**
- [ ] The four sentinel errors are declared once, at package level
- [ ] `Create` validates email + password length before hashing
- [ ] `Login` returns the *same* error for unknown email and wrong password
- [ ] You can trace both happy and failure paths (below)

## ② The Theory

The **service** layer is the "brain". Handlers (Layer 8) are dumb HTTP glue; the
service decides what is valid.

- **Sentinel errors** — named, shared error values that are the *contract* between
  service and handler. The handler maps them to HTTP status codes.
- **Anti user-enumeration** — for both "unknown email" and "wrong password", return
  the *same* error. If the API answered differently, an attacker could harvest valid
  email addresses.
- **Sanitize before validate** — trim and lowercase email so
  `" Alice@X.com "` becomes `alice@x.com`.

### Go concepts used in this layer

| Concept | Where it appears | Plain-English meaning |
|---|---|---|
| Package-level `var` block | `var ( ErrInvalidEmail = errors.New(...) )` | Shared values created once when the package loads. All callers compare against the same object. |
| Returning `(string, *models.User, error)` | `Login` | Go's multi-value returns; the handler needs both the token and the user. |
| String helpers | `strings.ToLower(strings.TrimSpace(email))` | `TrimSpace` strips leading/trailing whitespace; `ToLower` normalizes case. Call them *inside-out*: innermost runs first. |
| Standard-library parsing | `mail.ParseAddress(email)` | The `net/mail` package parses an RFC 5322 address; it returns an error for garbage. |
| Defense in depth | `if _, err := mail.ParseAddress(email); err != nil || email == ""` | Two independent checks: the stdlib parser *and* an empty-string guard. Neither alone is enough. |
| `%w` wrapping of non-sentinel errors | `fmt.Errorf("auth_service: ...: %w", err)` | Preserve the chain for logging while returning a distinct error to the caller. |

### Deep Dive — why the same login error for every failure

Consider what happens if the API distinguishes the two cases:

```
Wrong password → "invalid password"
Unknown email  → "no account with this email"
```

An attacker can automate thousands of logins; every "no account with this email"
answer tells them a NEW email they can now target for phishing or credential
stuffing. Returning the identical `ErrInvalidCredentials` for both removes this
information channel. This is a *product decision* encoded in code — the same response
for both failures, forever.

### Deep Dive — order of operations matters

```
1. sanitize (trim/lowercase)  → ~nanoseconds
2. validate email + length    → ~microseconds, pure CPU
3. bcrypt hash                → ~50-100 MILLISECONDS, deliberately slow
4. INSERT into users          → network round-trip
```

Validation *must* come before hashing. If you hash first, an attacker can make your
CPU spin on 100 ms of bcrypt per request with garbage input — a cheap denial of
service. Also: never hash data you already know is invalid.

## ③ The Build

File: `internals/services/auth-service.go`

```go
package services

import (
	"context"
	"errors"
	"fmt"
	"net/mail"
	"strings"

	"github.com/raaj2493/production-systems/heroverse/internals/models"
	"github.com/raaj2493/production-systems/heroverse/internals/repository"
	"github.com/raaj2493/production-systems/heroverse/internals/security"
)

var (
	ErrInvalidEmail       = errors.New("invalid email address format")
	ErrWeakPassword       = errors.New("password must be at least 8 characters long")
	ErrEmailAlreadyExists = errors.New("user with this email already exists")
	ErrInvalidCredentials = errors.New("invalid email or password")
)

type AuthService struct {
	userRepo  repository.UserRepository
	jwtSecret string
}

func NewAuthService(userRepo repository.UserRepository, jwtSecret string) *AuthService {
	return &AuthService{
		userRepo:  userRepo,
		jwtSecret: jwtSecret,
	}
}

func (a *AuthService) Create(ctx context.Context, email string, password string) (*models.User, error) {
	email = strings.ToLower(strings.TrimSpace(email))

	if _, err := mail.ParseAddress(email); err != nil || email == "" {
		return nil, ErrInvalidEmail
	}
	if len(password) < 8 {
		return nil, ErrWeakPassword
	}

	hashedPassword, err := security.HashedPassword(password)
	if err != nil {
		return nil, fmt.Errorf("auth_service: failed to hash password: %w", err)
	}

	user := &models.User{
		Email:        email,
		PasswordHash: hashedPassword,
		Role:         models.RoleUser,
	}

	if err := a.userRepo.Create(ctx, user); err != nil {
		if err.Error() == "user with this email already exists" {
			return nil, ErrEmailAlreadyExists
		}
		return nil, fmt.Errorf("auth_service: failed to register user: %w", err)
	}

	return user, nil
}

func (a *AuthService) Login(ctx context.Context, email, password string) (string, *models.User, error) {
	email = strings.ToLower(strings.TrimSpace(email))

	if email == "" || password == "" {
		return "", nil, ErrInvalidCredentials
	}

	user, err := a.userRepo.GetByEmail(ctx, email)
	if err != nil {
		if err.Error() == "user not found" {
			return "", nil, ErrInvalidCredentials
		}
		return "", nil, fmt.Errorf("auth_service: failed to fetch user for login: %w", err)
	}

	if !security.CheckPasswordHash(password, user.PasswordHash) {
		return "", nil, ErrInvalidCredentials
	}

	token, err := security.GenerateJWT(user.ID, string(user.Role), a.jwtSecret)
	if err != nil {
		return "", nil, fmt.Errorf("auth_service: failed to generate token: %w", err)
	}

	return token, user, nil
}
```

**Line by line:**

- **Sentinel error block** — the four shared errors. They are created once when the
  package is loaded; every `errors.Is` in the handlers compares against these same
  values.
- `type AuthService struct { userRepo repository.UserRepository; jwtSecret string }`
  — the service depends on the repository (value type) and the secret. The secret is
  injected at construction so the service never reads `.env` itself.
- `Create`:
  - `email = strings.ToLower(strings.TrimSpace(email))` — sanitize first.
  - `mail.ParseAddress(email)` — stdlib email validation. The `_, err :=` discards the
    parsed address; we only care whether parsing succeeded.
  - `len(password) < 8` — minimum strength. `len` on a string counts **bytes**; for
    plain ASCII passwords that equals character count (fine here).
  - **Order matters:** cheap validation runs *before* the expensive bcrypt hash.
  - Build `models.User` with `Role: models.RoleUser` (new accounts are always users).
  - `a.userRepo.Create` — persist. On error: compare `err.Error()` to the repo's
    message to map to `ErrEmailAlreadyExists`. Everything else → wrapped internal
    error. **This is the string comparison that fixes Bug #4.**
- `Login`:
  - Both empty-input and wrong-password and unknown-email return
    `ErrInvalidCredentials` — the anti-enumeration guarantee.
  - `security.CheckPasswordHash` — compare provided password against stored hash.
  - `security.GenerateJWT(user.ID, string(user.Role), a.jwtSecret)` — build token.
    `string(user.Role)` converts the `UserRole` named type to plain `string` for the
    JWT payload.
  - Returns `(token, user, nil)` — the handler needs both.

**Runtime trace — register, happy path:**

```
POST /api/v1/auth/register  {"email":"Alice@Example.com ","password":"password123"}
   │
   ▼
AuthService.Create(ctx, "Alice@Example.com ", "password123")
   │  email = strings.TrimSpace → "Alice@Example.com"
   │        = strings.ToLower   → "alice@example.com"
   │  mail.ParseAddress("alice@example.com") → ok
   │  len("password123") = 12 ≥ 8 → ok
   │  security.HashedPassword("password123")
   │    → "$2a$10$8tQ8bM6wjKvP1xYpN4u1E.abc..."  (≈60ms)
   │  user = {Email:"alice@example.com", PasswordHash:"$2a$10$...", Role:"user"}
   │  userRepo.Create(ctx, user) → INSERT → user.ID = 1
   ▼
return user, nil
```

**Runtime trace — register, duplicate email:**

```
POST /api/v1/auth/register  {"email":"alice@example.com","password":"password123"}
   │
   ▼
...same path up to userRepo.Create...
   │  repo returns errors.New("user with this email already exists")
   │
   ▼
err.Error() == "user with this email already exists"  → true
   ▼
return nil, ErrEmailAlreadyExists
```

**Runtime trace — login, happy path:**

```
POST /api/v1/auth/login  {"email":"alice@example.com","password":"password123"}
   │
   ▼
AuthService.Login(ctx, "alice@example.com", "password123")
   │  userRepo.GetByEmail → SELECT ... WHERE email=$1 LIMIT 1
   │    → user{ID:1, PasswordHash:"$2a$10$..."}
   │  CheckPasswordHash("password123", "$2a$10$...") → true
   │  GenerateJWT(1, "user", secret) → "eyJhbGci..."
   ▼
return "eyJhbGci...", user, nil
```

**Runtime trace — login, wrong password AND unknown email:**

```
POST /api/v1/auth/login  {"email":"alice@example.com","password":"wrongpass"}
   │
   ▼
userRepo.GetByEmail → found
CheckPasswordHash("wrongpass", hash) → false
   ▼
return "", nil, ErrInvalidCredentials

POST /api/v1/auth/login  {"email":"nobody@example.com","password":"anything1"}
   │
   ▼
userRepo.GetByEmail → "user not found"
err.Error() == "user not found" → true
   ▼
return "", nil, ErrInvalidCredentials   ← SAME error as above
```

## ④ Flow Check

```
AuthHandler.Register ──▶ AuthService.Create ──▶ UserRepository.Create ──▶ INSERT
AuthHandler.Login    ──▶ AuthService.Login  ──▶ UserRepository.GetByEmail ──▶ SELECT
                                                ├─ CheckPasswordHash
                                                └─ GenerateJWT → token
```

## ⑤ Run it

Not yet callable — the handler comes next. Compile-check:

```bash
go build ./...
```

## ⑤ The Gotcha — Bug #4: `errors.Is(err, errors.New("..."))` is always false

The original code compared repository errors like this:

```go
if errors.Is(err, errors.New("user with this email already exists")) {
```

`errors.New` creates a **brand-new error value on every call**. Two distinct values are
never equal — the branch was dead code, and duplicate registration returned `500`.
Fix: compare `err.Error()` (a string) against the exact message the repository
produces. Rule: *sentinel errors must be shared named variables; if you can't share
them, compare strings.*

**How you would debug it:** register the same email twice. Expected `400`, got `500`.
Read the server log — the wrapped message says `failed to register user: user with this
email already exists`, which tells you the repo *detected* the duplicate but the
handler's mapping never fired. That is the signature of a dead `errors.Is` branch.

---
# <a id="layer-8"></a>Layer 8 — Response helpers & Auth Handler

## ① The Objective

Expose `POST /api/v1/auth/register` and `POST /api/v1/auth/login` over HTTP, with a
consistent response envelope and consistent error mapping.

**Success checklist:**
- [ ] `/register` returns `201` with `{"data":{...}}` on success
- [ ] `/register` returns `400` for invalid email / weak password / duplicate
- [ ] `/login` returns `200` with `{"data":{"token":...,"user":{...}}}`
- [ ] `/login` returns `401` for bad credentials
- [ ] The password hash never appears in any response

## ② The Theory

- **Response envelope** — every success is `{"data": ...}`. Clients write one generic
  unwrapper. Lists add `"meta"`.
- **Error envelope** — every error is `{"code": "...", "message": "..."}`. `code` is
  stable and machine-readable; `message` is human-readable.
- **Status codes** — `400` = client sent something invalid; `401` = unauthenticated;
  `403` = authenticated but not allowed; `404` = not found; `500` = our fault. We never
  leak internal error details to clients — the real error goes to the server log.

### Go concepts used in this layer

| Concept | Where it appears | Plain-English meaning |
|---|---|---|
| Handler as method | `func (h *AuthHandler) Register(c *gin.Context)` | Methods let the handler hold its `*AuthService` dependency. Gin calls methods and functions identically. |
| Struct as request DTO | `type authPayload struct {...}` | A small struct describing the expected JSON body. DTO = data transfer object. |
| `ShouldBindJSON` | `c.ShouldBindJSON(&body)` | Uses reflection (Layer 2!) to map JSON fields onto struct fields via `json:"..."` tags. Returns an error if the body is malformed. |
| `switch` on multiple `errors.Is` | `errors.Is(err, a) || errors.Is(err, b)` | A boolean `switch` with no expression — cleanest form for "map many sentinels to one status". |
| `http.StatusX` constants | `http.StatusBadRequest` | Named constants instead of magic numbers (`400`). Both compile to the same int. |
| Context flow | `c.Request.Context()` | The HTTP request's context — the same one `WithContext(ctx)` used at Layer 6. Cancelling the client request cancels the DB query. |

### Deep Dive — the response contract

Every response is one of exactly two shapes:

```json
// success
{ "data": { ... } }

// error
{ "code": "SOME_CODE", "message": "human readable" }
```

Why an envelope at all? Three reasons:

1. **Versioning** — you can add a `"meta"` field or a `"version"` later without
   breaking clients that read `data`.
2. **Consistency** — one unwrapper client-side: `resp.data`, `resp.code`.
3. **Non-JSON guarantees** — a client can reliably detect the error shape by the
   presence of `code`.

The error `code` strings are a *second contract*: clients branch on `"UNAUTHORIZED"`
to trigger a re-login flow, on `"INVALID_INPUT"` to show a form error. Never send a
free-form message and expect clients to parse it.

## ③ The Build

### Step 1 — Response helpers

File: `internals/handlers/response.go`

```go
package handlers

import (
	"github.com/gin-gonic/gin"
)

type PaginationMeta struct {
	Page       int   `json:"page"`
	Limit      int   `json:"limit"`
	Total      int64 `json:"total"`
	TotalPages int   `json:"total_pages"`
}

func RespondWithData(c *gin.Context, status int, data any) {
	c.JSON(status, gin.H{
		"data": data,
	})
}

func RespondWithPagination(c *gin.Context, status int, data any, meta PaginationMeta) {
	c.JSON(status, gin.H{
		"data": data,
		"meta": meta,
	})
}
```

**Line by line:**

- `PaginationMeta` — the pagination contract (used by the hero list in Layer 9/11).
  `Total int64` matches what GORM's `Count` writes.
- `RespondWithData(c, status, data)` — wraps any payload in `{"data": ...}`.
- `RespondWithPagination(c, status, data, meta)` — wraps list payloads in
  `{"data": ..., "meta": ...}`.

### Step 2 — Central error mapper

File: `internals/handlers/errors.go`

```go
package handlers

import (
	"errors"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/raaj2493/production-systems/heroverse/internals/services"
)

type APIError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func RespondWithError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, services.ErrHeroNotFound):
		c.JSON(http.StatusNotFound, APIError{
			Code:    "HERO_NOT_FOUND",
			Message: "the requested hero was not found",
		})

	case errors.Is(err, services.ErrEmptyName),
		errors.Is(err, services.ErrEmptyPower),
		errors.Is(err, services.ErrInvalidHeroID),
		errors.Is(err, services.ErrNilHeroData),
		errors.Is(err, services.ErrInvalidPage),
		errors.Is(err, services.ErrInvalidLimit),
		errors.Is(err, services.ErrInvalidSortBy),
		errors.Is(err, services.ErrInvalidOrder):
		c.JSON(http.StatusBadRequest, APIError{
			Code:    "INVALID_INPUT",
			Message: err.Error(),
		})

	default:
		log.Printf("[ERROR] Internal failure: %v", err)
		c.JSON(http.StatusInternalServerError, APIError{
			Code:    "INTERNAL_ERROR",
			Message: "an unexpected internal error occurred",
		})
	}
}
```

**Line by line:**

- `type APIError struct { Code, Message string }` — the error envelope.
- `switch { ... }` — a type-free switch over boolean cases. Each `case` is evaluated
  top to bottom; the first true one wins.
- `errors.Is(err, services.ErrHeroNotFound)` → `404 HERO_NOT_FOUND`. This sentinel is
  defined in Layer 10; the mapper is written before the sentinel exists in this
  tutorial, so it will not compile until Layer 10 — that is fine, proceed in order.
- The grouped `400` cases — every validation sentinel maps to `400 INVALID_INPUT`
  with the sentinel's own message.
- `default:` — the safety net. Log the *real* error server-side, return a generic
  `500` to the client. **We never echo internal errors.**

### Step 3 — Auth handler

File: `internals/handlers/auth-handler.go`

```go
package handlers

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/raaj2493/production-systems/heroverse/internals/services"
)

type AuthHandler struct {
	authService *services.AuthService
}

func NewAuthHandler(authService *services.AuthService) *AuthHandler {
	return &AuthHandler{
		authService: authService,
	}
}

type authPayload struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (h *AuthHandler) Register(c *gin.Context) {
	var body authPayload
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, APIError{
			Code:    "INVALID_INPUT",
			Message: "invalid request body",
		})
		return
	}

	user, err := h.authService.Create(c.Request.Context(), body.Email, body.Password)
	if err != nil {
		if errors.Is(err, services.ErrInvalidEmail) ||
			errors.Is(err, services.ErrWeakPassword) ||
			errors.Is(err, services.ErrEmailAlreadyExists) {
			c.JSON(http.StatusBadRequest, APIError{
				Code:    "INVALID_INPUT",
				Message: err.Error(),
			})
			return
		}
		RespondWithError(c, err)
		return
	}

	RespondWithData(c, http.StatusCreated, user)
}

func (h *AuthHandler) Login(c *gin.Context) {
	var body authPayload
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, APIError{
			Code:    "INVALID_INPUT",
			Message: "invalid request body",
		})
		return
	}

	token, user, err := h.authService.Login(c.Request.Context(), body.Email, body.Password)
	if err != nil {
		if errors.Is(err, services.ErrInvalidCredentials) {
			c.JSON(http.StatusUnauthorized, APIError{
				Code:    "UNAUTHORIZED",
				Message: services.ErrInvalidCredentials.Error(),
			})
			return
		}
		RespondWithError(c, err)
		return
	}

	RespondWithData(c, http.StatusOK, gin.H{
		"token": token,
		"user":  user,
	})
}
```

**Line by line:**

- `type authPayload struct { Email, Password string }` — the request body shape. The
  `json:"email"` tags bind the wire names; a body sending `{"email":"...","password":"..."}`
  maps onto it. Unknown fields in the body are ignored by default.
- `c.ShouldBindJSON(&body)` — parses JSON into the struct. On failure → `400`. We
  pass a *pointer* so the function can fill the struct. A missing `Content-Type` or
  malformed JSON (e.g. `{"email": 123}`) lands here.
- `h.authService.Create(c.Request.Context(), ...)` — note `c.Request.Context()`:
  the HTTP request context flows into the service and repository.
- The `errors.Is` checks map the auth sentinels to `400`. Everything else →
  `RespondWithError`.
- `RespondWithData(c, http.StatusCreated, user)` — `201 Created` with the user
  (password hash hidden by `json:"-"` from Layer 4).
- `Login` — `401 UNAUTHORIZED` for bad credentials (the anti-enumeration error from
  Layer 7), else `200` with `{"token": ..., "user": ...}`.

### Step 4 — Wire into router and main

Add the auth routes to the router and wire the dependencies in `main.go`:

```go
userRepo := repository.NewUserRepository(db)
authService := services.NewAuthService(userRepo, cfg.JWT.Secret)
authHandler := handlers.NewAuthHandler(authService)
```

Then pass `authHandler` to `router.SetupRouter(...)`.

**The full dependency graph at this point:**

```
db ──▶ userRepo ──▶ authService ──▶ authHandler ──▶ router ──▶ http.Server
          (Layer 6)   (Layer 7)      (this layer)    (Layer 1)
```

## ④ Flow Check

```
POST /api/v1/auth/register
   │
   ▼
AuthHandler.Register
   ├─ ShouldBindJSON  → 400 if malformed
   ├─ AuthService.Create → ErrInvalidEmail/WeakPassword/Exists → 400
   └─ 201 {"data":{user}}
```

**Walk two real requests through the layer:**

**Request 1 — successful registration:**

```
Client                          AuthHandler.Register
  │  POST /api/v1/auth/register      │
  │  Content-Type: application/json  │
  │  {"email":"alice@example.com",   │
  │   "password":"password123"}       │
  ├──────────────────────────────────▶│
  │                                   │ ShouldBindJSON → authPayload{email, password}
  │                                   │ service.Create → INSERT → user{ID:1, ...}
  │                                   │ RespondWithData(201, user)
  │  201                              │
  │  {"data":{"id":1,"email":         │
  │   "alice@example.com",            │
  │   "role":"user",                  │
  │   "created_at":"...",             │
  │   "updated_at":"..."}}            │
  ◀───────────────────────────────────│
```

**Request 2 — wrong password:**

```
Client                          AuthHandler.Login
  │  POST /api/v1/auth/login          │
  │  {"email":"alice@example.com",   │
  │   "password":"wrongpass"}         │
  ├──────────────────────────────────▶│
  │                                   │ service.Login → ErrInvalidCredentials
  │                                   │ errors.Is(ErrInvalidCredentials) → true
  │                                   │ c.JSON(401, APIError{...})
  │  401                              │
  │  {"code":"UNAUTHORIZED",          │
  │   "message":"invalid email or     │
  │   password"}                      │
  ◀───────────────────────────────────│
```

## ⑤ Run it

```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"password123"}'
# 201 {"data":{"id":1,"email":"alice@example.com","role":"user","created_at":"...","updated_at":"..."}}

# duplicate → 400
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"password123"}'
# 400 {"code":"INVALID_INPUT","message":"user with this email already exists"}

# login → 200 with token
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"password123"}'
# 200 {"data":{"token":"eyJhbGci...","user":{...}}}

# wrong password / unknown user → 401 (identical response)
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"wrongpass"}'
# 401 {"code":"UNAUTHORIZED","message":"invalid email or password"}
```

**Troubleshooting:**

| Symptom | Cause | Fix |
|---|---|---|
| `500 INTERNAL_ERROR` on register | Dead `errors.Is` branch (Bug #4) or a wrapped error reaching `default` | Check the server log for the real cause; confirm `err.Error()` comparison in the service |
| `400 invalid request body` for a valid JSON | Wrong `Content-Type` header, or field names not matching tags | Use `-H "Content-Type: application/json"`; check tag names |
| Panic: nil pointer on register/login | Handler created with `&handlers.AuthHandler{}` (Bug #1) | Wire the chain: `userRepo → authService → authHandler` |
| Login returns 500 | `GetByEmail` returned a non-`user not found` error (e.g. DB down) | Check the server log; verify Postgres is up |

## ⑤ The Gotcha — Bug #1: `AuthHandler` created with a nil service

`main.go` originally passed `&handlers.AuthHandler{}` to the router — an empty struct
with a nil `authService`. Any call to Register/Login panicked (nil pointer
dereference) with a stack trace like `runtime error: invalid memory address or nil
pointer dereference`. Fix: construct the full chain `userRepo → authService →
authHandler`.

**Why this is sneaky:** the app *starts* fine — Gin happily registers handlers whose
dependencies are nil. The crash happens only when a request arrives. That is why this
class of wiring bug is caught by *testing endpoints*, never by `go build`.

---
# <a id="layer-9"></a>Layer 9 — Hero Repository

## ① The Objective

Full CRUD for heroes, including a `GetAll` with filtering, search, sorting, and
pagination.

**Success checklist:**
- [ ] `HeroRepository` is an *interface*; `gormHeroRepository` is its implementation
- [ ] You can write the SQL `GetAll` produces for a given filter (below)
- [ ] You understand `ILIKE '%term%'`, count-before-fetch, and the `id ASC` tie-breaker
- [ ] `go build ./...` passes

## ② The Theory

- **Interface vs concrete type** — here we declare a `HeroRepository` **interface**
  and return a concrete `gormHeroRepository`. The service depends on the interface,
  so tests can inject a fake. (The user repository used a concrete type — both are
  valid; the interface is the more testable pattern.)
- **`ILIKE '%term%'`** — Postgres case-insensitive contains-match.
- **Count before fetch** — count the *filtered* rows first (for `total`), then apply
  Order/Limit/Offset for the page. Both use the same `WHERE`.
- **Deterministic ordering** — `ORDER BY col dir, id ASC`. The `id ASC` tie-breaker
  prevents rows appearing on two pages.
- **Parameterized `?` queries** — SQL-injection safe.

### Go concepts used in this layer

| Concept | Where it appears | Plain-English meaning |
|---|---|---|
| Interface declaration | `type HeroRepository interface { ... }` | A *contract*: "anything with these exact methods satisfies me". No implementation here — just the signature list. |
| Interface satisfaction | `&gormHeroRepository{...}` returned as `HeroRepository` | Go is *implicit*: `gormHeroRepository` satisfies `HeroRepository` if it has all five methods — no `implements` keyword. If a method is missing, the `return &gormHeroRepository{...}` line fails to compile. |
| Unexported type | `type gormHeroRepository struct` | Lowercase name = only the `repository` package can name this type. Outsiders get it *as the interface*. |
| Constructor returning interface | `func NewHeroRepository(db *gorm.DB) HeroRepository` | The idiomatic way to return an interface: callers depend on the contract, not the concrete type. |
| String builder for SQL order | `fmt.Sprintf("%s %s, id ASC", sortBy, orderDir)` | Building the ORDER BY clause. Safe here because Layer 10 whitelists `sortBy`/`orderDir` before this runs. |
| Function chaining | `query.Where(...).Or(...)` | GORM's builder pattern. Each call returns the query object, mutating it in place. |

### Deep Dive — the SQL `GetAll` produces

Base state (no filters):

```sql
SELECT * FROM "heroes" WHERE "heroes"."deleted_at" IS NULL
ORDER BY id asc, id ASC LIMIT 20 OFFSET 0;
-- count: SELECT count(*) FROM "heroes" WHERE "heroes"."deleted_at" IS NULL;
```

With `?name=man`:

```sql
SELECT * FROM "heroes"
WHERE name ILIKE '%man%'
ORDER BY id asc, id ASC LIMIT 20 OFFSET 0;
```

With `?search=light&sort_by=name&order=desc&page=2&limit=5`:

```sql
SELECT count(*) FROM "heroes"
WHERE (name ILIKE '%light%' OR power ILIKE '%light%');

SELECT * FROM "heroes"
WHERE (name ILIKE '%light%' OR power ILIKE '%light%')
ORDER BY name desc, id ASC LIMIT 5 OFFSET 5;
```

Key details:

- **`ILIKE`** — case-insensitive; `'%man%'` matches "Man", "MAN", "superman". The
  `%` is a wildcard: `%term%` = anything, then the term, then anything.
- **Count runs first** on the same `WHERE` — so `total` reflects the filters, and
  `total_pages` math in the handler is correct.
- **`ORDER BY name desc, id ASC`** — if two heroes both named "Iron Man", the `id ASC`
  decides their relative order. Without it, rows can jump between pages as you page
  through (nondeterministic pagination).
- **`LIMIT 5 OFFSET 5`** — page 2 of limit 5 skips the first 5 rows. `OFFSET` is
  computed by the service as `(page-1) * limit` (Layer 10).

## ③ The Build

File: `internals/repository/hero-repository.go`

```go
package repository

import (
	"context"
	"fmt"
	"strings"

	"gorm.io/gorm"

	"github.com/raaj2493/production-systems/heroverse/internals/models"
)

type HeroFilter struct {
	Name   string
	Power  string
	Search string
	SortBy string
	Order  string
}

type HeroRepository interface {
	Create(ctx context.Context, hero *models.Hero) error
	GetByID(ctx context.Context, id uint) (*models.Hero, error)
	GetAll(ctx context.Context, filter HeroFilter, offset int, limit int) ([]models.Hero, int64, error)
	Update(ctx context.Context, hero *models.Hero) error
	Delete(ctx context.Context, id uint) error
}

type gormHeroRepository struct {
	db *gorm.DB
}

func NewHeroRepository(db *gorm.DB) HeroRepository {
	return &gormHeroRepository{
		db: db,
	}
}

func (r *gormHeroRepository) Create(ctx context.Context, hero *models.Hero) error {
	if err := r.db.WithContext(ctx).Create(hero).Error; err != nil {
		return fmt.Errorf("failed to create hero: %w", err)
	}
	return nil
}

func (r *gormHeroRepository) GetByID(ctx context.Context, id uint) (*models.Hero, error) {
	var hero models.Hero
	if err := r.db.WithContext(ctx).First(&hero, id).Error; err != nil {
		return nil, fmt.Errorf("failed to get hero by id %d: %w", id, err)
	}
	return &hero, nil
}

func (r *gormHeroRepository) GetAll(ctx context.Context, filter HeroFilter, offset int, limit int) ([]models.Hero, int64, error) {
	var heroes []models.Hero
	var total int64

	query := r.db.WithContext(ctx).Model(&models.Hero{})

	if filter.Name != "" {
		query = query.Where("name ILIKE ?", "%"+filter.Name+"%")
	}
	if filter.Power != "" {
		query = query.Where("power ILIKE ?", "%"+filter.Power+"%")
	}
	if filter.Search != "" {
		searchTerm := "%" + filter.Search + "%"
		query = query.Where(
			r.db.Where("name ILIKE ?", searchTerm).Or("power ILIKE ?", searchTerm),
		)
	}

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("failed to count heroes: %w", err)
	}

	var orderClause string
	sortBy := strings.ToLower(filter.SortBy)
	orderDir := strings.ToUpper(filter.Order)

	if sortBy == "id" {
		orderClause = fmt.Sprintf("id %s", orderDir)
	} else {
		orderClause = fmt.Sprintf("%s %s, id ASC", sortBy, orderDir)
	}

	if err := query.
		Order(orderClause).
		Limit(limit).
		Offset(offset).
		Find(&heroes).Error; err != nil {
		return nil, 0, fmt.Errorf("failed to fetch heroes: %w", err)
	}

	return heroes, total, nil
}

func (r *gormHeroRepository) Update(ctx context.Context, hero *models.Hero) error {
	if err := r.db.WithContext(ctx).Save(hero).Error; err != nil {
		return fmt.Errorf("failed to update hero %d: %w", hero.ID, err)
	}
	return nil
}

func (r *gormHeroRepository) Delete(ctx context.Context, id uint) error {
	if err := r.db.WithContext(ctx).Delete(&models.Hero{}, id).Error; err != nil {
		return fmt.Errorf("failed to delete hero %d: %w", id, err)
	}
	return nil
}
```

**Line by line:**

- `HeroFilter` — the filter/sort input bag passed from the handler. Plain strings,
  no tags — it is an internal query description, not a wire format.
- The **interface** — exactly the five operations the service needs. Adding a method
  here forces the implementation (and any test fake) to provide it — the compiler
  enforces the contract.
- `gormHeroRepository` — the unexported concrete implementation (nobody outside this
  package must use it directly). Unexported = package-private.
- `GetAll`:
  - `query := r.db.WithContext(ctx).Model(&models.Hero{})` — base query. `Model`
    tells GORM the target table (`heroes`) so `Count` and `Find` agree.
  - `Where(...).Where(...)` — ANDs the name/power filters.
  - The inner `.Where(...).Or(...)` — ORs name/power for the global search. The
    grouping matters: `name ILIKE '%x%' AND (name ILIKE '%y%' OR power ILIKE '%y%')`
    — the `Or` must be grouped with parens, which GORM does because we pass the
    `r.db.Where(...).Or(...)` *as a sub-expression*.
  - `query.Count(&total)` — filtered count (no Order/Limit/Offset yet). `Count` writes
    into the `*int64`.
  - Order clause — `sortBy`/`orderDir` are validated upstream (Layer 10), so building
    the string here is safe; the `, id ASC` tie-breaker keeps ordering deterministic.
  - `.Order(...).Limit(...).Offset(...).Find(&heroes)` — fetch the page.
- `Update` — `Save(hero)` issues an `UPDATE` for every field of the record. We load
  the existing hero in the service first so `Save` never blanks fields.
- `Delete` — `Delete(&models.Hero{}, id)` removes the row (hard delete because `Hero`
  has no `DeletedAt`).

**Runtime trace — filtered, sorted, paginated list:**

```
GET /api/v1/heroes?name=man&sort_by=name&page=2&limit=5
   │
   ▼
GetAll(ctx, filter{Name:"man", SortBy:"name", Order:"asc"}, offset:5, limit:5)
   │  query = Model(&Hero{})
   │  filter.Name != "" → query.Where("name ILIKE ?", "%man%")
   │  Count(&total) → SELECT count(*) ... WHERE name ILIKE '%man%' → 7
   │  sortBy="name", orderDir="ASC"
   │  orderClause = "name ASC, id ASC"
   │  Find(&heroes) → SELECT * ... ORDER BY name ASC, id ASC LIMIT 5 OFFSET 5
   ▼
return [hero6..hero10-ish], total=7, nil
```

## ④ Flow Check

```
HeroService ──▶ HeroRepository (interface)
                  └─ gormHeroRepository ──▶ PostgreSQL
```

## ⑤ Run it

Not yet callable — the service and handlers come next. Compile-check:

```bash
go build ./...
```

**Verify SQL by hand:** if you want to see exactly what GORM sends, you can enable
SQL logging by passing `&gorm.Config{TranslateError: true, Logger: logger.Default.LogMode(logger.Info)}`
temporarily — every statement prints to stdout. This is the single most useful
debugging trick for GORM.

## ⑤ The Gotcha — layering discipline

The repository returns **raw GORM errors wrapped in `fmt.Errorf`** — it deliberately
does *not* translate `gorm.ErrRecordNotFound` into `ErrHeroNotFound`. That translation
belongs to the service (Layer 10). Why the split? The repository's job is "talk to the
database and report what happened". Deciding "this is a 404 for the HTTP client" is a
*business* decision, so it lives one layer up. Mixing them makes the repository
unreusable outside HTTP (e.g. from a batch job that wants different handling).

---
# <a id="layer-10"></a>Layer 10 — Hero Service

## ① The Objective

Business rules for heroes: validate input, translate GORM errors into domain errors,
validate sort/order against a whitelist, and paginate.

**Success checklist:**
- [ ] The nine hero sentinel errors are declared once, at package level
- [ ] `allowedSortFields` is a map used as a set
- [ ] `GetByID`, `Update`, `Delete` translate `gorm.ErrRecordNotFound` → `ErrHeroNotFound`
- [ ] You understand why this fixes "missing hero returns 500" (Bug #8)

## ② The Theory

- **Validation order** — trim first, then check. `"  "` (whitespace only) must be
  treated as empty.
- **Sort whitelist** — `sort_by` and `order` become SQL fragments in Layer 9. Only
  known values are allowed, which is both validation *and* an injection defense.
- **`offset := (page-1) * limit`** — converts a 1-based page number to SQL offset.
- **GORM error translation** — `errors.Is(err, gorm.ErrRecordNotFound)` → the domain
  sentinel `ErrHeroNotFound`, which the handler maps to `404`. This is what fixes
  "missing hero returns 500".

### Go concepts used in this layer

| Concept | Where it appears | Plain-English meaning |
|---|---|---|
| Map as a set | `var allowedSortFields = map[string]bool{...}` | Go has no `set` type. A map where only the *keys* matter, values all `true`. `allowedSortFields[x]` is `true` for known fields, `false` for unknown. |
| Package-level var | `var allowedSortFields = ...` | Built once at load time; shared read-only by all calls. |
| `errors.Is(err, gorm.ErrRecordNotFound)` | in `GetByID`/`Update`/`Delete` | The key translation. It works because the repository wrapped the GORM error with `%w` (Layer 9), preserving the chain. |
| Multiple-return + nil | `return nil, ErrHeroNotFound` | When returning an error, return zero values for the others (`nil` here) so callers can't use garbage. |
| Integer arithmetic | `offset := (page - 1) * limit` | 1-based page → 0-based offset. Page 1 → 0, page 2 → limit, page 3 → 2×limit. |
| Existence-then-mutate | `Update`/`Delete` | Read the record first (authorize later in Layer 11), then act. Two steps, two queries, one guarantee. |

### Deep Dive — validation as a security control

`sort_by` and `order` are not just validated for politeness — they become raw SQL:

```go
orderClause = fmt.Sprintf("%s %s, id ASC", sortBy, orderDir)  // Layer 9
```

If an attacker could pass `sort_by="id; DROP TABLE heroes; --"`, the string would
become `id; DROP TABLE heroes; -- asc, id ASC` — SQL injection. The whitelist makes
that impossible: only `id`, `name`, `power`, `created_at` pass, and only `asc`/`desc`
pass. The repository *trusts* the service; the service *trusts nothing*.

This is the correct order of defense: validate at the boundary (handler/service) so
the layer that builds SQL never has to handle hostile input.

### Deep Dive — the error translation chain

Trace what happens for a missing hero, and why the fix works:

```
GET /heroes/999
   │
   ▼
HeroRepository.GetByID:  First(&hero, 999) → gorm.ErrRecordNotFound
   │  wrapped: fmt.Errorf("failed to get hero by id 999: %w", gorm.ErrRecordNotFound)
   ▼
HeroService.GetByID:
   │  errors.Is(err, gorm.ErrRecordNotFound)  ← walks the %w chain → true
   ▼
return nil, ErrHeroNotFound
   │
   ▼
Handler: RespondWithError → errors.Is(ErrHeroNotFound) → 404 HERO_NOT_FOUND
```

Without the translation, `ErrHeroNotFound` is never produced, `errors.Is(ErrHeroNotFound)`
is false, and the handler's `default` case returns `500` — Bug #8.

## ③ The Build

File: `internals/services/hero-service.go`

```go
package services

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"gorm.io/gorm"

	"github.com/raaj2493/production-systems/heroverse/internals/models"
	"github.com/raaj2493/production-systems/heroverse/internals/repository"
)

var (
	ErrHeroNotFound  = errors.New("hero not found")
	ErrInvalidHeroID = errors.New("hero id must be greater than zero")
	ErrEmptyName     = errors.New("hero name cannot be empty")
	ErrEmptyPower    = errors.New("hero power cannot be empty")
	ErrNilHeroData   = errors.New("hero data cannot be nil")
	ErrInvalidPage   = errors.New("page must be an integer greater than 0")
	ErrInvalidLimit  = errors.New("limit must be an integer between 1 and 100")
	ErrInvalidSortBy = errors.New("invalid sort_by field: allowed fields are id, name, power, created_at")
	ErrInvalidOrder  = errors.New("invalid order direction: allowed values are asc, desc")
)

type HeroService struct {
	repo repository.HeroRepository
}

func NewHeroService(repo repository.HeroRepository) *HeroService {
	return &HeroService{
		repo: repo,
	}
}

var allowedSortFields = map[string]bool{
	"id":         true,
	"name":       true,
	"power":      true,
	"created_at": true,
}

func (s *HeroService) Create(ctx context.Context, hero *models.Hero) error {
	if hero == nil {
		return ErrNilHeroData
	}

	hero.Name = strings.TrimSpace(hero.Name)
	hero.Power = strings.TrimSpace(hero.Power)

	if hero.Name == "" {
		return ErrEmptyName
	}
	if hero.Power == "" {
		return ErrEmptyPower
	}

	if err := s.repo.Create(ctx, hero); err != nil {
		return fmt.Errorf("service: failed to create hero: %w", err)
	}

	return nil
}

func (s *HeroService) GetByID(ctx context.Context, id uint) (*models.Hero, error) {
	if id == 0 {
		return nil, ErrInvalidHeroID
	}

	hero, err := s.repo.GetByID(ctx, id)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrHeroNotFound
		}
		return nil, fmt.Errorf("service: failed to fetch hero: %w", err)
	}

	return hero, nil
}

func (s *HeroService) GetAll(ctx context.Context, filter repository.HeroFilter, page int, limit int) ([]models.Hero, int64, error) {
	filter.Name = strings.TrimSpace(filter.Name)
	filter.Power = strings.TrimSpace(filter.Power)
	filter.Search = strings.TrimSpace(filter.Search)

	if filter.SortBy == "" {
		filter.SortBy = "id"
	} else {
		filter.SortBy = strings.ToLower(strings.TrimSpace(filter.SortBy))
		if !allowedSortFields[filter.SortBy] {
			return nil, 0, ErrInvalidSortBy
		}
	}

	if filter.Order == "" {
		filter.Order = "asc"
	} else {
		filter.Order = strings.ToLower(strings.TrimSpace(filter.Order))
		if filter.Order != "asc" && filter.Order != "desc" {
			return nil, 0, ErrInvalidOrder
		}
	}

	offset := (page - 1) * limit

	heroes, total, err := s.repo.GetAll(ctx, filter, offset, limit)
	if err != nil {
		return nil, 0, fmt.Errorf("service: failed to list heroes: %w", err)
	}

	return heroes, total, nil
}

func (s *HeroService) Update(ctx context.Context, hero *models.Hero) error {
	if hero == nil {
		return ErrNilHeroData
	}
	if hero.ID == 0 {
		return ErrInvalidHeroID
	}

	hero.Name = strings.TrimSpace(hero.Name)
	hero.Power = strings.TrimSpace(hero.Power)

	if hero.Name == "" {
		return ErrEmptyName
	}
	if hero.Power == "" {
		return ErrEmptyPower
	}

	_, err := s.repo.GetByID(ctx, hero.ID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrHeroNotFound
		}
		return fmt.Errorf("service: hero not found for update: %w", err)
	}

	if err := s.repo.Update(ctx, hero); err != nil {
		return fmt.Errorf("service: failed to update hero: %w", err)
	}

	return nil
}

func (s *HeroService) Delete(ctx context.Context, id uint) error {
	if id == 0 {
		return ErrInvalidHeroID
	}

	_, err := s.repo.GetByID(ctx, id)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrHeroNotFound
		}
		return fmt.Errorf("service: hero not found for deletion: %w", err)
	}

	if err := s.repo.Delete(ctx, id); err != nil {
		return fmt.Errorf("service: failed to delete hero: %w", err)
	}

	return nil
}
```

**Line by line:**

- **The nine sentinel errors** — the full service→handler vocabulary for heroes. Each
  maps to exactly one HTTP status via `RespondWithError` (Layer 8). Notice the messages
  are written for a human (they appear in `400` responses).
- `allowedSortFields` — a **map used as a set**; `allowedSortFields[x]` is `true` only
  for known columns. Reading a missing key yields `false` — perfect for `if !allowedSortFields[filter.SortBy]`.
- `Create` — nil check, trim, empty checks, then delegate to the repo. The nil check
  protects against a caller passing `(*models.Hero)(nil)`.
- `GetByID` — `id == 0` is invalid (a `400`); then translate
  `gorm.ErrRecordNotFound` → `ErrHeroNotFound` (the `404`).
- `GetAll` — trim filters; default `sort_by=id`, `order=asc`; validate both against
  the whitelist; compute `offset`; delegate. Defaults mean `GET /heroes` works with no
  query params at all.
- `Update` — nil/ID checks, trim, empty checks, existence check (translating to
  `ErrHeroNotFound`), then update.
- `Delete` — ID check, existence check (→ `ErrHeroNotFound`), then delete. The
  existence check also feeds Layer 11's ownership check (the handler reads the hero
  before authorizing).

**Runtime trace — validation paths:**

```
POST /heroes  {"name":"Iron Man","power":"Flight"}        → Create → repo.Create → 201
POST /heroes  {"name":"  ","power":"Flight"}              → trim → name=="" → ErrEmptyName → 400
POST /heroes  {}                                          → hero{ID:0,Name:"",Power:""} → ErrEmptyName → 400
POST /heroes  {"name":"x","power":"y","user_id":99}       → UserID overwritten in handler → mass-assignment blocked
GET  /heroes/999                                          → GetByID → gorm.ErrRecordNotFound → ErrHeroNotFound → 404
GET  /heroes?sort_by=email&order=asc                      → not in whitelist → ErrInvalidSortBy → 400
GET  /heroes?order=sideways                               → not asc/desc → ErrInvalidOrder → 400
GET  /heroes?page=-1                                      → handler parses → ErrInvalidPage → 400 (Layer 11)
GET  /heroes?limit=1000                                   → handler parses → ErrInvalidLimit → 400 (Layer 11)
```

## ④ Flow Check

```
HeroHandler ──▶ HeroService
                 ├─ validate
                 ├─ translate gorm.ErrRecordNotFound → ErrHeroNotFound
                 └─ delegate to HeroRepository
```

## ⑤ Run it

Not yet callable — the hero handler comes next. Compile-check:

```bash
go build ./...
```

## ⑤ The Gotcha — Bug #8: missing hero returned 500, not 404

`ErrHeroNotFound` was defined but never returned: the repository wrapped the raw GORM
error, the service re-wrapped it, and the handler's default case produced `500`. The
fix is the `errors.Is(err, gorm.ErrRecordNotFound)` translation in `GetByID`,
`Update`, and `Delete`.

**How you would debug it:** `curl GET /api/v1/heroes/999`. You see `500
{"code":"INTERNAL_ERROR"}` but the server log shows `failed to fetch hero: failed to
get hero by id 999: record not found`. The log *screams* the answer: "record not
found" was treated as an internal failure because nothing translated it. Grep for
`ErrHeroNotFound` — if it only appears in `errors.go` and the `var` block, it was never
returned anywhere.

---
# <a id="layer-11"></a>Layer 11 — Hero Handler & Auth Middleware

## ① The Objective

Expose the five hero endpoints (two public, three protected), validate the JWT in the
middleware, and enforce ownership on update/delete.

**Success checklist:**
- [ ] `GET /heroes` and `GET /heroes/:id` are public
- [ ] `POST/PUT/DELETE /heroes...` require `Authorization: Bearer <token>` (401 otherwise)
- [ ] A user cannot create a hero owned by someone else (mass-assignment defense)
- [ ] A non-owner gets `403` on update/delete; a missing hero gets `404`
- [ ] `go build ./...` and `go vet ./...` pass

## ② The Theory

- **Middleware chain (onion model)** — middleware runs before the handler; it can
  short-circuit (`c.Abort()`) or continue (`c.Next()`).
- **Context values** — the middleware puts `user_id` and `role` on the Gin context
  with `c.Set`; the handler reads them with `c.Get`.
- **Mass-assignment defense** — `Create` overwrites `hero.UserID` with the
  authenticated user's ID, so a client can never claim ownership of another user's
  hero.
- **IDOR defense** — `isOwnerOrAdmin` compares the authenticated user against the
  *stored* owner. Fetch-then-authorize: missing hero → 404 (don't reveal it exists),
  unauthorized → 403.
- **Import-cycle discipline** — middleware must not import handlers (handlers import
  middleware). It writes plain `gin.H` errors instead.

### Go concepts used in this layer

| Concept | Where it appears | Plain-English meaning |
|---|---|---|
| Middleware factory + closure | `func Authenticate(jwtSecret string) gin.HandlerFunc` | The factory captures `jwtSecret`; the returned closure uses it on every request. |
| `c.Abort()` vs `c.Next()` | in `Authenticate` | `Next()` continues the chain; `Abort()` stops it (nothing else runs, but the response already written is sent). |
| `c.Set` / `c.Get` | `c.Set(ContextUserIDKey, claims.UserID)` | Gin's context acts as a request-scoped key-value store, typed loosely (values are `any`). |
| Type assertion | `userIDVal.(uint)` | Recovers the concrete type from the `any` box. The two-value form `(value, ok)` is the safe one — always check `ok`. |
| String splitting | `strings.SplitN(authHeader, " ", 2)` | Split on the *first* space into at most 2 parts: `["Bearer", "<token>"]`. `SplitN` (not `Split`) so a token containing spaces is not torn apart. |
| Path parameter parsing | `strconv.ParseUint(c.Param("id"), 10, 64)` | `c.Param("id")` returns the `:id` segment as string; `ParseUint` converts to an unsigned int, erroring on garbage or negatives. |
| Ceiling division | `(total + limit - 1) / limit` | Integer math for "how many pages". `(7+5-1)/5 = 11/5 = 2` → 7 items at limit 5 needs 2 pages. |
| Boolean helper method | `func (h *HeroHandler) isOwnerOrAdmin(...) bool` | A small named predicate — keeps the authorize logic in one place, reused by Update and Delete. |

### Deep Dive — the onion model

```
                ┌─────────────────────────────┐
   request ───▶ │ Authenticate (middleware)    │
                │   read Authorization header  │
                │   validate JWT               │
                │   ┌───────────────────────┐  │
                │   │  Hero handler          │  │
                │   │  (Create/Update/... )  │  │
                │   └───────────────────────┘  │
   response ◀───│   writes the response        │
                └─────────────────────────────┘
```

Middleware runs *before* the handler. It may:
- **continue** — call `c.Next()`, which runs the handler, then returns.
- **abort** — write a response and call `c.Abort()`, which marks the chain as stopped;
  the handler never runs.

The middleware here does both: on success it sets identity on the context and calls
`c.Next()`; on failure it writes `401` and aborts.

### Deep Dive — the IDOR attack and the defense

**IDOR** (Insecure Direct Object Reference) is the bug where endpoint accepts an
object ID and acts on it *without checking the requester owns it*. Concretely:

```
Alice creates hero #1.
Bob logs in, calls DELETE /api/v1/heroes/1 → if the handler deletes without an
ownership check, Bob just deleted Alice's hero.
```

The defense in `Update`/`Delete`:

```
1. fetch the hero            → if missing, 404 (do not reveal that id exists)
2. authorize: is the caller the owner (or an admin)?  → if not, 403
3. only now mutate / delete
```

**Fetch-then-authorize order matters.** If you authorized by trusting the *request*
(`hero.UserID` from the body), a client could just lie. You must compare against the
**stored** owner — the row in the database.

## ③ The Build

### Step 1 — Auth middleware

File: `internals/middleware/auth-middleware.go`

```go
package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/raaj2493/production-systems/heroverse/internals/security"
)

const (
	ContextUserIDKey = "user_id"
	ContextUserRole  = "user_role"
)

func Authenticate(jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"code":    "UNAUTHORIZED",
				"message": "authorization header required",
			})
			c.Abort()
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"code":    "UNAUTHORIZED",
				"message": "invalid authorization header format (must be Bearer <token>)",
			})
			c.Abort()
			return
		}

		tokenString := parts[1]

		claims, err := security.ValidateJWT(tokenString, jwtSecret)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{
				"code":    "UNAUTHORIZED",
				"message": "invalid or expired token",
			})
			c.Abort()
			return
		}

		c.Set(ContextUserIDKey, claims.UserID)
		c.Set(ContextUserRole, claims.Role)

		c.Next()
	}
}
```

**Line by line:**

- `Authenticate(jwtSecret)` — a **middleware factory**; captures the secret.
- `c.GetHeader("Authorization")` — read the header. Empty → `401` + `c.Abort()`.
  `GetHeader` (not `GetHeaderMap`) is case-insensitive on the header name.
- `strings.SplitN(authHeader, " ", 2)` — split on the first space → `["Bearer", token]`.
  Checks there are exactly 2 parts and the scheme is `bearer` (case-insensitive).
- `security.ValidateJWT` — the actual authentication. Bad/expired token → `401`.
- `c.Set(ContextUserIDKey, claims.UserID)` / `c.Set(ContextUserRole, claims.Role)` —
  hand identity to downstream handlers.
- `c.Next()` — let the request continue to the handler.
- **Notice the imports**: `net/http`, `strings`, `gin`, `security`. **Not** `handlers`.
  That avoids the import cycle.

### Step 2 — Hero handler

File: `internals/handlers/hero-handler.go`

```go
package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/raaj2493/production-systems/heroverse/internals/middleware"
	"github.com/raaj2493/production-systems/heroverse/internals/models"
	"github.com/raaj2493/production-systems/heroverse/internals/repository"
	"github.com/raaj2493/production-systems/heroverse/internals/services"
)

type HeroHandler struct {
	service *services.HeroService
}

func NewHeroHandler(service *services.HeroService) *HeroHandler {
	return &HeroHandler{
		service: service,
	}
}

func parsePaginationParams(c *gin.Context) (int, int, error) {
	pageStr := c.Query("page")
	limitStr := c.Query("limit")

	page := 1
	limit := 20

	if pageStr != "" {
		parsedPage, err := strconv.Atoi(pageStr)
		if err != nil || parsedPage <= 0 {
			return 0, 0, services.ErrInvalidPage
		}
		page = parsedPage
	}

	if limitStr != "" {
		parsedLimit, err := strconv.Atoi(limitStr)
		if err != nil || parsedLimit <= 0 || parsedLimit > 100 {
			return 0, 0, services.ErrInvalidLimit
		}
		limit = parsedLimit
	}

	return page, limit, nil
}

func (h *HeroHandler) GetAll(c *gin.Context) {
	page, limit, err := parsePaginationParams(c)
	if err != nil {
		RespondWithError(c, err)
		return
	}

	searchQuery := c.Query("search")
	if searchQuery == "" {
		searchQuery = c.Query("q")
	}

	filter := repository.HeroFilter{
		Name:   c.Query("name"),
		Power:  c.Query("power"),
		Search: searchQuery,
		SortBy: c.Query("sort_by"),
		Order:  c.Query("order"),
	}

	heroes, total, err := h.service.GetAll(c.Request.Context(), filter, page, limit)
	if err != nil {
		RespondWithError(c, err)
		return
	}

	if heroes == nil {
		heroes = []models.Hero{}
	}

	totalPages := 0
	if total > 0 {
		totalPages = int((total + int64(limit) - 1) / int64(limit))
	}

	meta := PaginationMeta{
		Page:       page,
		Limit:      limit,
		Total:      total,
		TotalPages: totalPages,
	}

	RespondWithPagination(c, http.StatusOK, heroes, meta)
}

func (h *HeroHandler) Create(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserIDKey)
	if !exists {
		c.JSON(http.StatusUnauthorized, APIError{
			Code:    "UNAUTHORIZED",
			Message: "user context missing",
		})
		return
	}

	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusUnauthorized, APIError{
			Code:    "UNAUTHORIZED",
			Message: "invalid user context type",
		})
		return
	}

	var hero models.Hero
	if err := c.ShouldBindJSON(&hero); err != nil {
		RespondWithError(c, services.ErrNilHeroData)
		return
	}

	hero.UserID = userID

	if err := h.service.Create(c.Request.Context(), &hero); err != nil {
		RespondWithError(c, err)
		return
	}

	RespondWithData(c, http.StatusCreated, hero)
}

func (h *HeroHandler) GetByID(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 64)
	if err != nil || id == 0 {
		RespondWithError(c, services.ErrInvalidHeroID)
		return
	}

	hero, err := h.service.GetByID(c.Request.Context(), uint(id))
	if err != nil {
		RespondWithError(c, err)
		return
	}

	RespondWithData(c, http.StatusOK, hero)
}

func (h *HeroHandler) Update(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, APIError{Code: "INVALID_ID", Message: "invalid hero ID"})
		return
	}

	existingHero, err := h.service.GetByID(c.Request.Context(), uint(id))
	if err != nil {
		RespondWithError(c, err)
		return
	}

	if !h.isOwnerOrAdmin(c, existingHero.UserID) {
		c.JSON(http.StatusForbidden, APIError{
			Code:    "FORBIDDEN",
			Message: "you do not have permission to modify this hero",
		})
		return
	}

	var updateData models.Hero
	if err := c.ShouldBindJSON(&updateData); err != nil {
		RespondWithError(c, services.ErrNilHeroData)
		return
	}

	existingHero.Name = updateData.Name
	existingHero.Power = updateData.Power

	if err := h.service.Update(c.Request.Context(), existingHero); err != nil {
		RespondWithError(c, err)
		return
	}

	RespondWithData(c, http.StatusOK, existingHero)
}

func (h *HeroHandler) Delete(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 64)
	if err != nil || id == 0 {
		RespondWithError(c, services.ErrInvalidHeroID)
		return
	}

	existingHero, err := h.service.GetByID(c.Request.Context(), uint(id))
	if err != nil {
		RespondWithError(c, err)
		return
	}

	if !h.isOwnerOrAdmin(c, existingHero.UserID) {
		c.JSON(http.StatusForbidden, APIError{
			Code:    "FORBIDDEN",
			Message: "you do not have permission to delete this hero",
		})
		return
	}

	if err := h.service.Delete(c.Request.Context(), uint(id)); err != nil {
		RespondWithError(c, err)
		return
	}

	RespondWithData(c, http.StatusOK, gin.H{"message": "hero deleted successfully"})
}

func (h *HeroHandler) isOwnerOrAdmin(c *gin.Context, ownerUserID uint) bool {
	userIDVal, exists := c.Get(middleware.ContextUserIDKey)
	if !exists {
		return false
	}
	currentUserID, _ := userIDVal.(uint)

	roleVal, _ := c.Get(middleware.ContextUserRole)
	currentUserRole, _ := roleVal.(string)

	return currentUserRole == string(models.RoleAdmin) || currentUserID == ownerUserID
}
```

**Line by line:**

- `parsePaginationParams` — reads `page`/`limit`, defaults 1/20, validates ranges.
  `Atoi` converts string→int; `page=0`, `page=-2`, or `page=abc` all → `ErrInvalidPage`.
  `limit` must be `1..100` → `ErrInvalidLimit`.
- `GetAll` — `search` falls back to `q`; builds the `HeroFilter`; calls the service;
  **ceiling division** `(total+limit-1)/limit` for `totalPages`; `heroes == nil` →
  empty slice so JSON is `[]`, never `null`.
- `Create`:
  - `c.Get(middleware.ContextUserIDKey)` + **type assertion** `.(uint)` — reads what
    the middleware stored. Failures → `401`.
  - `ShouldBindJSON(&hero)` → `400` on malformed body.
  - **`hero.UserID = userID`** — the mass-assignment defense. Client-provided
    `user_id` is overwritten. This line is why a forged `"user_id": 99` in the body
    is ignored.
- `GetByID` — parse the `:id` path param; `0` or garbage → `400`. Public endpoint —
  no auth required, and it returns whatever the service found (including `404`).
- `Update`:
  - Fetch → **authorize** (`isOwnerOrAdmin`, else `403`) → bind → copy **only**
    `Name` and `Power` onto the existing record (field allow-listing) → service.
  - Copying only two fields is deliberate: the client cannot change `id`, `user_id`,
    or the timestamps.
- `Delete` — fetch → authorize (`403`) → delete. Fetch-then-authorize means a missing
  hero gives `404`, a non-owner gives `403`.
- `isOwnerOrAdmin` — admin bypass OR exact owner match, using the *stored* owner ID.
  The `_` in `currentUserID, _ :=` ignores the `ok`; a missing context already returned
  `false` via `exists`.

### Step 3 — Wire routes and main

The final `routes.go` registers hero routes; wire dependencies:

```go
heroRepo := repository.NewHeroRepository(db)
heroService := services.NewHeroService(heroRepo)
heroHandler := handlers.NewHeroHandler(heroService)
```

And in the router, protect only the mutating routes with
`protected.Use(middleware.Authenticate(jwtSecret))`.

## ④ Flow Check

```
GET  /heroes        → public   → GetAll
GET  /heroes/:id    → public   → GetByID
POST /heroes        → Authenticate → Create  (mass-assignment defense)
PUT  /heroes/:id    → Authenticate → fetch → isOwnerOrAdmin → Update
DELETE /heroes/:id  → Authenticate → fetch → isOwnerOrAdmin → Delete
```

**Walk four real requests through the layer:**

**Request 1 — create without a token:**

```
Client                          Authenticate middleware
  │  POST /api/v1/heroes           │
  │  (no Authorization header)     │
  ├───────────────────────────────▶│
  │                                │ authHeader == "" → 401 + Abort()
  │  401 {"code":"UNAUTHORIZED",   │
  │       "message":"authorization │
  │       header required"}        │
  ◀────────────────────────────────│  ← handler never runs
```

**Request 2 — create with a valid token (mass-assignment attempt):**

```
Client                          Authenticate              Create handler
  │  POST /api/v1/heroes           │                          │
  │  Bearer eyJ... (alice, id=1)  │                          │
  │  {"name":"Iron Man",          │                          │
  │   "power":"Flight",           │                          │
  │   "user_id":99}               │                          │
  ├──────────────────────────────▶│                          │
  │                               │ ValidateJWT → claims{1,"user"}
  │                               │ c.Set(user_id, 1) → Next()
  │                               ├─────────────────────────▶│
  │                               │                          │ userIDVal = 1
  │                               │                          │ hero.UserID = 1  ← 99 overwritten
  │                               │                          │ service.Create → INSERT
  │  201 {"data":{"id":1,"name":  │                          │
  │   "Iron Man","user_id":1,...}}│                          │
  ◀───────────────────────────────────────────────────────────│
```

**Request 3 — Bob updates Alice's hero:**

```
Client                          Update handler
  │  PUT /api/v1/heroes/1          │
  │  Bearer eyJ... (bob, id=2)     │
  │  {"name":"Renamed","power":"x"│
  ├───────────────────────────────▶│
  │                                │ GetByID(1) → hero{UserID:1}  (Alice's)
  │                                │ isOwnerOrAdmin(c, 1)?
  │                                │   currentUserID=2, role="user"
  │                                │   role != admin, 2 != 1 → false
  │  403 {"code":"FORBIDDEN",      │
  │       "message":"you do not    │
  │       have permission to       │
  │       modify this hero"}       │
  ◀────────────────────────────────│  ← DB untouched
```

**Request 4 — anyone reads a missing hero:**

```
Client                          GetByID handler
  │  GET /api/v1/heroes/999        │
  ├───────────────────────────────▶│
  │                                │ service.GetByID → ErrHeroNotFound
  │                                │ RespondWithError → 404
  │  404 {"code":"HERO_NOT_FOUND", │
  │       "message":"the requested │
  │       hero was not found"}     │
  ◀────────────────────────────────│
```

## ⑤ Run it

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"password123"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['token'])")

curl -X POST http://localhost:8080/api/v1/heroes \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"Iron Man","power":"Flight"}'   # 201

curl "http://localhost:8080/api/v1/heroes"                  # 200, public
curl -X PUT http://localhost:8080/api/v1/heroes/1 \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"Iron Man MK II","power":"Flight"}'           # 200 owner
```

**Troubleshooting:**

| Symptom | Cause | Fix |
|---|---|---|
| `401 invalid or expired token` on every call | Wrong `JWT_SECRET` between login and middleware, or expired token | Confirm `.env` `JWT_SECRET` is stable across restarts; re-login |
| `401 invalid authorization header format` | Client sent `Token <x>` or missing space | Must be exactly `Bearer <token>` |
| `403` for the owner | Token user_id type mismatch (int vs uint) | `claims.UserID` is `uint`; the assertion `.(uint)` must match what `c.Set` stored |
| `404` for an id that exists | Wrong base path (e.g. `/api/heroes` vs `/api/v1/heroes`) | Match the registered route prefix |
| `panic: assignment to entry in nil map` | `gin.H`/map nil assignment somewhere | Not applicable here — but keep an eye on nil maps in handlers |

## ⑤ The Gotchas — Bug #2 and Bug #9

**Bug #2 (import cycle):** middleware originally imported `handlers` to reuse
`APIError`, while handlers import middleware → `import cycle not allowed`. Fixed by
removing the handlers import (middleware writes plain `gin.H`).

**Why cycles are fatal:** Go does not allow package A → B → A. The compiler reports it
immediately (`import cycle not allowed`). The lesson is architectural: the *inner*
layer (middleware) must not depend on the *outer* layer (handlers). Middleware writes
its own minimal error JSON (`gin.H{...}`) instead.

**Bug #9 (no ownership check on Delete):** `Delete` originally skipped
`isOwnerOrAdmin`, so *any* authenticated user could delete *any* hero. Confirmed by
test: a second user deleted another user's hero with `200`. Fixed by fetch-then-
authorize.

**How you would debug Bug #9:** register Alice and Bob. Alice creates a hero. Delete
it with Bob's token:

```bash
curl -X DELETE http://localhost:8080/api/v1/heroes/1 -H "Authorization: Bearer $BOB_TOKEN"
# fixed:  403 {"code":"FORBIDDEN",...}
# broken: 200 {"message":"hero deleted successfully"}   ← BUG
```

A `200` here is proof the ownership check is missing — the exact regression test you
want in your CI.

---
# <a id="layer-12"></a>Layer 12 — Docker, `.env`, and full test run

## ① The Objective

Package PostgreSQL with Docker, finalize configuration, and run the complete test
suite against every endpoint.

**Success checklist:**
- [ ] `docker compose up -d postgres` starts a healthy Postgres
- [ ] `go build ./...` and `go vet ./...` pass
- [ ] Every endpoint in the test suite returns the expected status
- [ ] You have verified the ownership rule (403) end to end

## ② The Theory

- **Container** — an isolated process with its own filesystem, sharing the host
  kernel. `postgres:17-alpine` is the same database everywhere.
- **Named volume** — `postgres_data` persists the database files across restarts.
- **Healthcheck** — `pg_isready` tells dependent services when Postgres is actually
  ready, not just "started".

### Docker concepts used in this layer

| Concept | Where it appears | Plain-English meaning |
|---|---|---|
| Image | `image: postgres:17-alpine` | A frozen filesystem + metadata. `postgres:17-alpine` is a small, pinned Postgres 17. |
| Service | `services: postgres:` | One thing Compose manages (here: the database). |
| Environment interpolation | `POSTGRES_USER: ${DATABASE_USER}` | Compose reads `.env` and substitutes `${VAR}`. Same values the Go app reads — one source of truth. |
| Port mapping | `"${DATABASE_PORT}:5432"` | Host port → container port. Postgres *inside* always listens on 5432; on your machine it appears on `DATABASE_PORT`. |
| Named volume | `postgres_data:/var/lib/postgresql/data` | The container's data directory is mounted on a persistent volume. Containers are ephemeral; volumes survive `down`. |
| Healthcheck | `pg_isready -U ... -d ...` | A probe command. Compose reports the service `healthy` only after it succeeds. |

### Deep Dive — why "the same everywhere" is the whole point

The container runs a real Postgres exactly as Postgres is configured by `postgres:17-alpine`.
Your laptop, your teammate's laptop, and your CI run the *identical* database. The
common failure it prevents is "works on my machine" — version mismatches, missing
extensions, platform-specific setup. Docker removes that class of problem for the
database layer.

## ③ The Build

### Step 1 — `.env`

```bash
APP_ENV=development
SERVER_PORT=8080
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USER=postgres
DATABASE_PASSWORD=secretpassword
DATABASE_NAME=heroverse
JWT_SECRET=super-secret-default-key-change-in-production
```

Both the Go app (via `config.Load()`) and Compose (via `${VAR}`) read this file. That
is the single source of truth for every environment-specific value.

### Step 2 — `docker-compose.yml`

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:17-alpine
    container_name: heroverse_db
    restart: always
    environment:
      POSTGRES_USER: ${DATABASE_USER}
      POSTGRES_PASSWORD: ${DATABASE_PASSWORD}
      POSTGRES_DB: ${DATABASE_NAME}
    ports:
      - "${DATABASE_PORT}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DATABASE_USER} -d ${DATABASE_NAME}"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
```

**Line by line:**

- `version: '3.8'` — obsolete in modern Compose but harmless.
- `postgres:` — the service name (the thing `docker compose up -d postgres` refers to).
- `image: postgres:17-alpine` — the pinned image. Tag pinned = reproducible.
- `container_name: heroverse_db` — a stable name so `docker exec heroverse_db psql ...`
  works without listing containers.
- `restart: always` — if the container crashes, Docker restarts it.
- `environment:` — Compose injects these from our `.env` via `${VAR}`. These become
  Postgres's own env vars; the Postgres image uses them to create the user, password,
  and database on first boot.
- `ports: "${DATABASE_PORT}:5432"` — host port → container port.
- `volumes: postgres_data:/var/lib/postgresql/data` — persistence.
- `healthcheck` — probes readiness with `pg_isready` every 5s. Without this, "up" and
  "ready" are different things: the container can be running while Postgres is still
  initializing.
- `volumes: postgres_data:` — declares the named volume.

### Step 3 — Run everything

```bash
docker compose up -d postgres
go build ./...
go vet ./...
go run cmd/api/main.go
```

## ④ Flow Check

```
docker compose up -d postgres
   │
   ▼  (healthy)
go run cmd/api/main.go
   ├─ config.Load()      → reads .env
   ├─ database.Connect() → connects to localhost:5432 (the container)
   ├─ database.Migrate() → creates users + heroes tables
   ├─ DI wiring          → repos → services → handlers → router
   └─ ListenAndServe     → port 8080
```

**Walk one boot through the layer (narrative):**

1. `docker compose up -d postgres` pulls `postgres:17-alpine` (first time), then
   starts the container. The env vars from `.env` tell Postgres to create user
   `postgres`, password `secretpassword`, database `heroverse`.
2. The healthcheck polls `pg_isready` every 5s; after ~2–5s it reports `healthy`.
3. `go run cmd/api/main.go` reads `.env`, connects to `localhost:5432` (which forwards
   to the container's 5432), pings, migrates both tables, wires all dependencies, and
   starts listening on 8080.

## ⑤ Run it — the full test suite

```bash
# health
curl http://localhost:8080/health                                    # 200

# auth
curl -X POST http://localhost:8080/api/v1/auth/register -H "Content-Type: application/json" -d '{"email":"alice@example.com","password":"password123"}'   # 201
curl -X POST http://localhost:8080/api/v1/auth/register -H "Content-Type: application/json" -d '{"email":"alice@example.com","password":"password123"}'   # 400 duplicate
curl -X POST http://localhost:8080/api/v1/auth/login -H "Content-Type: application/json" -d '{"email":"alice@example.com","password":"password123"}'       # 200 + token
curl -X POST http://localhost:8080/api/v1/auth/login -H "Content-Type: application/json" -d '{"email":"alice@example.com","password":"wrongpass"}'         # 401

# heroes (public)
curl "http://localhost:8080/api/v1/heroes"                                # 200
curl "http://localhost:8080/api/v1/heroes/1"                              # 200
curl "http://localhost:8080/api/v1/heroes/999"                            # 404
curl "http://localhost:8080/api/v1/heroes?name=man&sort_by=name&page=1&limit=20"   # 200 filtered

# heroes (protected)
# ... using TOKEN from login
curl -X POST http://localhost:8080/api/v1/heroes -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"name":"Thor","power":"Lightning"}'  # 201
curl -X PUT http://localhost:8080/api/v1/heroes/1 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"name":"Iron Man MK II","power":"Flight"}'  # 200
curl -X DELETE http://localhost:8080/api/v1/heroes/1 -H "Authorization: Bearer $TOKEN"   # 200
curl -X POST http://localhost:8080/api/v1/heroes -H "Content-Type: application/json" -d '{}'   # 401 (no token)
```

## ⑤ The Gotcha — verify the ownership rule

Register a second user `bob@example.com`. Using Bob's token:
- `PUT /heroes/<alice's id>` → **403**
- `DELETE /heroes/<alice's id>` → **403**

If either returns `200`, the ownership check is missing — that was Bug #9. This is
also the *hardest* bug to catch with a single-account test, which is why the test
suite includes a second user.

---

## Final Project Map

```
Heroverse/
├── cmd/api/main.go              # assembly / dependency injection
├── internals/
│   ├── config/config.go         # env parsing, DSN, validation
│   ├── database/db.go           # pool + migration + TranslateError
│   ├── models/user-model.go     # User struct
│   ├── models/hero-model.go     # Hero struct
│   ├── security/password.go     # bcrypt
│   ├── security/jwt.go          # HS256 tokens
│   ├── repository/user-repository.go   # users CRUD
│   ├── repository/hero-repository.go   # heroes CRUD + filter/search/sort/page
│   ├── services/auth-service.go        # register/login rules
│   ├── services/hero-service.go        # hero rules + error translation
│   ├── handlers/health-handler.go      # /health
│   ├── handlers/response.go            # envelopes
│   ├── handlers/errors.go              # error → status mapper
│   ├── handlers/auth-handler.go        # register/login HTTP
│   ├── handlers/hero-handler.go        # heroes HTTP + ownership
│   ├── middleware/auth-middleware.go   # JWT guard
│   └── router/routes.go                # route table
├── .env
└── docker-compose.yml
```

**The dependency flow, reading the code from bottom to top:**

```
models  (schema + JSON shape)
   ▲
security  (bcrypt, JWT)         database  (pool, migration)
   ▲                                ▲
   └─────────── repository ─────────┘   (SQL only)
                     ▲
                 services  (business rules, sentinels)
                     ▲
             handlers + middleware  (HTTP, auth, ownership)
                     ▲
                  router  (route table)
                     ▲
             main.go  (wires everything)
```

**Verify the whole build:**

```bash
cd Heroverse
go build ./...
go vet ./...
go run cmd/api/main.go
```

Congratulations — you built a layered, JWT-secured, PostgreSQL-backed REST API, one
layer and one line at a time.

---
# <a id="appendix"></a>Appendix — Complete Endpoint Reference

Every endpoint of the API, one page. Each entry shows the method + path, what it
does, whether it needs a token, and a full request/response example.

## Global notes

- **Base URL:** `http://localhost:8080`
- **Auth:** routes marked 🔒 require `Authorization: Bearer <token>` where `<token>`
  is the `data.token` returned by login.
- **Envelope:** every success is `{"data": ...}`; lists add `"meta"`. Every error is
  `{"code": "...", "message": "..."}`.
- **Timestamps:** shown as `2026-08-14T12:00:00Z`-style for brevity.

---

## 1. Health

### `GET /health` — public

Returns liveness. No auth, no database touched.

```bash
curl http://localhost:8080/health
```

```json
200
{"status":"ok"}
```

---

## 2. Auth

### `POST /api/v1/auth/register` — public

Creates a user. Email is normalized (trimmed, lowercased). Password must be ≥ 8 chars.

```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"Alice@Example.com ","password":"password123"}'
```

**Success:**

```json
201
{
  "data": {
    "id": 1,
    "email": "alice@example.com",
    "role": "user",
    "created_at": "2026-08-14T12:00:00Z",
    "updated_at": "2026-08-14T12:00:00Z"
  }
}
```

Note: no `password_hash` field — `json:"-"` hides it (Layer 4).

**Duplicate email:**

```json
400
{"code":"INVALID_INPUT","message":"user with this email already exists"}
```

**Invalid email:**

```json
400
{"code":"INVALID_INPUT","message":"invalid email address format"}
```

**Weak password:**

```json
400
{"code":"INVALID_INPUT","message":"password must be at least 8 characters long"}
```

**Malformed body** (bad JSON, wrong types, missing Content-Type):

```json
400
{"code":"INVALID_INPUT","message":"invalid request body"}
```

### `POST /api/v1/auth/login` — public

Returns a JWT (24h) and the user. The response is **identical** for unknown email and
wrong password (anti user-enumeration).

```bash
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"password123"}'
```

**Success:**

```json
200
{
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJyb2xlIjoidXNlciIsImV4cCI6MTc1MDAwMDAwMCwiaWF0IjoxNzQ5OTEzNjAwfQ.<signature>",
    "user": {
      "id": 1,
      "email": "alice@example.com",
      "role": "user",
      "created_at": "2026-08-14T12:00:00Z",
      "updated_at": "2026-08-14T12:00:00Z"
    }
  }
}
```

**Wrong password or unknown email** (same body for both):

```json
401
{"code":"UNAUTHORIZED","message":"invalid email or password"}
```

---

## 3. Heroes — public

### `GET /api/v1/heroes` — public

Lists heroes with optional filters, search, sort, and pagination.

Query parameters:

| Param | Default | Rule |
|---|---|---|
| `name` | none | case-insensitive contains on `name` |
| `power` | none | case-insensitive contains on `power` |
| `search` (alias `q`) | none | ORs `name` and `power` contains |
| `sort_by` | `id` | one of `id`, `name`, `power`, `created_at` |
| `order` | `asc` | `asc` or `desc` |
| `page` | `1` | integer ≥ 1 |
| `limit` | `20` | integer 1–100 |

```bash
curl "http://localhost:8080/api/v1/heroes?search=light&sort_by=name&order=desc&page=2&limit=5"
```

**Success:**

```json
200
{
  "data": [
    {
      "id": 7,
      "name": "Thor",
      "user_id": 1,
      "power": "Lightning",
      "created_at": "2026-08-14T12:00:00Z",
      "updated_at": "2026-08-14T12:00:00Z"
    }
  ],
  "meta": {
    "page": 2,
    "limit": 5,
    "total": 7,
    "total_pages": 2
  }
}
```

Empty result returns `"data": []` (never `null`):

```json
200
{"data":[],"meta":{"page":1,"limit":20,"total":0,"total_pages":0}}
```

**Bad sort field:**

```json
400
{"code":"INVALID_INPUT","message":"invalid sort_by field: allowed fields are id, name, power, created_at"}
```

**Bad page / limit:**

```json
400
{"code":"INVALID_INPUT","message":"page must be an integer greater than 0"}
```

```json
400
{"code":"INVALID_INPUT","message":"limit must be an integer between 1 and 100"}
```

### `GET /api/v1/heroes/:id` — public

```bash
curl "http://localhost:8080/api/v1/heroes/1"
```

**Success:**

```json
200
{
  "data": {
    "id": 1,
    "name": "Iron Man",
    "user_id": 1,
    "power": "Flight",
    "created_at": "2026-08-14T12:00:00Z",
    "updated_at": "2026-08-14T12:00:00Z"
  }
}
```

**Missing hero:**

```json
404
{"code":"HERO_NOT_FOUND","message":"the requested hero was not found"}
```

**Invalid id (non-numeric or `0`):**

```json
400
{"code":"INVALID_INPUT","message":"hero id must be greater than zero"}
```

---

## 4. Heroes — protected 🔒

All of these require a valid token. A missing/malformed/bad token gives:

```json
401
{"code":"UNAUTHORIZED","message":"authorization header required"}
```

```json
401
{"code":"UNAUTHORIZED","message":"invalid authorization header format (must be Bearer <token>)"}
```

```json
401
{"code":"UNAUTHORIZED","message":"invalid or expired token"}
```

### `POST /api/v1/heroes` 🔒 — create

```bash
curl -X POST http://localhost:8080/api/v1/heroes \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"Iron Man","power":"Flight"}'
```

**Success:** the `user_id` is forced to the authenticated user (a client-sent
`user_id` is ignored — mass-assignment defense).

```json
201
{
  "data": {
    "id": 1,
    "name": "Iron Man",
    "user_id": 1,
    "power": "Flight",
    "created_at": "2026-08-14T12:00:00Z",
    "updated_at": "2026-08-14T12:00:00Z"
  }
}
```

**Empty name / power:**

```json
400
{"code":"INVALID_INPUT","message":"hero name cannot be empty"}
```

```json
400
{"code":"INVALID_INPUT","message":"hero power cannot be empty"}
```

**No token:**

```json
401
{"code":"UNAUTHORIZED","message":"authorization header required"}
```

### `PUT /api/v1/heroes/:id` 🔒 — update (owner or admin)

```bash
curl -X PUT http://localhost:8080/api/v1/heroes/1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"Iron Man MK II","power":"Flight"}'
```

**Success (owner):**

```json
200
{
  "data": {
    "id": 1,
    "name": "Iron Man MK II",
    "user_id": 1,
    "power": "Flight",
    "created_at": "2026-08-14T12:00:00Z",
    "updated_at": "2026-08-14T12:00:01Z"
  }
}
```

Only `name` and `power` are taken from the body; `id`, `user_id`, and timestamps
cannot be changed via this endpoint.

**Forbidden (authenticated but not the owner, not admin):**

```json
403
{"code":"FORBIDDEN","message":"you do not have permission to modify this hero"}
```

**Missing hero:**

```json
404
{"code":"HERO_NOT_FOUND","message":"the requested hero was not found"}
```

### `DELETE /api/v1/heroes/:id` 🔒 — delete (owner or admin)

```bash
curl -X DELETE http://localhost:8080/api/v1/heroes/1 \
  -H "Authorization: Bearer $TOKEN"
```

**Success (owner):**

```json
200
{"data":{"message":"hero deleted successfully"}}
```

**Forbidden (non-owner):**

```json
403
{"code":"FORBIDDEN","message":"you do not have permission to delete this hero"}
```

**Missing hero:**

```json
404
{"code":"HERO_NOT_FOUND","message":"the requested hero was not found"}
```

---

## Status code cheat sheet

| Code | Meaning | Typical causes in this API |
|---|---|---|
| `200` | OK | login, list, get-by-id, update, delete |
| `201` | Created | register, create hero |
| `400` | Bad request | malformed body, invalid email/password/name/power/sort/page/limit, duplicate email |
| `401` | Unauthenticated | missing/bad/expired token, wrong credentials |
| `403` | Forbidden | authenticated but not the owner and not admin |
| `404` | Not found | unknown hero id |
| `500` | Internal error | anything unexpected; details only in server logs |

## Error code cheat sheet

| `code` | When |
|---|---|
| `INVALID_INPUT` | any validation failure or bad JSON body |
| `UNAUTHORIZED` | missing/bad token or wrong credentials |
| `FORBIDDEN` | not the owner / not admin |
| `HERO_NOT_FOUND` | hero id does not exist |
| `INVALID_ID` | non-numeric path id on PUT |
| `INTERNAL_ERROR` | unexpected server failure (details in logs) |

---

## The 9 bugs this project fixed (quick recap)

| # | Layer | Bug | Symptom | Fix |
|---|---|---|---|---|
| 1 | 8 | nil `AuthHandler` | panic on register/login | wire `userRepo → authService → authHandler` |
| 2 | 11 | middleware ↔ handlers import cycle | `import cycle not allowed` | middleware writes `gin.H`, drops handlers import |
| 3 | 5 | ES256 signed with string secret | `key is of invalid type` | sign + verify with HS256, force HMAC |
| 4 | 7 | `errors.Is(err, errors.New(...))` | duplicate email → 500 | compare `err.Error()` strings |
| 5 | 4 | `User` not migrated | `relation "users" does not exist` | migrate both models |
| 6 | 3 | missing `TranslateError` | duplicate email → 500 | `TranslateError: true` |
| 7 | 3 | SQLite driver + Postgres DSN | garbage file, no real DB | use `postgres` dialector |
| 8 | 10 | missing `ErrRecordNotFound` translation | missing hero → 500 | translate to `ErrHeroNotFound` → 404 |
| 9 | 11 | no ownership check on delete | any user deletes any hero | fetch-then-authorize `isOwnerOrAdmin` |
