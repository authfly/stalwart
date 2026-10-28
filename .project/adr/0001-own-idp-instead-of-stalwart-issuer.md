# ADR-0001: Свой IdP в AuthFly вместо Stalwart как issuer

- **Status:** Deferred (отложено)
- **Date:** 2026-10-28
- **Deciders:** owner (Smarty Cab)
- **Supersedes / Superseded by:** —
- **Related:** [ADR-0002](0002-free-stalwart-and-webmaster-course.md) — текущий приоритет (Accepted)

> Решение **отложено**. Документ фиксирует результаты исследования и план на случай, если к теме вернёмся.
> Сейчас действует [ADR-0002](0002-free-stalwart-and-webmaster-course.md): работаем только на бесплатных (non-Pro) возможностях Stalwart.

## Context

### Текущая архитектура

- AuthFly 0.5.3 — оболочка над Stalwart 1.0.0 на `accounts.yself.link`.
- Stalwart выполняет роль account store и OIDC issuer: подпись токенов ES256, PKCE S256.
- AuthFly проксирует discovery, token, userinfo, jwks, revoke и logout.
- Multi-tenancy в Stalwart доступна только в Pro (Enterprise).
- В модели Stalwart нет настоящего SSO между разными RP (relying parties).

### История

- В истории `authfly/cli` своего IdP никогда не было: с первого коммита `46b84a0` и в тегах `v0.4.0` / `v0.4.1` AuthFly проксирует Stalwart 0.16.
- Более ранний PoC — [`fastygo/idp`](https://github.com/fastygo/idp) + [`fastygo/oidc-hanko`](https://github.com/fastygo/oidc-hanko) (Hanko как credential store). Он до сих пор описан на authfly.vercel.app.

### Оценка `fastygo/oidc-hanko`

- Содержит только `Dockerfile` (`hanko:latest`, версия не закреплена) и `hanko-config.yaml`.
- Переиспользовать нечего, кроме идеи «credential backend за SPI».

### Оценка `fastygo/idp`

Go + templ + UI8Kit 0.2.5, MIT, ~5.2k LOC. Не развивается с 2026-04-17; тесты проходят на go1.27.

Что хорошо:

- Продуманный SPI в `pkg/core`: `Identity`, `Credential`, `CodeStore`, `SessionStore`, `TokenRevoker`, `Features`.
- Front-channel и back-channel logout.
- Introspect и revoke.
- `pkg/authkit`.

Почему не production:

- JWT написан вручную: только RS256, без ротации ключей.
- XMLDSig и C14N для SAML написаны вручную.
- Только in-memory stores.
- PKCE необязателен и допускает `plain`.
- Нет refresh tokens.
- Нет MFA и passkeys.
- Нет organizations.
- SAML: только SP-initiated через redirect binding, нет SLO.

## Decision

**Отложено.** Если к теме вернёмся, план такой.

- IdP растёт **внутри `authfly/cli`** как пакет (например, `server/idp`), а не отдельным сервисом.
- Из `fastygo/idp` **берём**: SPI, логику logout, тесты как спецификацию.
- Из `fastygo/idp` **не берём**: самописную криптографию, XML-подпись, in-memory stores и `plain` PKCE.
- Стек:
  - OIDC/OAuth core — `zitadel/oidc` (пакет `op`) или `ory/fosite`;
  - SAML — `crewjam/saml` + `russellhaering/goxmldsig`;
  - passkeys — `go-webauthn/webauthn`;
  - хранилище — Postgres (SQLite для single-node).
- Issuer уже `accounts.yself.link`, поэтому для RP переход прозрачен: merged JWKS публикует ключи Stalwart и наши собственные ES256-ключи.

### Фазы

| Phase | Содержание |
|---|---|
| **P0** | Заморозить контракт для RP: issuer, endpoints, claims, `sub` = Stalwart account id. Прогнать OIDC conformance suite. |
| **P1** | Каркас за feature flag. Собственные ES256-ключи с `kid` и перекрытием при ротации. Merged JWKS. SQL store для codes, sessions и refresh (ротация + reuse detection). Аутентификация пока делегирована Stalwart. |
| **P2** | Собственная выдача токенов, переключение per-client. PKCE S256 обязателен. Refresh, consent, logout. Dynamic clients в БД. Маппинг `sub`. |
| **P3** | Organizations, memberships, roles и groups. Claims `org_id` / `roles`. Invites (на базе `invite.go`). Domain verification. Admin API в стиле WorkOS. Org switcher в AuthKit widgets. Audit в SQL. |
| **P4** | Enterprise SSO: SAML IdP per org (SP- и IdP-initiated, SLO). Собственный credential store (password hash, passkeys). SCIM. Stalwart становится mail/optional backend. |

## Consequences

### Риски

- Самописная криптография, если код скопируют из `fastygo/idp` «как есть».
- Миграция `sub` и паролей. Хэши паролей, вероятно, нельзя выгрузить через API Stalwart [?], поэтому нужна lazy migration при логине.
- HA и состояние: появляется своё stateful-хранилище, которое нужно резервировать.
- Нужны security review и OIDC conformance.
- Период двойной поддержки (Stalwart issuer + собственный issuer).
- Scope creep: риск начать строить «весь WorkOS».
- Изменения API в Stalwart 1.x.

### Триггер пересмотра

Вернуться к ADR, когда:

- бесплатных возможностей Stalwart не хватает для обязательного кейса (tenancy, SSO между RP), **или**
- это потребуется курсу или продукту (см. [ADR-0002](0002-free-stalwart-and-webmaster-course.md)).

## Links

- [ADR-0002: Приоритет — бесплатный Stalwart + AuthFly и курс для вебмастеров](0002-free-stalwart-and-webmaster-course.md)
- [authfly/cli](https://github.com/authfly/cli): `server/core` (JMAP-клиент Stalwart, `Harden`, `init-stalwart`)
- [fastygo/idp](https://github.com/fastygo/idp), [fastygo/oidc-hanko](https://github.com/fastygo/oidc-hanko) — ранний PoC
- https://authfly.vercel.app — сайт; сейчас описывает старый PoC
- `zitadel/oidc`, `ory/fosite`, `crewjam/saml`, `russellhaering/goxmldsig`, `go-webauthn/webauthn`
- [docs/stalwart-api.md](../../docs/stalwart-api.md) — аудит JMAP management API (Enterprise-only объекты)
