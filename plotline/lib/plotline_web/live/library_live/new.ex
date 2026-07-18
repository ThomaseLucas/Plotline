defmodule PlotlineWeb.LibraryLive.New do
  use PlotlineWeb, :live_view

  alias Plotline.BookRequests
  alias Plotline.BookRequests.BookRequest
  alias Plotline.Books
  alias Plotline.CatalogSync
  alias Plotline.Extraction.Adapters.ChapterSummaries.Catalog

  @page_size 9

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Add Book")
     |> assign(:search, "")
     |> assign(:importing, false)
     |> assign(:syncing_catalog, CatalogSync.syncing?())
     |> assign(:request_form, request_form(%{}))
     |> assign_catalog_page(Books.search_catalog(""), 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div>
          <Layouts.back_link navigate={~p"/library"}>← Back to library</Layouts.back_link>
          <h1 class="mt-2 text-2xl font-bold text-[#212121]">Add a book</h1>
          <p class="mt-1 text-sm text-[#212121]/70">
            Browse books Plotline supports via chapter-summaries.com. Only titles in this catalog can be added with spoiler-safe summaries.
          </p>
          <p id="catalog-size" class="mt-2 text-sm font-medium text-[#2F5C43]">
            {catalog_summary(@catalog_size, @search, @catalog_entries)}
          </p>
        </div>

        <div class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h2 class="text-lg font-bold text-[#212121]">Available books</h2>
            <p class="mt-1 text-sm text-[#212121]/70">
              Search by title or author, then click Add on any match.
            </p>
          </div>
          <button
            id="reload-catalog-button"
            type="button"
            phx-click="reload_catalog"
            disabled={@syncing_catalog or @importing}
            class="inline-flex items-center gap-2 rounded-lg border border-[#2F5C43] bg-white px-4 py-2 text-sm font-semibold text-[#2F5C43] transition hover:bg-[#2F5C43]/10 disabled:cursor-not-allowed disabled:opacity-60"
          >
            <.icon name="hero-arrow-path" class={["size-4", @syncing_catalog && "motion-safe:animate-spin"]} />
            Reload catalog
          </button>
        </div>

        <%= if @syncing_catalog do %>
          <div id="catalog-sync-indicator" class="flex items-center gap-2 text-sm text-[#2F5C43]">
            <.icon name="hero-arrow-path" class="size-4 motion-safe:animate-spin" />
            Updating the book list from chapter-summaries.com…
          </div>
        <% end %>

        <form id="catalog-search-form" phx-change="search" phx-submit="search">
          <.input
            name="search"
            value={@search}
            type="search"
            label="Search by title or author"
            placeholder="e.g. Pride and Prejudice"
            phx-debounce="200"
            class="w-full rounded-lg border-0 bg-white px-4 py-3.5 text-[#212121] shadow-md placeholder:text-[#212121]/40 focus:outline-none focus:ring-2 focus:ring-[#74AC8D]"
          />
        </form>

        <%= if @importing do %>
          <div id="importing-indicator" class="flex items-center gap-2 text-sm text-[#2F5C43]">
            <.icon name="hero-arrow-path" class="size-4 motion-safe:animate-spin" />
            Importing chapter summaries… this may take a moment.
          </div>
        <% end %>

        <ul id="catalog-results" class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <li
            :for={entry <- @catalog_results}
            id={"catalog-#{entry.slug}"}
            class="flex flex-col overflow-hidden rounded-xl bg-white shadow-md transition hover:shadow-lg"
          >
            <img
              src={Catalog.cover_image_url(entry)}
              alt={"#{entry.title} cover"}
              loading="lazy"
              class="aspect-[2/3] w-full bg-[#F2E8CF] object-cover"
            />
            <div class="flex flex-1 flex-col gap-2 p-4">
              <div class="min-w-0 flex-1">
                <p class="font-semibold leading-snug text-[#212121]">{entry.title}</p>
                <p class="mt-1 text-sm text-[#212121]/70">{entry.author}</p>
                <p class="mt-1 text-xs text-[#212121]/50">{entry.total_chapters} chapters</p>
              </div>
              <Layouts.brand_submit
                id={"add-book-#{entry.slug}"}
                type="button"
                phx-click="add"
                phx-value-title={entry.title}
                phx-value-author={entry.author}
                disabled={@importing or @syncing_catalog}
                class="w-full px-3 py-2"
              >
                Add
              </Layouts.brand_submit>
            </div>
          </li>
        </ul>

        <%= if @catalog_entries == [] and @search != "" do %>
          <p id="catalog-no-results" class="text-sm text-[#212121]/70">
            No catalog matches for "{@search}".
          </p>
        <% end %>

        <%= if @catalog_total_pages > 1 do %>
          <nav
            id="catalog-pagination"
            class="flex flex-wrap items-center justify-between gap-3 rounded-xl bg-white/60 px-4 py-3"
          >
            <button
              id="catalog-prev-page"
              type="button"
              phx-click="catalog_page"
              phx-value-page={@catalog_page - 1}
              disabled={@catalog_page == 1}
              class="rounded-lg border border-[#2F5C43] px-3 py-1.5 text-sm font-medium text-[#2F5C43] transition hover:bg-[#2F5C43]/10 disabled:cursor-not-allowed disabled:opacity-40"
            >
              Previous
            </button>
            <p id="catalog-page-label" class="text-sm text-[#212121]/70">
              Page {@catalog_page} of {@catalog_total_pages}
            </p>
            <button
              id="catalog-next-page"
              type="button"
              phx-click="catalog_page"
              phx-value-page={@catalog_page + 1}
              disabled={@catalog_page == @catalog_total_pages}
              class="rounded-lg border border-[#2F5C43] px-3 py-1.5 text-sm font-medium text-[#2F5C43] transition hover:bg-[#2F5C43]/10 disabled:cursor-not-allowed disabled:opacity-40"
            >
              Next
            </button>
          </nav>
        <% end %>

        <section
          id="book-request-section"
          class="rounded-xl border border-dashed border-[#74AC8D]/50 bg-white/60 p-6"
        >
          <h2 class="text-lg font-bold text-[#212121]">Can't find your book?</h2>
          <p class="mt-1 text-sm text-[#212121]/70">
            Request a title and we'll review adding chapter summaries for it.
          </p>

          <.form
            for={@request_form}
            id="book-request-form"
            phx-submit="request_book"
            phx-change="validate_request"
            class="mt-4 space-y-4"
          >
            <.input
              field={@request_form[:title]}
              type="text"
              label="Title"
              placeholder="e.g. Dune"
              required
              class="w-full rounded-lg border-0 bg-white px-4 py-3.5 text-[#212121] shadow-md placeholder:text-[#212121]/40 focus:outline-none focus:ring-2 focus:ring-[#74AC8D]"
            />
            <.input
              field={@request_form[:author]}
              type="text"
              label="Author"
              placeholder="e.g. Frank Herbert"
              required
              class="w-full rounded-lg border-0 bg-white px-4 py-3.5 text-[#212121] shadow-md placeholder:text-[#212121]/40 focus:outline-none focus:ring-2 focus:ring-[#74AC8D]"
            />
            <.input
              field={@request_form[:notes]}
              type="textarea"
              label="Notes (optional)"
              placeholder="Anything that helps us find the right edition"
              class="w-full rounded-lg border-0 bg-white px-4 py-3.5 text-[#212121] shadow-md placeholder:text-[#212121]/40 focus:outline-none focus:ring-2 focus:ring-[#74AC8D]"
            />
            <Layouts.brand_submit>Submit request</Layouts.brand_submit>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(:search, search)
     |> assign_catalog_page(Books.search_catalog(search), 1)
     |> maybe_prefill_request(search)}
  end

  def handle_event("catalog_page", %{"page" => page}, socket) do
    page = String.to_integer(page)

    {:noreply, assign_catalog_page(socket, socket.assigns.catalog_entries, page)}
  end

  def handle_event("reload_catalog", _params, socket) do
    case CatalogSync.request_sync(self()) do
      {:ok, :started} ->
        {:noreply, assign(socket, :syncing_catalog, true)}

      {:error, :in_progress} ->
        {:noreply, put_flash(socket, :info, "Catalog reload is already in progress.")}

      {:error, {:rate_limited, seconds}} ->
        {:noreply,
         put_flash(
           socket,
           :info,
           "Please wait #{seconds} seconds before reloading the catalog again."
         )}
    end
  end

  def handle_event("validate_request", %{"book_request" => params}, socket) do
    changeset =
      %BookRequest{}
      |> BookRequest.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :request_form, to_form(changeset, as: "book_request"))}
  end

  def handle_event("request_book", %{"book_request" => params}, socket) do
    user = socket.assigns.current_scope.user

    case BookRequests.create_request(user.id, params) do
      {:ok, _request} ->
        {:noreply,
         socket
         |> put_flash(:info, "Thanks! Your book request was submitted.")
         |> assign(:request_form, request_form(%{}))}

      {:error, changeset} ->
        {:noreply, assign(socket, :request_form, to_form(changeset, as: "book_request"))}
    end
  end

  def handle_event("add", %{"title" => title, "author" => author}, socket) do
    user = socket.assigns.current_scope.user
    socket = assign(socket, :importing, true)

    case Books.add_to_user_library(user.id, title, author) do
      {:ok, user_book, _book} ->
        {:noreply,
         socket
         |> put_flash(:info, "Added #{title} to your library.")
         |> push_navigate(to: ~p"/library/#{user_book.id}")}

      {:error, :not_in_catalog} ->
        {:noreply,
         socket
         |> assign(:importing, false)
         |> put_flash(:error, "Summaries are not available for that book.")}

      {:error, :already_in_library} ->
        {:noreply,
         socket
         |> assign(:importing, false)
         |> put_flash(:error, "That book is already in your library.")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:importing, false)
         |> put_flash(:error, "Could not import summaries. Please try again.")}
    end
  end

  @impl true
  def handle_info({:catalog_sync_done, {:ok, count}}, socket) do
    results = Books.search_catalog(socket.assigns.search)

    {:noreply,
     socket
     |> assign(:syncing_catalog, false)
     |> assign_catalog_page(results, 1)
     |> assign(:catalog_size, count)
     |> put_flash(:info, "Catalog updated — #{count} books available.")}
  end

  def handle_info({:catalog_sync_done, {:error, _reason}}, socket) do
    {:noreply,
     socket
     |> assign(:syncing_catalog, false)
     |> put_flash(:error, "Could not reload the catalog. Please try again later.")}
  end

  defp assign_catalog_page(socket, entries, page) do
    total_pages = entries |> length() |> total_pages()
    page = page |> max(1) |> min(total_pages)

    page_results =
      entries
      |> Enum.drop((page - 1) * @page_size)
      |> Enum.take(@page_size)

    catalog_size =
      if socket.assigns[:search] in [nil, ""] do
        Books.catalog_size()
      else
        length(entries)
      end

    socket
    |> assign(:catalog_entries, entries)
    |> assign(:catalog_results, page_results)
    |> assign(:catalog_page, page)
    |> assign(:catalog_total_pages, total_pages)
    |> assign(:catalog_size, catalog_size)
  end

  defp total_pages(0), do: 1

  defp total_pages(count) do
    (count + @page_size - 1) |> div(@page_size)
  end

  defp request_form(params) do
    %BookRequest{}
    |> BookRequest.changeset(params)
    |> to_form(as: "book_request")
  end

  defp maybe_prefill_request(socket, ""), do: socket

  defp maybe_prefill_request(socket, search) do
    assign(socket, :request_form, request_form(%{"title" => search}))
  end

  defp catalog_summary(catalog_size, "", _entries) do
    "#{catalog_size} books available to add"
  end

  defp catalog_summary(_catalog_size, search, entries) do
    "#{length(entries)} match#{if length(entries) == 1, do: "", else: "es"} for \"#{search}\""
  end
end
