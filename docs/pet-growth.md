# Appearance and pet growth

The first onboarding screen collects the pet name, fur and collar together.
Fur and collar are free choices. Fur stays fixed after onboarding; the pencil
beside the pet name opens an editor for both name and collar, on home and care
screens. The editor previews the selected collar on the saved fur and age,
persists both fields together and keeps the form open after a save failure.
A missing or unknown collar renders
as red; a missing or unknown fur renders as gray.

`catAsset` resolves stage, fur, collar and mood to one of 135 optimized WebP
files under `assets/Cat/stages`. Only the new asset folders are bundled; the
older source artwork remains in the repository but is not bundled. The output
is 17.53 MiB at quality 84 with a maximum size of 768 × 1152. Original PNGs are
not modified. `tool/prepare_pet_assets.py` reproduces the conversion from the
sorted source directory (requires Pillow).

Transparent margins are trimmed during conversion. Home and care scenes anchor
the artwork at the bottom and constrain its width. Visible height multipliers
are 0.76 for a kitten, 1.0 for the middle stage and 1.12 for an adult. Tap reaction
art uses the same stage, fur and collar; the existing breathing motion and purr
remain in place. Park and Tugriki dialogues also receive the saved appearance.

The backend remains authoritative for growth. Its existing rule advances the
pet after three consecutive successful game periods, at most to stage 3. This
change does not change income, rewards, purchases or this progression rule.
The app parses `petStageBefore` and `petStageAfter` from the persisted day
summary. After the summary, a stage increase opens the existing transformation
screen with the pet's saved name and both age images. There is no new progress
counter or player-facing age selector. Reopening the app uses the persisted
stage and does not replay a growth animation just because the home refreshed.

The map's dedicated walking and idle sprites keep their existing appearance;
age/collar variants for those poses do not exist. They are not replaced with
front-facing illustrations.

## Database and API rollout

Apply `0035_pet_collar_options.sql` before using collar IDs in the new client.
The migration adds only three cosmetic catalog entries and is replay-safe.
It does not backfill or reset existing pets. Server health now requires it.
Onboarding status includes `accessoryOptionId` for interrupted flow recovery.
`POST /pet` and `PUT /pet` lock the authenticated child's profile before an
identity write; changing fur after onboarding returns
`409 pet_appearance_locked`. Changing the collar to one of the three known
collar IDs is allowed; an invalid replacement returns `400 invalid_collar_option`.
Name-only updates with the saved appearance remain valid. The profile lock also serializes identity writes against onboarding
completion. A persistent age is never accepted from the client.

## Local review

`flutter run -d web-server --web-port 8133 -t lib/main_pet_growth_preview.dart`
opens an independent visual preview with no game API or wallet writes. Complete
the first screen to see the chosen pet, or use the preview-only “Возрасты”
button. The age switches and transformation button exist only in this entry
point. `lib/main.dart` retains the ordinary server-driven flow.

Visual review: Chrome, 390 × 844, default text scale; onboarding, collar choices
and all three base poses. Widget checks additionally cover 320 × 568 with
enlarged text, age ordering, common baseline, all 135 asset paths, server-driven
celebration and preserving the selected collar.

Android device rendering still needs validation on a machine with Android SDK.
Full migration replay needs disposable PostgreSQL; Docker was not running on
the development machine, so database integration tests were not executed.

## Integration base

The publishing branch is based on main `0457a86` (offline support). It preserves
the current tutorial budget and first-day income, spendable balance rules,
dictionary, text scaling, pet-stroking joy and the updated star/white-glow
transition. Pet evolution uses the existing home-room background and the
continue button has no rocket emoji. Offline growth remains server-authoritative
and is not predicted locally.
