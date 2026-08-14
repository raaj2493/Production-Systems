# Heroverse API Testing & Fixes

This document records the end-to-end API testing performed on the Heroverse application
and every bug that was found and fixed during the process.

## Setup Used for Testing

- PostgreSQL 17 via `docker compose up -d postgres`
- API started with `SERVER_PORT=8081` (8080 was occupied by another app)
- JWT secret from `.env` / default config

## Endpoint Test Results (all passing after fixes)

| Endpoint | Method | Auth | Result |
|---|---|---|---|
| `/health` | GET | No | `200 {"status":"ok"}` |
| `/api/v1/auth/register` | POST | No | `201` with user |
| `/api/v1/auth/register` (duplicate email) | POST | No | `400 INVALID_INPUT` |
| `/api/v1/auth/register` (invalid email) | POST | No | `400` |
| `/api/v1/auth/register` (weak password) | POST | No | `400` |
| `/api/v1/auth/login` | POST | No | `200` with JWT |
| `/api/v1/auth/login` (wrong password) | POST | No | `401` |
| `/api/v1/auth/login` (unknown user) | POST | No | `401` (no enumeration) |
| `/api/v1/heroes` (GET) | GET | No | `200` paginated list |
| `/api/v1/heroes?name=&power=&search=&q=&sort_by=&order=&page=&limit=` | GET | No | `200` |
| `/api/v1/heroes/:id` (GET) | GET | No | `200` |
| `/api/v1/heroes/:id` (missing) | GET | No | `404 HERO_NOT_FOUND` |
| `/api/v1/heroes/:id` (invalid id) | GET | No | `400` |
| `/api/v1/heroes` (POST) | POST | Bearer | `201` |
| `/api/v1/heroes` (POST, no token) | POST | None | `401` |
| `/api/v1/heroes` (POST, bad token) | POST | Bearer | `401` |
| `/api/v1/heroes` (POST, empty name/power) | POST | Bearer | `400` |
| `/api/v1/heroes/:id` (PUT, owner) | PUT | Bearer | `200` |
| `/api/v1/heroes/:id` (PUT, non-owner) | PUT | Bearer | `403 FORBIDDEN` |
| `/api/v1/heroes/:id` (PUT, missing) | PUT | Bearer | `404` |
| `/api/v1/heroes/:id` (DELETE, owner) | DELETE | Bearer | `200` |
| `/api/v1/heroes/:id` (DELETE, non-owner) | DELETE | Bearer | `403 FORBIDDEN` |
| `/api/v1/heroes/:id` (DELETE, missing) | DELETE | Bearer | `404` |
| Invalid `sort_by` / `page` / `limit` | GET | No | `400` |
| Unknown route | any | - | `404` |

## Bugs Found & Fixed

### 1. `AuthHandler` created without its dependencies (nil service)
`cmd/api/main.go` passed `&handlers.AuthHandler{}` to the router, so `authService`
was nil and any register/login call panicked or failed.
**Fix:** Initialize `userRepo` → `authService` → `authHandler` and pass the real instance.

### 2. Circular import between `handlers` and `middleware`
`middleware/auth-middleware.go` imported `handlers` (for `APIError`) while
`handlers/hero-handler.go` imports `middleware` → import cycle, app would not build.
**Fix:** Removed the `handlers` import from the middleware; it now responds with `gin.H` maps.

### 3. JWT signing method mismatch / unusable signing
`GenerateJWT` used `ES256` (ECDSA) but passed a `[]byte` secret. ECDSA requires an
`*ecdsa.PrivateKey`, so token generation failed at login:
`key is of invalid type: ECDSA sign expects *ecdsa.PrivateKey`. The validator also
expected HMAC, so even a valid token would not parse.
**Fix:** Sign with `HS256` (HMAC, works with a byte secret) and validate the same way.

### 4. Error-message comparisons in `AuthService` could never match
`Create`/`Login` compared repository errors via `errors.Is(err, errors.New("..."))`.
`errors.New` creates a *new* error each call, so equality always failed → duplicate
registration returned `500` instead of `400`, and "user not found" was not detected.
Also the repository messages were inconsistent (`"User exist "` vs
`"user with this email already exists"`, `"User not Found"` vs `"user not found"`).
**Fix:** Compare `err.Error()` strings and normalized repository messages to `"user not found"`.

### 5. `users` table never migrated
`main.go` only auto-migrated `&models.Hero{}`, so `users` did not exist and register
failed with `relation "users" does not exist`.
**Fix:** Migrate `&models.Hero{}, &models.User{}`.

### 6. Duplicate-key error not translated to `gorm.ErrDuplicatedKey`
The repository checks `errors.Is(err, gorm.ErrDuplicatedKey)`, but GORM only returns
that sentinel when `TranslateError` is enabled in the dialector config. Without it the
raw driver error fell through to a `500`.
**Fix:** Set `TranslateError: true` in `gorm.Config` (in `internals/database/db.go`).

### 7. Database driver mismatch — sqlite used with a PostgreSQL DSN
`internals/database/db.go` opened **sqlite** using `sqlite.Open(cfg.DSN())` where `DSN()`
emits a PostgreSQL connection string (sqlite treated it as a filename). This contradicted
`docker-compose.yml` and the README (PostgreSQL). It silently ran against a garbage file.
**Fix:** Use `gorm.io/driver/postgres` with `postgres.Open(cfg.DSN())`.

### 8. Hero not found returned `500` instead of `404`
`ErrHeroNotFound` was never returned anywhere; the repository wrapped the raw
`gorm.ErrRecordNotFound` and the error mapper fell through to `500`.
**Fix:** In `HeroService.GetByID`, `Update`, and `Delete`, map
`errors.Is(err, gorm.ErrRecordNotFound)` → `ErrHeroNotFound` (404).

### 9. `DELETE /heroes/:id` had no ownership check
Any authenticated user could delete any hero (only `Update` checked ownership). This was
confirmed with a non-owner successfully deleting someone else's hero.
**Fix:** `HeroHandler.Delete` now fetches the hero and enforces `isOwnerOrAdmin` before
deleting, returning `403` otherwise.

## How to Run

```bash
docker compose up -d postgres   # start PostgreSQL
go run cmd/api/main.go           # run the API (default port 8080)
```
