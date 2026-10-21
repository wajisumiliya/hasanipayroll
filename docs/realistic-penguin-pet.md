# Realistic Penguin Pet — implementation contract

Status: **implementation groundwork only; not enabled in production**.

## Product
A visually realistic penguin companion for employees. Use licensed/owned high-resolution penguin artwork or a licensed rigged 3D model, not emoji, generic icons or misleading photo cutouts. Animation states: idle breathing, blinking, waddling, swimming, eating fish, resting, playing and sleeping. Include sound toggle and reduced-motion support. Keep it performant on low-end Android hardware and responsive on web.

## Growth
- Egg (days 0–2), chick (days 3–14), juvenile (days 15–44), adult (day 45+). These are **game progression stages**, not biologically accurate penguin maturation.
- Calculate age from server-stored adoption timestamp using UTC server time; never trust the device clock for rewards.
- Growth continues while offline. Last visit does not stop aging.
- Feeding/play raise wellbeing and unlock animations, not payroll/attendance privileges. Never kill the pet or penalize employees for missing work or not logging in.
- All cosmetic spending is virtual. Do not tie pet rewards to real-money gambling, wages, payroll or performance evaluations.

## Database proposal
Use a separate migration after verifying the deployed Neon schema and existing employee identity functions.

```sql
CREATE TABLE IF NOT EXISTS public.employee_penguin_pets (
  employee_id text PRIMARY KEY REFERENCES public.employees(employee_id) ON DELETE CASCADE,
  adopted_at timestamptz NOT NULL DEFAULT now(),
  nickname text NOT NULL DEFAULT 'Pingu',
  last_fed_at timestamptz,
  last_played_at timestamptz,
  equipped_skin text NOT NULL DEFAULT 'classic',
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.employee_penguin_pets ENABLE ROW LEVEL SECURITY;
```

**Do not deploy this sketch as-is.** It intentionally grants no access: migration must add tested employee-scoped RLS and backend RPCs that derive employee identity from a verified JWT, not user-supplied employee IDs.

## API proposal
- `get_my_penguin()`: get-or-create under verified identity; return server timestamp, age, stage, wellbeing, equipped cosmetics and existing crystal balance.
- `feed_my_penguin()`: server-enforced cooldown; update last_fed_at atomically; return authoritative state.
- `play_with_my_penguin()`: server-enforced cooldown; return authoritative state.
- `equip_penguin_item(item_id)`: check ownership; charge existing crystal currency **only via the current authoritative crystal transaction mechanism**, atomically, never client-side.
- Ensure retries and simultaneous taps cannot double-spend crystals or double-claim rewards.

## Flutter
- Create `PenguinPetPage` with realistic layered animated penguin artwork and responsive icy habitat.
- Provide loading, offline cached state, retry and error states.
- Add a named entry to the employee portal without breaking existing bottom navigation.
- Fetch from authenticated Neon backend via existing `NeonApi`/PostgREST adapter.
- Don't introduce an unverified new database connection or hardcoded API secret.

## Acceptance tests
1. Two employees cannot view or modify each other's pets.
2. Branch admins cannot alter employee pet ownership or crystal balance.
3. Growth reflects elapsed server days even after a week offline.
4. Concurrent feed/play/equip requests enforce cooldowns and single crystal debit.
5. Android low-end device runs idle animation smoothly; reduced-motion mode works.
6. App reinstalls retain pet state; no data lost on token refresh.
7. Payroll, attendance, payslips and crystal garden remain unchanged.

## Rollout
Implement database policies and tests, backend RPCs, Flutter screen, real art assets, integration tests, then merge after CI and staging validation. Do not merge this planning branch as a completed feature.
