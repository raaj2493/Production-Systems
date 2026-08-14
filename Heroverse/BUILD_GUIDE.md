# Build Guide: Heroverse API — Layer by Layer, Line by Line

This guide rebuilds the Heroverse API from an empty folder to a fully working
production-style application. We go **one layer at a time**, and inside every layer we
go **one function at a time, one line at a time**.

Every step follows the same rhythm:

```
①  THE OBJECTIVE   → what are we building right now, and why does it come at this point?
②  THE THEORY      → the concept we are applying, explained in plain words.
③  THE BUILD       → the code, line by line. Each file is written completely.
④  FLOW CHECK      → how this piece connects to the pieces already built.
⑤  THE GOTCHA      → the real bug that happened here when this project was being made.
```

> **Setup requirement before Layer 1:** Go 1.25+, Docker (for PostgreSQL), and a
> terminal. Every command is shown. Type everything yourself — that is how you learn.

---

## How to Use This Guide (read this first)

There are **three documents** in this project, and each has one job:

| File | Job | Read it when... |
|---|---|---|
| `BUILD_GUIDE.md` (this file) | The **"what to type"** — 12 layers, full code, line-by-line | you are building |
| `THEORY_DEEP_DIVE.md` | The **"why"** — same 12 layers, the concept behind each decision | you don't understand *why* something works |
| `TESTING.md` | The **"did it work"** — endpoint tests + the 9 real bugs that were found | you want to verify everything or debug |

### The 5 rules of using this guide

1. **Don't read it like a novel.** Read ONE layer at a time, with a terminal open next
   to it.

2. **For every layer, follow this loop:**
   - Read **① The Objective** and **② The Theory** first (about a minute) — know *what*
     and *why* before you write anything.
   - **Type the code yourself.** Copy it into the matching folder
     (`cmd/api/`, `internals/...`). Do **not** copy-paste with your mouse — typing is
     what builds the mental map.
   - Run the **⑤ Run it** command and confirm you see the expected output.
   - Read the matching section in `THEORY_DEEP_DIVE.md` to lock in the "why".
   - Read **⑤ The Gotcha** and remember it — these are real bugs that broke this
     project; knowing them saves you weeks later.

3. **Don't move to the next layer until the current one runs.** Each layer compiles
   and can be verified on its own. If a later layer seems broken, the problem is
   almost always in a previous layer — go back, don't push forward.

4. **If you get stuck, use this reference order:**
   - Runtime error → check the **⑤ The Gotcha** box of the layer you're on (it is
     often Bug #6 / #8 / #9 from the test log).
   - Don't understand a concept → same layer in `THEORY_DEEP_DIVE.md`.
   - Everything builds but something behaves wrong → run the matching test from
     `TESTING.md`.

5. **The real test:** after building once, delete the `internals/` folder and rebuild
   from memory, using only the layer headings as a checklist. If you can do that, you
   own this codebase.

---

## Table of Contents

- [Layer 1 — The Skeleton: server, router, health endpoint](#layer-1--the-skeleton-server-router-health-endpoint)
- [Layer 2 — Configuration: environment variables](#layer-2--configuration-environment-variables)
- [Layer 3 — Database connection & migrations](#layer-3--database-connection--migrations)
- [Layer 4 — Models: User and Hero](#layer-4--models-user-and-hero)
- [Layer 5 — Security: bcrypt & JWT](#layer-5--security-bcrypt--jwt)
- [Layer 6 — User Repository](#layer-6--user-repository)
- [Layer 7 — Auth Service (business logic)](#layer-7--auth-service-business-logic)
- [Layer 8 — Response helpers & Auth Handler](#layer-8--response-helpers--auth-handler)
- [Layer 9 — Hero Repository](#layer-9--hero-repository)
- [Layer 10 — Hero Service](#layer-10--hero-service)
- [Layer 11 — Hero Handler & Auth Middleware](#layer-11--hero-handler--auth-middleware)
- [Layer 12 — Docker, `.env`, and full test run](#layer-12--docker-env-and-full-test-run)

---

# Layer 1 — The Skeleton: server, router, health endpoint

## ① The Objective

We build the smallest possible running web server: a Gin engine with one route
`GET /health` that answers `{"status":"ok"}`. This proves our toolchain works before
we add any real logic.

## ② The Theory

A web server is just an **infinite loop** that:
1. listens on a port for incoming network connections,
2. reads the HTTP request (method, path, headers, body),
3. decides which code should handle it (routing),
4. writes back an HTTP response.

We will not write the HTTP parser ourselves — that is what the **Gin** framework
does. Our job is to tell Gin *which path maps to which handler*.

Two terms you must know from now on:

- **Handler** — a function that receives a request and produces a response.
- **Router** — the table that maps `METHOD /path` to a handler.

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
  program. `cmd` is the Go convention for "runnable programs"; `api` is the name of
  our program.
- `mkdir -p Heroverse/internals/{...}` — creates *every* package folder at once.
  `internals` is a special Go directory: **only this module can import from it**. It is
  how we keep our architecture private.
- `go mod init github.com/raaj2493/production-systems/heroverse` — creates `go.mod`.
  The path is not a real website; it is just a unique name that becomes the root of
  every import statement (for example
  `github.com/raaj2493/production-systems/heroverse/internals/router`).

### Step 2 — Install Gin

```bash
go get github.com/gin-gonic/gin
```

`go get` downloads the library, records its version in `go.mod`, and writes checksums
into `go.sum`.

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
  here it does, which is the convention.
- `import "github.com/gin-gonic/gin"` — we need Gin's `*gin.Context` and `gin.H`.
- `func HealthHandler() gin.HandlerFunc {` — this is a **factory function**. It does
  not handle a request itself; it *returns* a handler. Why? Because `HealthHandler` is
  a factory with no arguments — but look at Layer 11: `middleware.Authenticate(jwtSecret)`
  is also a factory that *captures* a value. Factories are how Gin lets us pass
  configuration into a handler.
- `return func(c *gin.Context) { ... }` — this inner function is the actual handler.
  It is a **closure**: even though it will run later (when a request arrives), it
  remembers the scope in which it was created. `c` is Gin's context — it carries the
  request *and* the response writer.
- `c.JSON(200, gin.H{"status": "ok"})` — two things happen:
  1. `gin.H{...}` is shorthand for `map[string]any`. We are building the JSON object.
  2. `c.JSON(code, value)` sets the HTTP status code to `200`, sets the header
     `Content-Type: application/json`, serializes the map to JSON, and writes it to
     the response. The client receives exactly `{"status":"ok"}`.

### Step 4 — Write the router

File: `internals/router/routes.go`

```go
package router

import (
	"github.com/gin-gonic/gin"

	"github.com/raaj2493/production-systems/heroverse/internals/handlers"
)

func SetupRouter(env string, heroHandler *handlers.HeroHandler, authHandler *handlers.AuthHandler, jwtSecret string) *gin.Engine {
	if env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.New()

	r.GET("/health", handlers.HealthHandler())

	v1 := r.Group("/api/v1")
	{
		registerAuthRoutes(v1, authHandler)
		registerHeroRoutes(v1, heroHandler, jwtSecret)
	}

	return r
}

func registerAuthRoutes(rg *gin.RouterGroup, authHandler *handlers.AuthHandler) {
	auth := rg.Group("/auth")
	{
		auth.POST("/register", authHandler.Register)
		auth.POST("/login", authHandler.Login)
	}
}

func registerHeroRoutes(rg *gin.RouterGroup, heroHandler *handlers.HeroHandler, jwtSecret string) {
	rg.GET("/heroes", heroHandler.GetAll)
	rg.GET("/heroes/:id", heroHandler.GetByID)

	protected := rg.Group("")
	protected.Use(middleware.Authenticate(jwtSecret))
	{
		protected.POST("/heroes", heroHandler.Create)
		protected.PUT("/heroes/:id", heroHandler.Update)
		protected.DELETE("/heroes/:id", heroHandler.Delete)
	}
}
```

> **⚠ Important for Layer 1:** this is the *final* router. At Layer 1 we only have
> `HealthHandler`. So start with this minimal version:

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

**Line by line (minimal version):**

- `func SetupRouter(env string) *gin.Engine {` — the router is also a factory. It
  returns a `*gin.Engine` (the whole application). We pass `env` so it can decide
  debug vs release mode.
- `r := gin.New()` — creates a bare engine. `gin.Default()` would also add the
  Logger and Recovery middleware; we use `New()` and add middleware ourselves later.
- `r.GET("/health", handlers.HealthHandler())` — **route registration**. It says:
  "when an HTTP GET arrives on path `/health`, run the handler returned by
  `HealthHandler()`."
- `return r` — hand the fully-configured engine back to `main`.

### Step 5 — Write the entry point

File: `cmd/api/main.go`

```go
package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/raaj2493/production-systems/heroverse/internals/config"
	"github.com/raaj2493/production-systems/heroverse/internals/database"
	"github.com/raaj2493/production-systems/heroverse/internals/handlers"
	"github.com/raaj2493/production-systems/heroverse/internals/models"
	"github.com/raaj2493/production-systems/heroverse/internals/repository"
	"github.com/raaj2493/production-systems/heroverse/internals/router"
	"github.com/raaj2493/production-systems/heroverse/internals/services"
)

func main() {
	// 1. Load Config
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// 2. Connect Database
	db, err := database.Connect(&cfg.Database)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	log.Println("Database connected successfully.")

	// 3. Auto-Migrate Schema (Hero + User)
	if err := database.Migrate(db, &models.Hero{}, &models.User{}); err != nil {
		log.Fatalf("Failed to auto-migrate database: %v", err)
	}
	log.Println("Database schema auto-migrated successfully.")

	// 4. Dependency Injection
	heroRepo := repository.NewHeroRepository(db)
	heroService := services.NewHeroService(heroRepo)
	heroHandler := handlers.NewHeroHandler(heroService)

	userRepo := repository.NewUserRepository(db)
	authService := services.NewAuthService(userRepo, cfg.JWT.Secret)
	authHandler := handlers.NewAuthHandler(authService)

	// 5. Initialize Router
	engine := router.SetupRouter(cfg.App.Env, heroHandler, authHandler, cfg.JWT.Secret)

	// 6. Configure & Start HTTP Server
	server := &http.Server{
		Addr:    fmt.Sprintf(":%d", cfg.Server.Port),
		Handler: engine,
	}

	log.Printf("Starting server on port %d...", cfg.Server.Port)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server error: %v", err)
	}
}
```

> **⚠ Important for Layer 1:** this is the *final* `main.go`. For now, write the
> minimal version so it compiles with the minimal router:

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

**Line by line (minimal version):**

- `package main` — only `cmd/api` has this. A `main` package is a program.
- `func main() {` — the starting point Go executes when you run the binary.
- `engine := router.SetupRouter("development")` — ask the router for the Gin engine.
- `server := &http.Server{ Addr: ":8080", Handler: engine }` — build a real HTTP
  server. `Addr` is the listen address. `Handler` is everything that will process
  requests — our Gin engine.
- `server.ListenAndServe()` — **this call blocks forever**, serving requests until the
  process is killed. The `err != http.ErrServerClosed` check means: when the server is
  shut down gracefully, the returned error is *expected*, so we do not treat it as a
  crash.

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

## ⑤ Run it

```bash
go run cmd/api/main.go
# another terminal:
curl http://localhost:8080/health
# → {"status":"ok"}
```

---

# Layer 2 — Configuration: environment variables

## ① The Objective

Replace hard-coded values (port, env, later database credentials and JWT secret) with
values read from environment variables and a `.env` file. The same binary must run on
any machine without recompiling.

## ② The Theory

Configuration lives outside the code because it **changes by environment**: your laptop
uses `localhost:5432`, production uses a managed database URL; production must use a
different JWT secret. Two libraries do the work:

- **`godotenv`** — loads a `.env` file into the process environment (only if present).
- **`caarlos0/env`** — reads environment variables into a typed Go struct using
  **struct tags** (`env:"PORT"`), applying defaults from `envDefault:"8080"`.

This is your first taste of **reflection**: the library inspects your struct at
runtime, finds the tags, and fills the fields. That is also how GORM and
`encoding/json` work later.

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
    it (see `Validate`).
- **`func (db DatabaseConfig) DSN() string`** — a **method with a value receiver**.
  It returns the **Data Source Name**: the one string the PostgreSQL driver needs.
  `fmt.Sprintf` formats with `%s` (string) and `%d` (int). `sslmode=disable` disables
  TLS (fine for local dev; production would use `require`).
- **`func (c *Config) Validate() error`** — a **method with a pointer receiver**
  (pointer so we don't copy the whole struct). It only enforces rules in
  `production`: the database password must exist and the JWT secret must not be the
  default. This is **fail-fast**: a misconfigured production build refuses to boot.
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
from config (the full final `main.go` from Layer 1 already does this — uncomment/keep
the config lines):

```go
cfg, err := config.Load()
if err != nil {
	log.Fatalf("Failed to load config: %v", err)
}
```

Then use `fmt.Sprintf(":%d", cfg.Server.Port)` for the `Addr`.

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

## ⑤ Run it

```bash
go run cmd/api/main.go
curl http://localhost:8080/health   # still works, port now from config
```

## ⑤ The Gotcha — Why config must come first

`config.Load()` is the very first call in `main`. If you hard-code anything, you can't
change behaviour without recompiling. And because `Validate()` fails fast, a missing
production password is reported at startup — not after a week of silent 500 errors.

---

# Layer 3 — Database connection & migrations

## ① The Objective

Open a PostgreSQL connection with a connection pool, and write a migration helper that
creates tables from our models.

## ② The Theory

Two important ideas:

1. **Connection pool** — opening a database connection costs a TCP handshake + auth.
   We keep a pool of reusable connections: `MaxOpen` (upper cap), `MaxIdle` (kept
   warm), `MaxLifetime` (recycle stale ones). The app borrows a connection, uses it,
   returns it.
2. **ORM + `TranslateError`** — GORM turns Go structs into SQL and SQL results back
   into structs. `TranslateError: true` makes GORM convert database-specific errors
   (e.g. Postgres `23505` for a unique violation) into portable Go sentinels like
   `gorm.ErrDuplicatedKey`. Without it, duplicate-email detection cannot work.
3. **AutoMigrate** — reads our model struct tags and generates `CREATE TABLE IF NOT
   EXISTS`. It is idempotent, so it is safe to run at every startup.

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
  the first request.
- `func Migrate(db *gorm.DB, models ...any) error` — `...any` means "any number of
  values of any type". `AutoMigrate` reflects over them and creates/updates tables.

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

## ⑤ Run it

```bash
docker compose up -d postgres   # (Layer 12 has the compose file; for now run Postgres any way you like)
go run cmd/api/main.go
# → Database connected successfully.
```

## ⑤ The Gotcha — Two real bugs happened right here

**Bug #7 (wrong driver):** the project originally opened the connection with the
**SQLite** driver (`sqlite.Open(cfg.DSN())`) while the DSN was a PostgreSQL connection
string. SQLite silently treated that string as a *filename* and created a garbage file
on disk — bypassing Postgres entirely. The dialector and the DSN must always match.

**Bug #6 (missing `TranslateError`):** with `TranslateError: false`, duplicate email
errors surfaced as raw `SQLSTATE` strings, so `errors.Is(err, gorm.ErrDuplicatedKey)`
never matched and duplicates returned `500` instead of `400`. Both fixed by the two
lines shown above.

---

# Layer 4 — Models: User and Hero

## ① The Objective

Define the two database tables as Go structs. The structs are the **single source of
truth** for both the SQL schema (GORM tags) and the JSON API shape (json tags).

## ② The Theory

A **struct tag** is metadata attached to a field. Three different libraries read these
tags:

- `gorm:"..."` — GORM reads these to build the table.
- `json:"..."` — `encoding/json` reads these to name the fields in API responses.
- `env:"..."` — `caarlos0/env` read these in Layer 2.

The killer feature: **one struct, two consumers**. Add a field once and both the table
and the JSON automatically gain it.

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
  `user.Role = "banana"`. This is compile-time domain modeling.
- `ID uint \`json:"id" gorm:"primaryKey"\`` — `uint` is a positive integer;
  `primaryKey` makes GORM create an auto-increment primary key.
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

The generated SQL looks roughly like:

```sql
CREATE TABLE users (
  id            BIGSERIAL PRIMARY KEY,
  email         VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role          VARCHAR(20) NOT NULL DEFAULT 'user',
  created_at    TIMESTAMPTZ,
  updated_at    TIMESTAMPTZ
);
CREATE UNIQUE INDEX idx_users_email ON users (email);
```

## ④ Flow Check

```
models.Hero  ──AutoMigrate──▶  heroes table
models.User  ──AutoMigrate──▶  users table
      │
      └── both passed to database.Migrate in main.go
```

## ⑤ Run it

```bash
docker compose up -d postgres
go run cmd/api/main.go
# → Database schema auto-migrated successfully.
```

## ⑤ The Gotcha — Bug #5: only the Hero was migrated

Originally `main.go` called `database.Migrate(db, &models.Hero{})` — the `User` model
was missing. The app started fine, but `/register` crashed with
`relation "users" does not exist` because the table was never created. Migration must
receive **every** model the app uses.

---

# Layer 5 — Security: bcrypt & JWT

## ① The Objective

Build the two security primitives: password hashing (bcrypt) and token
create/validate (JWT). These are pure functions — they know nothing about HTTP or the
database.

## ② The Theory

### Hashing vs encryption
- **Encryption** is two-way (you decrypt with a key).
- **Hashing** is one-way (you cannot recover the input). Passwords are *hashed*, never
  encrypted, so even a leaked database yields no passwords.

### bcrypt
- A deliberately slow hash function. Slow = expensive to brute-force.
- It embeds a random **salt** and the **cost** in the output string, so identical
  passwords produce different hashes, defeating rainbow tables.

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

- `bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)` — hashes.
  `DefaultCost` (10) means ~1024 rounds — the deliberate slowness.
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
  claims plus the standard ones (expiry, issued-at) embedded.
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

## ⑤ The Gotcha — Bug #3: ES256 vs HS256 mismatch

The project originally *signed* with `jwt.SigningMethodES256` while passing a
`[]byte` string secret. ECDSA signing crashed with
`key is of invalid type: ECDSA sign expects *ecdsa.PrivateKey`, and the validator
expected HMAC anyway — so even correct tokens failed. Fix: sign and verify with
**HS256**, and force HMAC in the validator callback.

---

# Layer 6 — User Repository

## ① The Objective

Create the only code that talks to the `users` table: create a user, fetch by ID,
fetch by email.

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
    `INSERT INTO users (email, password_hash, role, ...) VALUES (?, ?, ?, ...)`.
    GORM writes the auto-generated `ID` and timestamps back into the `user` pointer.
  - `errors.Is(err, gorm.ErrDuplicatedKey)` — detects the unique-index violation.
    We convert it into a *domain* message ("user with this email already exists").
    The service (Layer 7) compares this exact string.
- `GetByID` / `GetByEmail`:
  - `First(&user, id)` → `SELECT * FROM users WHERE id = ? LIMIT 1`.
  - `First(&user).Where("email = ?", email)` → same, filtered by email.
  - `errors.Is(err, gorm.ErrRecordNotFound)` → translate to the domain message
    `"user not found"` so the service can distinguish "unknown user" from a real
    database failure.
  - `fmt.Errorf("... %w", err)` for anything else — wraps with context, keeps the
    chain.

## ④ Flow Check

```
AuthService ──▶ UserRepository
                  ├─ Create(INSERT ...)
                  ├─ GetByID(SELECT by pk)
                  └─ GetByEmail(SELECT by email)
```

## ⑤ Run it

Not yet callable — it needs the AuthService + handler. Proceed to Layer 7.

---

# Layer 7 — Auth Service (business logic)

## ① The Objective

Implement the business rules of registration and login: validate input, hash
passwords, check credentials, issue JWTs.

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

- **Sentinel error block** — the four shared errors.
- `type AuthService struct { userRepo repository.UserRepository; jwtSecret string }`
  — the service depends on the repository (interface/value) and the secret.
- `Create`:
  - `email = strings.ToLower(strings.TrimSpace(email))` — sanitize first.
  - `mail.ParseAddress(email)` — stdlib email validation.
  - `len(password) < 8` — minimum strength.
  - **Order matters:** cheap validation runs *before* the expensive bcrypt hash.
  - Build `models.User` with `Role: models.RoleUser` (new accounts are always users).
  - `a.userRepo.Create` — persist. On error: compare `err.Error()` to the repo's
    message to map to `ErrEmailAlreadyExists`. Everything else → wrapped internal
    error.
- `Login`:
  - Both empty-input and wrong-password and unknown-email return
    `ErrInvalidCredentials` — the anti-enumeration guarantee.
  - `security.CheckPasswordHash` — compare provided password against stored hash.
  - `security.GenerateJWT(user.ID, string(user.Role), a.jwtSecret)` — build token.
  - Returns `(token, user, nil)` — the handler needs both.

## ④ Flow Check

```
AuthHandler.Register ──▶ AuthService.Create ──▶ UserRepository.Create ──▶ INSERT
AuthHandler.Login    ──▶ AuthService.Login  ──▶ UserRepository.GetByEmail ──▶ SELECT
                                                ├─ CheckPasswordHash
                                                └─ GenerateJWT → token
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

---

# Layer 8 — Response helpers & Auth Handler

## ① The Objective

Expose `POST /api/v1/auth/register` and `POST /api/v1/auth/login` over HTTP, with a
consistent response envelope and consistent error mapping.

## ② The Theory

- **Response envelope** — every success is `{"data": ...}`. Clients write one generic
  unwrapper. Lists add `"meta"`.
- **Error envelope** — every error is `{"code": "...", "message": "..."}`. `code` is
  stable and machine-readable; `message` is human-readable.
- **Status codes** — `400` = client sent something invalid; `401` = unauthenticated;
  `403` = authenticated but not allowed; `404` = not found; `500` = our fault. We never
  leak internal error details to clients — the real error goes to the server log.

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
- `switch { ... }` — a type-free switch over boolean cases.
- `errors.Is(err, services.ErrHeroNotFound)` → `404 HERO_NOT_FOUND`.
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

- `type authPayload struct { Email, Password string }` — the request body shape.
- `c.ShouldBindJSON(&body)` — parses JSON into the struct. On failure → `400`.
- `h.authService.Create(c.Request.Context(), ...)` — note `c.Request.Context()`:
  the HTTP request context flows into the service and repository.
- The `errors.Is` checks map the auth sentinels to `400`. Everything else →
  `RespondWithError`.
- `RespondWithData(c, http.StatusCreated, user)` — `201 Created` with the user
  (password hash hidden by `json:"-"`).
- `Login` — `401 UNAUTHORIZED` for bad credentials (the anti-enumeration error), else
  `200` with `{"token": ..., "user": ...}`.

### Step 4 — Wire into router and main

Add the auth routes to the final router (already shown in Layer 1) and wire the
dependencies in `main.go`:

```go
userRepo := repository.NewUserRepository(db)
authService := services.NewAuthService(userRepo, cfg.JWT.Secret)
authHandler := handlers.NewAuthHandler(authService)
```

Then pass `authHandler` to `router.SetupRouter(...)`.

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

## ⑤ Run it

```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"password123"}'
# 201 {"data":{"id":1,"email":"alice@example.com","role":"user",...}}

# duplicate → 400
# login → 200 with token
# wrong password / unknown user → 401 (identical response)
```

## ⑤ The Gotcha — Bug #1: `AuthHandler` created with a nil service

`main.go` originally passed `&handlers.AuthHandler{}` to the router — an empty struct
with a nil `authService`. Any call to Register/Login panicked (nil pointer
dereference). Fix: construct the full chain `userRepo → authService → authHandler`.

---

# Layer 9 — Hero Repository

## ① The Objective

Full CRUD for heroes, including a `GetAll` with filtering, search, sorting, and
pagination.

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

- `HeroFilter` — the filter/sort input bag passed from the handler.
- The **interface** — exactly the five operations the service needs.
- `gormHeroRepository` — the unexported concrete implementation (nobody outside this
  package must use it directly).
- `GetAll`:
  - `query := r.db.WithContext(ctx).Model(&models.Hero{})` — base query.
  - `Where(...).Where(...)` — ANDs the name/power filters.
  - The inner `.Where(...).Or(...)` — ORs name/power for the global search.
  - `query.Count(&total)` — filtered count (no Order/Limit/Offset yet).
  - Order clause — `sortBy`/`orderDir` are validated upstream (Layer 10), so building
    the string here is safe; the `, id ASC` tie-breaker keeps ordering deterministic.
  - `.Order(...).Limit(...).Offset(...).Find(&heroes)` — fetch the page.
- `Update` — `Save(hero)` issues an `UPDATE` for every field of the record.
- `Delete` — `Delete(&models.Hero{}, id)` removes the row (hard delete because `Hero`
  has no `DeletedAt`).

## ④ Flow Check

```
HeroService ──▶ HeroRepository (interface)
                  └─ gormHeroRepository ──▶ PostgreSQL
```

## ⑤ Run it

Not yet callable — the service and handlers come next.

---

# Layer 10 — Hero Service

## ① The Objective

Business rules for heroes: validate input, translate GORM errors into domain errors,
validate sort/order against a whitelist, and paginate.

## ② The Theory

- **Validation order** — trim first, then check. `"  "` (whitespace only) must be
  treated as empty.
- **Sort whitelist** — `sort_by` and `order` become SQL fragments in Layer 9. Only
  known values are allowed, which is both validation *and* an injection defense.
- **`offset := (page-1) * limit`** — converts a 1-based page number to SQL offset.
- **GORM error translation** — `errors.Is(err, gorm.ErrRecordNotFound)` → the domain
  sentinel `ErrHeroNotFound`, which the handler maps to `404`. This is what fixes
  "missing hero returns 500".

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

- **The nine sentinel errors** — the full service→handler vocabulary for heroes.
- `allowedSortFields` — a **map used as a set**; `allowedSortFields[x]` is `true` only
  for known columns.
- `Create` — nil check, trim, empty checks, then delegate to the repo.
- `GetByID` — `id == 0` is invalid (a `400`); then translate
  `gorm.ErrRecordNotFound` → `ErrHeroNotFound` (the `404`).
- `GetAll` — trim filters; default `sort_by=id`, `order=asc`; validate both against
  the whitelist; compute `offset`; delegate.
- `Update` — nil/ID checks, trim, empty checks, existence check (translating to
  `ErrHeroNotFound`), then update.
- `Delete` — ID check, existence check (→ `ErrHeroNotFound`), then delete.

## ④ Flow Check

```
HeroHandler ──▶ HeroService
                 ├─ validate
                 ├─ translate gorm.ErrRecordNotFound → ErrHeroNotFound
                 └─ delegate to HeroRepository
```

## ⑤ The Gotcha — Bug #8: missing hero returned 500, not 404

`ErrHeroNotFound` was defined but never returned: the repository wrapped the raw GORM
error, the service re-wrapped it, and the handler's default case produced `500`. The
fix is the `errors.Is(err, gorm.ErrRecordNotFound)` translation in `GetByID`,
`Update`, and `Delete`.

---

# Layer 11 — Hero Handler & Auth Middleware

## ① The Objective

Expose the five hero endpoints (two public, three protected), validate the JWT in the
middleware, and enforce ownership on update/delete.

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
- `GetAll` — `search` falls back to `q`; builds the `HeroFilter`; calls the service;
  **ceiling division** `(total+limit-1)/limit` for `totalPages`; `heroes == nil` →
  empty slice so JSON is `[]`, never `null`.
- `Create`:
  - `c.Get(middleware.ContextUserIDKey)` + **type assertion** `.(uint)` — reads what
    the middleware stored. Failures → `401`.
  - `ShouldBindJSON(&hero)` → `400` on malformed body.
  - **`hero.UserID = userID`** — the mass-assignment defense. Client-provided
    `user_id` is overwritten.
- `GetByID` — parse the `:id` path param; `0` or garbage → `400`.
- `Update`:
  - Fetch → **authorize** (`isOwnerOrAdmin`, else `403`) → bind → copy **only**
    `Name` and `Power` onto the existing record (field allow-listing) → service.
- `Delete` — fetch → authorize (`403`) → delete. Fetch-then-authorize means a missing
  hero gives `404`, a non-owner gives `403`.
- `isOwnerOrAdmin` — admin bypass OR exact owner match, using the *stored* owner ID.

### Step 3 — Wire routes and main

The final `routes.go` (Layer 1) already registers hero routes. Wire dependencies:

```go
heroRepo := repository.NewHeroRepository(db)
heroService := services.NewHeroService(heroRepo)
heroHandler := handlers.NewHeroHandler(heroService)
```

## ④ Flow Check

```
GET  /heroes        → public   → GetAll
GET  /heroes/:id    → public   → GetByID
POST /heroes        → Authenticate → Create  (mass-assignment defense)
PUT  /heroes/:id    → Authenticate → fetch → isOwnerOrAdmin → Update
DELETE /heroes/:id  → Authenticate → fetch → isOwnerOrAdmin → Delete
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

## ⑤ The Gotchas — Bug #2 and Bug #9

**Bug #2 (import cycle):** middleware originally imported `handlers` to reuse
`APIError`, while handlers import middleware → `import cycle not allowed`. Fixed by
removing the handlers import (middleware writes plain `gin.H`).

**Bug #9 (no ownership check on Delete):** `Delete` originally skipped
`isOwnerOrAdmin`, so *any* authenticated user could delete *any* hero. Confirmed by
test: a second user deleted another user's hero with `200`. Fixed by fetch-then-
authorize.

---

# Layer 12 — Docker, `.env`, and full test run

## ① The Objective

Package PostgreSQL with Docker, finalize configuration, and run the complete test
suite against every endpoint.

## ② The Theory

- **Container** — an isolated process with its own filesystem, sharing the host
  kernel. `postgres:17-alpine` is the same database everywhere.
- **Named volume** — `postgres_data` persists the database files across restarts.
- **Healthcheck** — `pg_isready` tells dependent services when Postgres is actually
  ready, not just "started".

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
- `postgres:` — the service name.
- `image: postgres:17-alpine` — the pinned image.
- `environment:` — Compose injects these from our `.env` via `${VAR}`.
- `ports: "${DATABASE_PORT}:5432"` — host port → container port.
- `volumes: postgres_data:/var/lib/postgresql/data` — persistence.
- `healthcheck` — probes readiness.

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

## ⑤ Full Test Suite

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

If either returns `200`, the ownership check is missing — that was Bug #9.

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

**Verify the whole build:**

```bash
cd Heroverse
go build ./...
go vet ./...
go run cmd/api/main.go
```

Congratulations — you built a layered, JWT-secured, PostgreSQL-backed REST API, one
layer and one line at a time.
