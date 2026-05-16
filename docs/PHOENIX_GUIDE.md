# Phoenix Project Structure & Database Design Guide

> Today: Get Phoenix running + design database schema  
> Next week: Build web scrapers  
> Timeline: 9 hrs/week, 14 weeks

## Part 1: Phoenix Project Structure

Your Phoenix app (in `plotline/`) is organized into these key directories:

### Web Layer (`lib/plotline_web/`)

- **Controllers**: Handle HTTP requests → return HTML/JSON (rarely used with LiveView)
- **Live Views**: Interactive components that update in real-time without page reload
- **Components**: Reusable HTML/UI building blocks
- **Router**: Defines all URL routes

### Business Logic (`lib/plotline/`)

- **Contexts**: Organize business logic (e.g., `Books`, `Summaries`, `Accounts`)
- **Schemas**: Ecto schemas define database tables as Elixir structs
- **Repo**: Database connection/queries

### Database (`priv/repo/`)

- **Migrations**: SQL-like files that create/modify database tables
- **seeds.exs**: Seed data for development

### Testing (`test/`)

- Unit and integration tests

## Part 2: Database Schema Design for Plotline

### Overview

We need three core tables:

1. **users** — Created by `phx.gen.auth` (user accounts)
2. **books** — Book metadata (title, author, total chapters, source)
3. **user_books** — Reading progress (which user is reading which book, current chapter)
4. **chapter_summaries** — Retrieved summaries from scrapers (chapter, summary text, source URL, date scraped)

### Schema Details

```
users
├── id (primary key)
├── email (string, unique)
├── hashed_password
├── confirmed_at (nullable timestamp for email verification)
└── created_at, updated_at

books
├── id (primary key)
├── title (string)
├── author (string)
├── total_chapters (integer)
├── hardcover_id (nullable string - external ID from Hardcover API)
├── created_at, updated_at

user_books (junction table - tracks reading progress)
├── id (primary key)
├── user_id (foreign key → users)
├── book_id (foreign key → books)
├── current_chapter_number (integer, 0 to total_chapters)
├── unique constraint: (user_id, book_id) — one reading progress per user per book
└── created_at, updated_at

chapter_summaries
├── id (primary key)
├── book_id (foreign key → books)
├── chapter_number (integer)
├── summary_text (text)
├── source_name (string: "SparkNotesAI", "ChapterSummaries.com", "Sparknotes")
├── source_url (string - where we scraped it from)
├── scraped_at (timestamp)
├── unique constraint: (book_id, chapter_number, source_name) — avoid duplicates
└── created_at, updated_at
```

### Migration Files to Create

1. `01_create_books` — Create books table
2. `02_create_user_books` — Create user_books table
3. `03_create_chapter_summaries` — Create chapter_summaries table

(Phoenix's `phx.gen.auth` will create users tables automatically)

### Example Queries You'll Need

```elixir
# Get a user's current progress on a book
user_book = Repo.get_by(UserBook, user_id: user_id, book_id: book_id)
current_chapter = user_book.current_chapter_number

# Get all summaries for a book up to current chapter (spoiler-safe)
summaries = Repo.all(
  from cs in ChapterSummary,
  where: cs.book_id == ^book_id and cs.chapter_number <= ^current_chapter,
  order_by: cs.chapter_number
)

# Get a specific chapter summary from a specific source
summary = Repo.get_by(ChapterSummary,
  book_id: book_id,
  chapter_number: chapter_num,
  source_name: "SparkNotesAI"
)
```

## Part 3: Implementation Plan for Today

### Step 1: Generate Auth System

```bash
cd plotline
mix phx.gen.auth Accounts User users
mix ecto.migrate
```

This creates:

- User schema with email/password
- Authentication context (login, register)
- Database migrations

### Step 2: Create Custom Migrations

Create these migration files in `priv/repo/migrations/`:

- `*_create_books.exs`
- `*_create_user_books.exs`
- `*_create_chapter_summaries.exs`

### Step 3: Create Ecto Schemas

Create schema files in `lib/plotline/`:

- `books.ex` (Book schema)
- `user_books.ex` (UserBook schema)
- `chapter_summaries.ex` (ChapterSummary schema)

### Step 4: Create Contexts

Create logic files in `lib/plotline/`:

- `accounts.ex` (manage users — mostly created by phx.gen.auth)
- `books.ex` (create/list books)
- `summaries.ex` (store/retrieve summaries)

### Step 5: Test Database Connection

```bash
mix ecto.create
mix ecto.migrate
iex -S mix
# In iex:
iex(1)> Plotline.Repo.all(Plotline.Accounts.User)
[]
```

## Part 4: Next Week (Scraper Week)

Once the database is solid, you'll build scrapers:

- SparkNotesAI adapter
- ChapterSummaries.com adapter
- Sparknotes adapter

Each scraper:

1. Takes book title + chapter number
2. Fetches HTML from the website
3. Parses/extracts summary text
4. Stores in `chapter_summaries` table with source provenance

## Quick Command Reference

```bash
# Create new migration
mix ecto.gen.migration create_books

# Run migrations
mix ecto.create     # Create database
mix ecto.migrate    # Run pending migrations
mix ecto.rollback   # Undo last migration

# Start dev server + iex
iex -S mix phx.server

# Run tests
mix test

# Format code
mix format
```

## Notes

- **Constraints**: Keep schema simple for MVP. Avoid soft deletes, versioning until needed.
- **Spoiler safety**: Always filter summaries by `current_chapter_number` when displaying.
- **Source provenance**: Always store which scraper/site the summary came from.
- **No embeddings yet**: Skip vector DB for now. Re-evaluate after MVP demo.

---

Next: Let's create the auth system and design the migrations.
