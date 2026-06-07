I am working on a senior project called Plotline.

Project summary:
Plotline is a full-stack web application that helps readers recover story context after pausing a book. Users add a book, track their current chapter, and receive spoiler-free summaries and context limited to chapters they have already read.

Core goal:
This is not just a book tracker. The main feature is a spoiler-aware recall system.

Tech stack:

- Elixir
- Phoenix LiveView
- PostgreSQL
- GitHub

MVP:

- Add/manage books
- Track current chapter
- Store chapter-level summaries
- Filter summaries by current chapter
- Display spoiler-safe recall output

Current constraints:

- About 9 hours per week
- 14-week timeline
- Must be demoable, not perfect
- Small manually curated dataset is acceptable
- Avoid scraping restricted sites

Current priority:
Build the add-book flow (catalog check → import summaries → track progress). Then spoiler-safe recall UI.

When helping me:

- Keep answers concise and actionable
- Ask only necessary clarifying questions
- Help me decide what to work on next
- Warn me if I am scope creeping
- Prefer MVP-first implementation
- Explain concepts at a beginner-to-novice Phoenix/Elixir level

Current project status:
[Updated 2026-06-06]

For ongoing week-by-week notes, see [weekly-log.md](weekly-log.md).

Requirements specification (CSE 499): [requirements.md](requirements.md).

## What is in the codebase now (extraction)

- **Extraction pipeline** (`Plotline.Extraction`) — orchestrates fetch + store into `chapter_summaries`
- **Adapter behaviour** (`Plotline.Extraction.Adapter`) — one module per summary source; all return the same normalized shape
- **Adapters implemented**:
  - `JsonFile` — curated offline demo data in `priv/data/extraction/`
  - `ChapterSummaries` — primary source: [chapter-summaries.com](https://chapter-summaries.com)
  - `Sparknotes` — skeleton for live SparkNotes fetching (secondary)
- **Catalog** (`ChapterSummaries.Catalog`) — tracks all 97 books on chapter-summaries.com; synced to `priv/data/chapter_summaries_catalog.json`
- **Book add flow** — `Books.add_book_with_summaries!/1` looks up title/author in catalog, creates book, imports all chapters once
- **Availability check** — `Books.chapter_summaries_available?/2` before import (fast, uses cached catalog)
- **Mix tasks** — `mix plotline.sync_catalog`, `mix plotline.extract --book-id ID --adapter chaptersummaries`
- **DB** — `books.chapter_summaries_slug` stores the chapter-summaries.com slug per book
- **Import strategy** — summaries imported once on book add; spoiler safety at read time via `Summaries.get_summaries_up_to/2`

## Week: 3

- What is done:
  - ✅ Planning stage for initial project
  - ✅ Created plan on where to get data from (for demo purposes only, not selling the app)
  - ✅ Decided on database design/schema design
  - ✅ App will have user authentication
- What I am stuck on: Nothing yet!
- Next task: Initialize pheonix project structure, decide on final database schema
- Important decisions made:
  - see [Decisions markdown file](decisions.md)

## Week: 4

- What is done:
  - ✅ Phoenix project initialized with LiveView
  - ✅ Created PHOENIX_GUIDE.md with project structure explanation
  - ✅ Designed database schema (users, books, user_books, chapter_summaries)
  - ✅ Created implementation roadmap
- What I am stuck on: Nothing yet!
- Next task: Generate auth system with `phx.gen.auth`, create migrations
- Important decisions made:
  - Use `phx.gen.auth` for login/register (no custom auth from scratch)
  - Store chapter summaries with source provenance (book_id, chapter_number, source_name are unique)
  - Spoiler safety via chapter filtering on read, not at storage time

## Week: 7

See [weekly-log.md](weekly-log.md#week-7).
