# ADR-0002: Приоритет — бесплатный Stalwart + AuthFly и курс для вебмастеров

- **Status:** Accepted
- **Date:** 2026-10-28
- **Deciders:** owner (Smarty Cab)
- **Related:** [ADR-0001](0001-own-idp-instead-of-stalwart-issuer.md) — свой IdP (Deferred, отложенная альтернатива)

## Context

- AuthFly 0.5.3 работает как оболочка над Stalwart 1.0.0 (`accounts.yself.link`). Stalwart отвечает за account store и OIDC issuer, AuthFly проксирует OIDC endpoints.
- Multi-tenancy и часть объектов Stalwart (`x:Metric`, `x:Trace`, `x:ArchivedItem`, `x:MaskedEmail`) доступны только в Pro/Enterprise (см. [docs/stalwart-api.md](../../docs/stalwart-api.md)).
- Альтернатива — собственный IdP ([ADR-0001](0001-own-idp-instead-of-stalwart-issuer.md)). Она дорогая и рискованная (crypto, миграция, conformance), поэтому отложена.

Слова owner (2026-10-28), кратко:

> Пока полностью погружаемся в бесплатные возможности Stalwart. Нужно не просто сделать для себя, а подготовить полноценный курс с harness-агентами и гайдами для 9 targets. Любой вебмастер без опыта в SRE должен суметь запустить свою self-hosted систему авторизации, в том числе с отключением телеметрии и обновлений, и в целом научиться закрывать требования юрисдикции своей страны. Приоритет сейчас именно такой.

## Decision

1. **Основа — только бесплатные (non-Pro) возможности Stalwart.** Stalwart Pro не используем и не требуем.
2. **Продукт:** собственный authorization server с единым входом (SSO) на 9 targets (целевое состояние; сейчас SSO между RP нет — см. known limitation в Consequences), «под ключ». Вебмастер вместе с агентом справляются сами, без подрядчиков.
3. **Модель organizations без Stalwart Pro:**
   - у каждого вебмастера своя organization: участники (members), roles, invites и OIDC clients для его сайтов;
   - пользователи лежат в одном общем пуле Stalwart;
   - принадлежность к organization AuthFly хранит в своей БД и добавляет в токен через claim `org`.
4. **Курс** для вебмастеров без опыта SRE: гайды + harness для агентов, по каждому из 9 targets.
5. **Сайт AuthFly** (authfly.vercel.app; будет переписан, сейчас описывает старый PoC `fastygo/idp`) целиком посвящён объяснениям, развёртыванию и интеграциям, плюс **compliance audit robot** (проверка соблюдения законов и т. п.).

## Consequences

### Структура курса (набросок)

| # | Module | Содержание |
|---|---|---|
| 1 | Host basics | Сервер/VPS, Incus (контейнеры), DNS, TLS, firewall, SSH-ключи. |
| 2 | Stalwart: install & hardening | Установка, `init-stalwart` / `Harden` из `authfly/cli`, отключение web UI (`x:Application.enabled=false` + `UpdateApps`). Отключение телеметрии и проверки обновлений — **какие именно настройки Stalwart это контролируют, пока не проверено [?]**. |
| 3 | AuthFly deploy | `npx authfly` / `authfly deploy`, docker или incus, policy packs (GDPR / 152-FZ). |
| 4 | OIDC client integration | По одному уроку на каждый target (см. ниже): PKCE S256, проверка ID token, logout. |
| 5 | Organizations & invites | Organization, members, roles, invites, OIDC clients сайтов; claim `org`. |
| 6 | Backups 3-2-1 | Бэкап Stalwart и БД AuthFly по правилу 3-2-1, регулярная проверка restore. |
| 7 | SLO & monitoring | Целевые SLO (availability, latency логина), health checks, алерты на free-функциях (Prometheus endpoint `/metrics/prometheus` — доступность в free-сборке не подтверждена [?]). |
| 8 | Jurisdiction | Checklist: GDPR, 152-FZ, локализация данных, retention (`x:DataRetention`), согласия; методика «как закрыть требования своей страны». |
| 9 | Admin via SSH tunnel | Управление: Console и admin API только через loopback / SSH tunnel, без публичной админки. |

### Harness для агентов

- Для каждого модуля — сценарий, который агент выполняет вместе с вебмастером: проверки до и после шага, rollback, критерии «готово».
- Опора на существующие проверки репозиториев: `tools/e2e-compat.sh`, аудит API (`tools/stalwart-audit.py`), contract tests `authfly/authfly`.
- Compliance audit robot на сайте использует те же checklists из модуля 8.

### 9 targets

**9 targets: 5 UI-фреймворков и 4 серверных шаблонизатора** (на лендинге: «одна система, 9 платформ»; EN: *9 targets: 5 UI frameworks and 4 server-side template engines* / *One system, 9 platforms*). Список совпадает с [authfly/authkit](https://github.com/authfly/authkit) и [ui8kit/codegen](https://github.com/ui8kit/codegen).

UI-фреймворки:

1. React — `@authfly/react`
2. Vue 3 — `@authfly/vue`
3. Svelte 5 — `@authfly/svelte`
4. Solid — `@authfly/solid`
5. Web Components — `@authfly/webcomponent`

Серверные шаблонизаторы:

6. templ (Go) — `github.com/authfly/authkit/packages/ui/templ`
7. Twig (PHP) — `authfly/twig`
8. Latte (PHP) — `authfly/latte`
9. Jinja2 (Python) — `authfly-jinja2`

Термин — **target** (render target), а не runtime или framework: templ, Twig, Latte и Jinja2 — серверные шаблонизаторы, а не runtimes; а «framework» не покрывает Web Components и шаблонизаторы. Twig и Latte — отдельные targets (по уроку на каждый). Серверные SDK (`authfly/authfly`: TS, Go, Python, PHP) — отдельная ось, к ним относятся уроки модуля 4.

### Прочие последствия

- **Known limitation (для курса):** в AuthFly 0.5.3 поверх Stalwart нет настоящего SSO между relying parties. Каждая авторизация RP проходит через `/api/auth` Stalwart и снова запрашивает пароль. Настоящий единый вход между сайтами требует, чтобы AuthFly держал собственную сессию и сам выдавал authorization codes, то есть [ADR-0001](0001-own-idp-instead-of-stalwart-issuer.md) (Deferred). В курсе это ограничение описываем явно.
- В AuthFly появляется своя БД (organizations, memberships, invites, clients): её нужно включить в бэкапы и миграции.
- Dev stack в этом репозитории использует Stalwart v0.16, production — 1.0.0; гайды пишем под 1.x, compat e2e нужно держать на актуальной версии [?].
- Возврат к [ADR-0001](0001-own-idp-instead-of-stalwart-issuer.md) — по его триггеру (free-функций Stalwart не хватает для обязательного кейса или это нужно курсу/продукту).

## Links

- [ADR-0001: Свой IdP в AuthFly вместо Stalwart как issuer](0001-own-idp-instead-of-stalwart-issuer.md) — Deferred
- [authfly/authkit](https://github.com/authfly/authkit) — widgets для 9 targets
- [authfly/authfly](https://github.com/authfly/authfly) — contract, providers, server SDKs
- [authfly/cli](https://github.com/authfly/cli) — `npx authfly`, deploy, policy packs GDPR/152-FZ
- [docs/stalwart.md](../../docs/stalwart.md), [docs/stalwart-api.md](../../docs/stalwart-api.md)
- https://authfly.vercel.app — сайт (будет переписан)
