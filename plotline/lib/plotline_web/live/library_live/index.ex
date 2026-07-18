defmodule PlotlineWeb.LibraryLive.Index do
  use PlotlineWeb, :live_view

  alias Plotline.PdfUploads
  alias Plotline.UserBooks

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:page_title, "My Library")
     |> assign_library(user.id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex items-center justify-between gap-4">
          <div>
            <h1 class="text-2xl font-bold text-[#212121]">My Library</h1>
            <p class="mt-1 text-sm text-[#212121]/70">
              Books you are reading with spoiler-safe recall.
            </p>
          </div>
          <div class="flex shrink-0 flex-wrap items-center gap-2">
            <.link
              id="upload-pdf-button"
              navigate={~p"/library/upload"}
              class="inline-flex items-center justify-center gap-2 rounded-lg border border-[#2F5C43] bg-white px-4 py-2.5 text-sm font-semibold text-[#2F5C43] transition hover:bg-[#2F5C43]/10"
            >
              <.icon name="hero-arrow-up-tray" class="size-4" /> Upload PDF
            </.link>
            <Layouts.brand_button navigate={~p"/library/new"} class="shrink-0">
              <.icon name="hero-plus" class="size-4" /> Browse catalog
            </Layouts.brand_button>
          </div>
        </div>

        <%= if @user_books == [] and @pdf_uploads == [] do %>
          <div
            id="library-empty"
            class="rounded-xl border border-dashed border-[#74AC8D]/50 bg-white/60 p-10 text-center"
          >
            <p class="font-medium text-[#212121]">No books yet.</p>
            <p class="mt-2 text-sm text-[#212121]/70">
              Add a book from the catalog or upload a PDF to start tracking your progress.
            </p>
            <Layouts.brand_button navigate={~p"/library/new"} class="mt-6">
              Add your first book
            </Layouts.brand_button>
          </div>
        <% else %>
          <ul id="library-list" class="space-y-3">
            <li
              :for={ub <- @user_books}
              id={"user-book-#{ub.id}"}
              class="group flex items-stretch gap-2 rounded-xl bg-white p-4 shadow-md transition hover:shadow-lg"
            >
              <.link navigate={~p"/library/#{ub.id}"} class="min-w-0 flex-1">
                <div class="flex items-start justify-between gap-3">
                  <div class="min-w-0">
                    <h2 class="font-semibold text-[#212121]">{ub.book.title}</h2>
                    <p class="text-sm text-[#212121]/70">{ub.book.author}</p>
                  </div>
                  <p class="shrink-0 text-xs font-medium text-[#2F5C43]">
                    {progress_label(ub)}
                  </p>
                </div>
                <div
                  class="mt-3 h-2 w-full overflow-hidden rounded-full bg-[#F2E8CF]"
                  role="progressbar"
                  aria-valuemin="0"
                  aria-valuemax={ub.book.total_chapters}
                  aria-valuenow={ub.current_chapter_number}
                  aria-label={"Progress: #{progress_percent(ub)}%"}
                >
                  <div
                    class="h-full rounded-full bg-[#2F5C43] transition-all"
                    style={"width: #{progress_percent(ub)}%"}
                  >
                  </div>
                </div>
              </.link>
              <button
                type="button"
                id={"delete-user-book-#{ub.id}"}
                phx-click="delete-book"
                phx-value-id={ub.id}
                data-confirm={"Remove \"#{ub.book.title}\" from your library?"}
                class="shrink-0 self-center rounded-lg p-2 text-[#212121]/40 transition hover:bg-red-50 hover:text-red-700 sm:opacity-0 sm:group-hover:opacity-100 sm:group-focus-within:opacity-100"
                aria-label={"Remove #{ub.book.title} from library"}
              >
                <.icon name="hero-trash" class="size-5" />
              </button>
            </li>

            <li
              :for={upload <- @pdf_uploads}
              id={"pdf-upload-#{upload.id}"}
              class="group flex items-stretch gap-2 rounded-xl bg-white p-4 shadow-md transition hover:shadow-lg"
            >
              <.link navigate={~p"/library/upload"} class="min-w-0 flex-1">
                <div class="flex items-start justify-between gap-3">
                  <div class="min-w-0">
                    <h2 class="font-semibold text-[#212121]">
                      {PdfUploads.display_title(upload)}
                    </h2>
                    <p class="text-sm text-[#212121]/70">
                      Author unknown · {PdfUploads.format_bytes(upload.byte_size)} PDF
                    </p>
                  </div>
                  <p class="shrink-0 text-xs font-medium text-[#2F5C43]">
                    {pdf_progress_label(upload)}
                  </p>
                </div>
                <div
                  class="mt-3 h-2 w-full overflow-hidden rounded-full bg-[#F2E8CF]"
                  role="progressbar"
                  aria-valuemin="0"
                  aria-valuemax="100"
                  aria-valuenow="0"
                  aria-label="Progress: 0%"
                >
                  <div class="h-full w-0 rounded-full bg-[#2F5C43]"></div>
                </div>
              </.link>
              <button
                type="button"
                id={"delete-pdf-#{upload.id}"}
                phx-click="delete-pdf"
                phx-value-id={upload.id}
                data-confirm={"Delete #{upload.original_filename}?"}
                class="shrink-0 self-center rounded-lg p-2 text-[#212121]/40 transition hover:bg-red-50 hover:text-red-700 sm:opacity-0 sm:group-hover:opacity-100 sm:group-focus-within:opacity-100"
                aria-label={"Delete #{upload.original_filename}"}
              >
                <.icon name="hero-trash" class="size-5" />
              </button>
            </li>
          </ul>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("delete-book", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user

    case Integer.parse(to_string(id)) do
      {user_book_id, ""} ->
        case UserBooks.delete_user_book_for_user(user.id, user_book_id) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Removed from library.")
             |> assign_library(user.id)}

          {:error, :not_found} ->
            {:noreply, put_flash(socket, :error, "Book not found.")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Book not found.")}
    end
  end

  def handle_event("delete-pdf", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user

    case PdfUploads.get_upload_for_user(user.id, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "PDF not found.")}

      upload ->
        {:ok, _} = PdfUploads.delete_upload(upload)

        {:noreply,
         socket
         |> put_flash(:info, "PDF deleted.")
         |> assign_library(user.id)}
    end
  end

  defp assign_library(socket, user_id) do
    socket
    |> assign(:user_books, UserBooks.list_user_books_with_books(user_id))
    |> assign(:pdf_uploads, PdfUploads.list_pending_uploads_for_user(user_id))
  end

  defp progress_percent(%{current_chapter_number: current, book: %{total_chapters: total}})
       when is_integer(current) and is_integer(total) and total > 0 do
    current
    |> max(0)
    |> min(total)
    |> Kernel.*(100)
    |> div(total)
  end

  defp progress_percent(_), do: 0

  defp progress_label(%{current_chapter_number: 0, book: book}) do
    "Not started · #{book.total_chapters} chapters"
  end

  defp progress_label(%{current_chapter_number: current, book: book})
       when current >= book.total_chapters do
    "Finished · #{book.total_chapters} chapters"
  end

  defp progress_label(%{current_chapter_number: current, book: book}) do
    "Ch. #{current} of #{book.total_chapters}"
  end

  defp pdf_progress_label(%{status: "uploaded"}), do: "Uploaded · chapters pending"
  defp pdf_progress_label(%{status: "processing"}), do: "Processing…"
  defp pdf_progress_label(%{status: "ready"}), do: "Ready"
  defp pdf_progress_label(%{status: "failed"}), do: "Failed"
  defp pdf_progress_label(_), do: "PDF upload"
end
