defmodule PlotlineWeb.LibraryLive.Upload do
  use PlotlineWeb, :live_view

  alias Plotline.PdfUploads
  alias Plotline.PdfUploads.Processor
  alias Plotline.Repo

  @max_file_size 50_000_000

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:page_title, "Upload PDF")
     |> assign(:max_file_size, @max_file_size)
     |> assign(:uploads_list, PdfUploads.list_uploads_for_user(user.id))
     |> assign(:processing_ids, MapSet.new())
     |> allow_upload(:pdf,
       accept: ~w(.pdf),
       max_entries: 1,
       max_file_size: @max_file_size,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div>
          <Layouts.back_link navigate={~p"/library"}>← Back to library</Layouts.back_link>
          <h1 class="mt-2 text-2xl font-bold text-[#212121]">Upload PDF</h1>
          <p class="mt-1 text-sm text-[#212121]/70">
            Upload a book PDF. Processing extracts text, looks up Hardcover metadata, and generates chapter summaries.
          </p>
        </div>

        <form id="pdf-upload-form" phx-submit="save" phx-change="validate" class="space-y-4">
          <div
            id="pdf-drop-zone"
            class="rounded-xl border border-dashed border-[#74AC8D]/60 bg-white/70 p-8 text-center"
            phx-drop-target={@uploads.pdf.ref}
          >
            <p class="font-medium text-[#212121]">Choose a PDF to upload</p>
            <p class="mt-1 text-sm text-[#212121]/70">
              PDF only · max {div(@max_file_size, 1_000_000)} MB
            </p>

            <label class="mt-6 inline-flex cursor-pointer items-center justify-center gap-2 rounded-lg bg-[#212121] px-4 py-2.5 text-sm font-semibold text-[#F2E8CF] transition hover:bg-[#212121]/90">
              <.icon name="hero-arrow-up-tray" class="size-4" />
              Select PDF
              <.live_file_input upload={@uploads.pdf} class="sr-only" />
            </label>

            <div :for={entry <- @uploads.pdf.entries} class="mt-6 space-y-2 text-left">
              <div class="flex items-center justify-between gap-3 text-sm text-[#212121]">
                <span class="truncate font-medium">{entry.client_name}</span>
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  class="shrink-0 text-[#2F5C43] underline underline-offset-2"
                >
                  Cancel
                </button>
              </div>
              <div class="h-2 w-full overflow-hidden rounded-full bg-[#F2E8CF]">
                <div
                  class="h-full rounded-full bg-[#2F5C43] transition-all"
                  style={"width: #{entry.progress}%"}
                >
                </div>
              </div>
              <p class="text-xs text-[#212121]/60">{entry.progress}% uploaded</p>

              <p
                :for={err <- upload_errors(@uploads.pdf, entry)}
                class="text-sm text-red-700"
              >
                {error_to_string(err)}
              </p>
            </div>

            <p
              :for={err <- upload_errors(@uploads.pdf)}
              class="mt-4 text-sm text-red-700"
            >
              {error_to_string(err)}
            </p>
          </div>

          <Layouts.brand_submit
            id="save-pdf-button"
            disabled={@uploads.pdf.entries == []}
          >
            Save PDF
          </Layouts.brand_submit>
        </form>

        <section :if={@uploads_list != []} id="uploaded-pdfs" class="space-y-3">
          <h2 class="text-lg font-bold text-[#212121]">Your uploaded PDFs</h2>
          <ul class="space-y-2">
            <li
              :for={upload <- @uploads_list}
              id={"pdf-upload-#{upload.id}"}
              class="group flex flex-wrap items-center justify-between gap-3 rounded-xl bg-white p-4 shadow-md"
            >
              <div class="min-w-0 flex-1">
                <p class="truncate font-medium text-[#212121]">{upload.original_filename}</p>
                <p class="text-xs text-[#212121]/60">
                  {PdfUploads.format_bytes(upload.byte_size)} · {upload.status}
                </p>
              </div>
              <div class="flex shrink-0 items-center gap-2">
                <button
                  :if={processable?(upload) and not MapSet.member?(@processing_ids, upload.id)}
                  type="button"
                  id={"process-pdf-#{upload.id}"}
                  phx-click="process"
                  phx-value-id={upload.id}
                  class="rounded-lg bg-[#2F5C43] px-3 py-1.5 text-sm font-semibold text-[#F2E8CF] transition hover:bg-[#2F5C43]/90"
                >
                  Process PDF
                </button>
                <span
                  :if={upload.status == "processing" or MapSet.member?(@processing_ids, upload.id)}
                  class="text-sm font-medium text-[#2F5C43]"
                >
                  Processing…
                </span>
                <span
                  :if={upload.status == "ready"}
                  class="text-sm font-medium text-[#2F5C43]"
                >
                  Ready in library
                </span>
                <button
                  type="button"
                  id={"delete-pdf-#{upload.id}"}
                  phx-click="delete"
                  phx-value-id={upload.id}
                  data-confirm={"Delete #{upload.original_filename}? This removes the file and its metadata."}
                  class="rounded-lg p-2 text-[#212121]/40 transition hover:bg-red-50 hover:text-red-700"
                  aria-label={"Delete #{upload.original_filename}"}
                >
                  <.icon name="hero-trash" class="size-5" />
                </button>
              </div>
            </li>
          </ul>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :pdf, ref)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user

    case PdfUploads.get_upload_for_user(user.id, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "PDF not found.")}

      upload ->
        {:ok, _} = PdfUploads.delete_upload(upload)

        {:noreply,
         socket
         |> put_flash(:info, "PDF deleted.")
         |> assign(:uploads_list, PdfUploads.list_uploads_for_user(user.id))
         |> update(:processing_ids, &MapSet.delete(&1, upload.id))}
    end
  end

  def handle_event("process", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user

    case PdfUploads.get_upload_for_user(user.id, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "PDF not found.")}

      %{status: status} = upload when status in ["uploaded", "failed"] ->
        if async_processing?() do
          start_async_processing(socket, upload)
        else
          finish_processing(socket, Processor.process(upload.id))
        end

      _upload ->
        {:noreply, put_flash(socket, :error, "This PDF cannot be processed right now.")}
    end
  end

  def handle_event("save", _params, socket) do
    user = socket.assigns.current_scope.user

    results =
      consume_uploaded_entries(socket, :pdf, fn %{path: path}, entry ->
        case PdfUploads.create_from_path(user.id, path, %{
               original_filename: entry.client_name,
               content_type: entry.client_type || "application/pdf",
               byte_size: entry.client_size
             }) do
          {:ok, upload} -> {:ok, upload}
          {:error, reason} -> {:ok, {:error, reason}}
        end
      end)

    case results do
      [%Plotline.PdfUploads.PdfUpload{}] ->
        {:noreply,
         socket
         |> put_flash(:info, "PDF uploaded successfully.")
         |> assign(:uploads_list, PdfUploads.list_uploads_for_user(user.id))}

      [{:error, _reason}] ->
        {:noreply, put_flash(socket, :error, "Could not save the PDF. Please try again.")}

      [] ->
        {:noreply, put_flash(socket, :error, "Choose a PDF file first.")}

      _other ->
        {:noreply, put_flash(socket, :error, "Could not save the PDF. Please try again.")}
    end
  end

  @impl true
  def handle_info({:pdf_processed, upload_id, result}, socket) do
    socket = update(socket, :processing_ids, &MapSet.delete(&1, upload_id))
    finish_processing(socket, result)
  end

  defp start_async_processing(socket, upload) do
    lv_pid = self()
    upload_id = upload.id
    user = socket.assigns.current_scope.user

    {:ok, _task} =
      Task.Supervisor.start_child(Plotline.TaskSupervisor, fn ->
        allow_repo(lv_pid)
        result = Processor.process(upload_id)
        send(lv_pid, {:pdf_processed, upload_id, result})
      end)

    {:noreply,
     socket
     |> update(:processing_ids, &MapSet.put(&1, upload.id))
     |> assign(:uploads_list, PdfUploads.list_uploads_for_user(user.id))
     |> put_flash(:info, "Processing started. This may take a minute.")}
  end

  defp finish_processing(socket, result) do
    user = socket.assigns.current_scope.user

    socket = assign(socket, :uploads_list, PdfUploads.list_uploads_for_user(user.id))

    case result do
      {:ok, _upload} ->
        {:noreply,
         put_flash(socket, :info, "PDF processed. Open My Library to read chapter summaries.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, Processor.humanize_error(reason))}
    end
  end

  defp async_processing? do
    Application.get_env(:plotline, Processor, [])
    |> Keyword.get(:async, true)
  end

  defp processable?(%{status: status}) when status in ["uploaded", "failed"], do: true
  defp processable?(_), do: false

  defp allow_repo(parent_pid) do
    try do
      Ecto.Adapters.SQL.Sandbox.allow(Repo, parent_pid, self())
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end
  end

  defp handle_progress(:pdf, entry, socket) do
    if entry.done? do
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp error_to_string(:too_large), do: "File is too large (max 50 MB)."
  defp error_to_string(:too_many_files), do: "Upload one PDF at a time."
  defp error_to_string(:not_accepted), do: "Only PDF files are allowed."
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
