# Capability: Mobile UI

## Overview

Material 3 Flutter app (iOS + Android). Screens: Home, Ask, Page detail, Search, Inbox, Sources, Settings. Clean knowledge-first design with status color coding.

## Requirements

- **REQ-1** Home: wiki header, quick actions (Ask, Import source, Inbox with pending-count badge), recent pages, global search bar.
- **REQ-2** Ask: conversation-style; streaming-free simple response; answer rendered with markdown; citation chips (tappable → page); "Save to wiki" → creates draft bundle → inbox.
- **REQ-3** Page detail: markdown body rendered; claims section listing claim cards with status badge + evidence quotes; deprecated claims muted/struck.
- **REQ-4** Inbox: pending draft bundles; inline op preview (first 3 ops + count); Accept / Reject buttons; corroboration note when run; force-accept for `needs_review` bundles.
- **REQ-5** Sources: list with title, version, content_hash (short), imported_at; Import button (file picker) triggers compile (Flow A) with snackbar progress feedback.
- **REQ-6** Settings: OpenRouter API key (secure storage), primary + corroboration model pickers, wiki path info, Export button, Rebuild index button.
- **REQ-7** Status colors: `unverified` amber ⚠, `supported` blue, `cross_checked` purple, `human_verified` green ✓, `contradicted` red, `deprecated` grey (struck).
- **REQ-8** Empty states everywhere (no pages yet, no inbox items, no sources).
- **REQ-9** AdMob banner ads at the bottom of Home and Page detail screens; never on Ask (AdMob restricts LLM-generated content). Android uses production ad units (`useTestAds=false`); iOS stays on test IDs until an iOS AdMob app exists.

## Behavior

- Errors from AI/import shown as SnackBars, never silent.
- All destructive actions confirm.
