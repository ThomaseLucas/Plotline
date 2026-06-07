# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
alias Plotline.{Books, Extraction, Repo}

demo_book_attrs = %{
  title: "Pride and Prejudice",
  author: "Jane Austen",
  total_chapters: 61,
  hardcover_id: "sparknotes:pride-and-prejudice"
}

book =
  case Repo.get_by(Plotline.Books.Book, title: demo_book_attrs.title, author: demo_book_attrs.author) do
    nil ->
      {:ok, book} = Books.create_book(demo_book_attrs)
      book

    book ->
      book
  end

case Extraction.import_book(book.id, "json") do
  {:ok, stats} ->
    IO.puts("Seeded #{stats.imported} chapter summaries for #{book.title}.")

  {:error, reason} ->
    IO.puts("Failed to seed summaries: #{inspect(reason)}")
end
