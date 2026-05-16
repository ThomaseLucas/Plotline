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
Help me make practical progress toward a working demo. Do not overcomplicate the project. Favor simple, buildable solutions.

When helping me:

- Keep answers concise and actionable
- Ask only necessary clarifying questions
- Help me decide what to work on next
- Warn me if I am scope creeping
- Prefer MVP-first implementation
- Explain concepts at a beginner-to-novice Phoenix/Elixir level

Current project status:
[Updated 2026-05-14]

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
