# ADR-0001: Свой IdP в AuthFly вместо Stalwart как issuer

- **Status:** Accepted — In progress (OIDC SSO в проде с 2026-10-29; SAML и собственные креды — позже)
- **Date:** 2026-10-28
- **Deciders:** owner (Smarty Cab)
- **Supersedes / Superseded by:** —
- **Related:** [ADR-0002](0002-free-stalwart-and-webmaster-course.md) — текущий приоритет (Accepted)

> 2026-10-29: решение **принято** владельцем и реализовано для OIDC (AuthFly 0.6.0). История исследования ниже сохранена.
> [ADR-0002](0002-free-stalwart-and-webmaster-course.md) не нарушается: используются только бесплатные возможности Stalwart (`/api/auth`, admin JMAP, `x:AllowedIp`).

## Context

### Текущая архитектура

- AuthFly 0.5.3 — оболочка над Stalwart 1.0.0 на `accounts.example.com`.
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
- Issuer уже `accounts.example.com`, поэтому для RP переход прозрачен: merged JWKS публикует ключи Stalwart и наши собственные ES256-ключи.

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

## Реализация (2026-10-29, AuthFly 0.6.0)

Коммиты `authfly/cli` (main): [30890ab](https://github.com/authfly/cli/commit/30890ab), [5557c87](https://github.com/authfly/cli/commit/5557c87), [0cea735](https://github.com/authfly/cli/commit/0cea735).

- `server/idp` на `github.com/zitadel/oidc/v3` (`pkg/op`): AuthFly — issuer `https://accounts.example.com` (discovery, authorize, token, userinfo, jwks, revoke, introspect, end_session) на прежних путях, RP менять не пришлось.
- Ключи: собственный ES256 KeySet (первый ключ подписывает, все публикуются; готово к ротации). Ключи Stalwart в JWKS больше нет. Секрет — `/root/secrets/authfly-idp-es256.pem` на хосте (600), копия в контейнере `/etc/authfly/secrets/idp-es256.pem`.
- Хранилище: JSON-файл (`/var/lib/authfly/idp.json`, атомарная запись) — auth requests, коды (одноразовые), access/refresh (ротация), SSO-сессии, гранты, профили; переживает рестарт.
- Stalwart остаётся хранилищем учёток: пароль (+TOTP через `mfaRequired`) проверяется адаптером `POST /api/auth` (клиент `authfly-portal`); профиль — admin JMAP. `sub` = OIDC-subject Stalwart (<admin-account> = `2`), маппинг RP не изменился. IP AuthFly (`<authfly-host-ip>/32`) добавлен в `x:AllowedIp` Stalwart, чтобы fail2ban не банил IdP; перебор режет rate limiter AuthFly по IP клиента.
- SSO-сессия = сессия портала (`authfly_session`, HttpOnly, Secure, SameSite=Lax, host-only) + серверная запись со списком клиентов. `prompt=none` / `prompt=login` / `max_age`, `sid` в ID token. Согласие для first-party клиентов запоминается per client (грант).
- Logout (уточнение владельца): выход в приложении (RP-initiated `end_session`) завершает **только это приложение** (его токены в этой сессии отзываются); SSO-сессия и другие приложения живут. Выход на accounts.example.com (или «везде» / «другие сеансы» / завершение сеанса в кабинете) удаляет SSO-сессию, отзывает её токены и рассылает OIDC Back-Channel Logout 1.0 всем приложениям сессии.
- Кабинет «Приложения / Apps» (templ + UI8Kit 3, en/ru): приложения со входом (первый/последний вход, scopes, «Отозвать» → токены + грант + back-channel), активные сеансы (устройство, IP, начало, активность, «Это устройство»), «выйти из всех других», «выйти везде». POST под CSRF.
- `examples/rp`: `POST /auth/backchannel-logout` (подпись, iss, aud, iat, events, sid/sub, без nonce, jti), сессии по `sid`. Второй RP `test.example.com` (клиент `test-yself-link`, unit `rp-test`, :8081).
- Откат: `AUTHFLY_IDP=off` возвращает прокси к Stalwart-issuer; снапшоты `pre-idp-20261029` (web/edge, web/site, mail/authfly, mail/stalwart), бэкапы `authfly-0.5.4.bak`, `rp-0.5.4.bak`, `*.bak-0.5.4`.
- E2E `/root/e2e.py` на хосте: 14/14 PASS.

### Доработки 2026-10-29 (кабинет: грант ≠ сессия приложения)
Коммиты `authfly/cli`: [4cd4f68](https://github.com/authfly/cli/commit/4cd4f68), [2cc29fb](https://github.com/authfly/cli/commit/2cc29fb), [7114f00](https://github.com/authfly/cli/commit/7114f00), [c2205bb](https://github.com/authfly/cli/commit/c2205bb).
- В «Приложениях» разделены грант (разрешение) и сессия приложения: статус «Вход выполнен (· сеансов: N)» / «Не в системе · быстрый вход доступен» по живым сессиям клиента в SSO-сессиях пользователя; RP-initiated logout переводит клиента в «Не в системе».
- «Выйти» — завершает сессии приложения (back-channel по всем sid пользователя, токены отозваны), **грант сохраняется**: следующий вход без пароля.
- «Отозвать» (danger) — удаляет грант и токены, back-channel по всем sid; молчаливый SSO в это приложение запрещён до входа паролем. RP гасит сессии по `sid` или `sub`.
- Все POST кабинета — Post/Redirect/Get (303 + одноразовое flash-сообщение), CSRF; back-channel параллельно с ограниченным ожиданием (2 с на RP, 3 с всего).

### Осталось
- Сейчас все клиенты first-party, поэтому экрана согласия нет; после «Отозвать» повторный вход требует пароль. Когда появятся third-party клиенты (вебмастера), экран согласия станет обязательным: отзыв ведёт к повторному согласию («Приложение X запрашивает доступ к profile, email» → «Разрешить»), пароль — только если нет SSO-сессии. Согласие хранится per client + scopes (новые scopes — новое согласие); флаг `first_party` у клиента пропускает экран.
- SQL-хранилище (Postgres/SQLite) вместо JSON при росте нагрузки; consent-экран для third-party клиентов.
- Ротация ключа по расписанию; SAML; собственные креды/passkeys (lazy migration).
- Сессии портала, созданные до 0.6.0 или magic-link без пароля, получают OIDC `sub` только после первого входа паролем.
