# Design Decisions — Plotline App

Date: 2026-05-07

Short summary: This document records the design decisions for the whole Plotline web app, including product scope, data model, integrations, retrieval, generation, and UI behavior. Each entry explains what data or constraint led to the decision, what was decided, and why.

## Decisions

### <Decision Title>

- **Data / Context**: (short description of data or constraints that motivate the decision)
- **Decision**: (concise statement of the choice made)
- **Rationale**: (brief reason)
- **Action items**: (optional — concrete next steps)
- **Open items**: (optional — unresolved questions)

## How to use this document

This document stores design choices for the whole web app. Add new entries using the template above and update the "Open items" section as decisions finalize.

## Data Retreival and Summary Generation Decision- 05/07/2026

Plotline will use Hardcover only for book metadata and reading progress, not as a summary source. Chapter summaries will be retrieved from approved summary websites using source-specific adapters, then stored locally in the database with source provenance. The app will only generate recaps from retrieved summaries and will strictly filter summaries up to the user's current chapter.

#### Key Decisions

- Hardcover = metadata/progress tracker only
- Retrieve summaries once, then store locally
- Use source-specific adapters for scraping/normalizing summaries
- AI only rewrites/reformats retrieved summaries
- Strict chapter gating prevents spoilers

#### Immediate Action Items

- Build Hardcover integration
- Create first scraper adapters (SparkNotesAI, ChapterSummaries.com, Sparknotes)
- Design chapter summary database schema
- Implement spoiler filtering
- Create recap-generation prompt

#### Open Items

- Which summary sites are most reliable?
- Should embeddings/vector search be added later?
- How should page/percent progress map to chapters?
- When should EPUB upload support be added?
- If possible, find wiki chapter by chapter summaries through a fan-based wiki website. Could be adapted to each wiki for large fan base book series (brandon sanderson, game of thrones)

## Data Storage Decision - 05/07/2026

For the MVP, Plotline will use Postgres as the primary database and Ecto for schemas/queries. User reading progress will store the current chapter in a `user_books` table, and retrieved chapter summaries will be stored in a `chapter_summaries` table. A vector database is deferred and will only be added later if retrieval needs exceed what the MVP storage/query approach can support.

#### Key Decisions

- Use Postgres for MVP data storage
- Use Ecto for schemas and queries
- Store current chapter in `user_books`
- Store retrieved summaries in `chapter_summaries`
- Skip vector database until needed

#### Immediate Action Items

- Create Ecto migrations for `user_books` and `chapter_summaries`
- Add Ecto schemas and changesets for both tables
- Add indexes for user progress lookups and chapter summary queries

#### Open Items

- Do we need soft deletes for imported summaries?
- What retention/versioning policy should we use for re-scraped summaries?
- Which fields should be required in `chapter_summaries` for source provenance?

## Authentication and User Progress Decision- 05/07/2026

Plotline will use Phoenix's built-in auth generator (`phx.gen.auth`) for login and registration. Reading progress will be stored per user and per book in a `user_books` table, with `current_chapter_number` as the canonical progress field.

#### Key Decisions

- Use `phx.gen.auth` for login/register
- Store reading progress in `user_books`
- Track `current_chapter_number` per user per book

#### Immediate Action Items

- Run `phx.gen.auth` and migrate auth tables
- Add `user_books` migration with user/book relationship and `current_chapter_number`
- Add constraints to ensure one `user_books` row per user/book pair
- Wire progress updates to authenticated user sessions

#### Open Items

- Should guest mode be allowed for demo day, or require login for all features?
- Do we need progress history (not just current chapter) in MVP?
- Should progress updates be manual only, or support page/percent-to-chapter mapping?

