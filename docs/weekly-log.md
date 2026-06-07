# Plotline Weekly Log

Short weekly notes on progress, blockers, and next steps. Same structure each week:

- What is done
- What I am stuck on
- Next task
- Important decisions made

---

## Week: 7

[Updated 2026-06-06]

- What is done:
  - ✅ Database schema verified (books, user_books, chapter_summaries, auth)
  - ✅ Extraction pipeline with adapter behaviour and orchestrator
  - ✅ ChapterSummaries.com adapter — fetches all chapters from one page per book
  - ✅ Catalog sync — 97 books cached locally for availability checks
  - ✅ `Books.add_book_with_summaries!/1` — import all chapters on book add
  - ✅ Live test: *The Strength of the Few* — 80/80 chapters imported
  - ✅ Mix tasks: `plotline.sync_catalog`, `plotline.extract`
  - ✅ All tests passing (131)
- What I am stuck on: Nothing major — need to build the add-book UI next
- Next task: Add-book LiveView — catalog check, import on add, create `user_book` with starting chapter
- Important decisions made:
  - chapter-summaries.com as primary summary source for MVP
  - Import summaries once on book add (not on each chapter update)
  - Local catalog JSON for fast “is this book available?” checks
  - See [decisions.md](decisions.md) — Extraction Adapter Architecture, Chapter Summaries Catalog
