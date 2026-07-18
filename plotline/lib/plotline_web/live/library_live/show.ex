defmodule PlotlineWeb.LibraryLive.Show do
  use PlotlineWeb, :live_view

  alias Plotline.AI
  alias Plotline.Summaries
  alias Plotline.Summaries.Format
  alias Plotline.UserBooks
  alias Plotline.UserBooks.UserBook

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.user
    user_book = UserBooks.get_user_book_for_user!(user.id, id)

    {:ok,
     socket
     |> assign(:page_title, user_book.book.title)
     |> assign(:user_book, user_book)
     |> assign(:chapter_form, chapter_form(user_book))
     |> assign(:chat_messages, [])
     |> assign(:chat_loading, false)
     |> assign(:ai_enabled?, AI.enabled?())
     |> load_summaries(user_book)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div>
          <Layouts.back_link navigate={~p"/library"}>← Back to library</Layouts.back_link>
          <h1 class="mt-2 text-2xl font-bold text-[#212121]">
            {@user_book.book.title}
          </h1>
          <p class="text-[#212121]/70">{@user_book.book.author}</p>
        </div>

        <.form
          for={@chapter_form}
          id="chapter-form"
          phx-change="validate_chapter"
          phx-submit="update_chapter"
          class="rounded-xl bg-white p-4 shadow-md"
        >
          <div class="space-y-1">
            <label
              for={@chapter_form[:current_chapter_number].id}
              class="block text-sm font-medium text-[#212121]"
            >
              Current chapter (of {@user_book.book.total_chapters})
            </label>
            <div class="flex flex-wrap items-center gap-4">
              <div class="relative min-w-0 grow">
                <input
                  type="number"
                  id={@chapter_form[:current_chapter_number].id}
                  name={@chapter_form[:current_chapter_number].name}
                  value={@chapter_form[:current_chapter_number].value}
                  min="0"
                  max={@user_book.book.total_chapters}
                  required
                  class="chapter-number-input w-full rounded-lg border-0 bg-white py-3.5 pl-4 pr-12 text-[#212121] shadow-md placeholder:text-[#212121]/40 focus:outline-none focus:ring-2 focus:ring-[#74AC8D]"
                />
                <div class="absolute inset-y-0 right-2 flex flex-col justify-center">
                  <button
                    type="button"
                    class="flex h-5 w-6 items-center justify-center text-[#212121] transition hover:text-[#2F5C43]"
                    aria-label="Increase chapter"
                    phx-click={
                      JS.dispatch("plotline:step-number",
                        to: "##{@chapter_form[:current_chapter_number].id}",
                        detail: %{delta: 1}
                      )
                    }
                  >
                    <.icon name="hero-chevron-up-mini" class="size-4" />
                  </button>
                  <button
                    type="button"
                    class="flex h-5 w-6 items-center justify-center text-[#212121] transition hover:text-[#2F5C43]"
                    aria-label="Decrease chapter"
                    phx-click={
                      JS.dispatch("plotline:step-number",
                        to: "##{@chapter_form[:current_chapter_number].id}",
                        detail: %{delta: -1}
                      )
                    }
                  >
                    <.icon name="hero-chevron-down-mini" class="size-4" />
                  </button>
                </div>
              </div>
              <Layouts.brand_submit class="shrink-0">Update progress</Layouts.brand_submit>
            </div>
          </div>
        </.form>

        <section id="assistant-section" class="space-y-4 rounded-xl bg-white p-4 shadow-md">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h2 class="text-lg font-bold text-[#212121]">Reading assistant</h2>
              <p class="text-sm text-[#212121]/70">
                Ask questions or get a recap based only on chapters you've read.
              </p>
            </div>
            <Layouts.brand_submit
              id="recap-button"
              type="button"
              phx-click="recap"
              disabled={assistant_disabled?(@chat_loading, @user_book, @ai_enabled?)}
              class="shrink-0"
            >
              Recap so far
            </Layouts.brand_submit>
          </div>

          <%= unless @ai_enabled? do %>
            <p id="assistant-unconfigured" class="text-sm text-[#212121]/70">
              Add <code class="rounded bg-[#F2E8CF] px-1.5 py-0.5 text-xs">GEMINI_API_KEY</code>
              to your <code class="rounded bg-[#F2E8CF] px-1.5 py-0.5 text-xs">.env</code>
              file to enable the assistant. Get a free key from
              <a
                href="https://aistudio.google.com/apikey"
                target="_blank"
                rel="noopener noreferrer"
                class="font-medium text-[#2F5C43] underline underline-offset-2"
              >
                Google AI Studio
              </a>.
            </p>
          <% end %>

          <%= if @user_book.current_chapter_number == 0 do %>
            <p id="assistant-no-progress" class="text-sm text-[#212121]/60">
              Set your current chapter above to use the reading assistant.
            </p>
          <% end %>

          <div
            :if={@chat_messages != []}
            id="chat-messages"
            class="max-h-80 space-y-3 overflow-y-auto rounded-lg bg-[#F2E8CF]/40 p-4"
          >
            <div
              :for={{message, index} <- Enum.with_index(@chat_messages)}
              id={"chat-message-#{index}"}
              class={[
                "rounded-lg px-3 py-2 text-sm leading-relaxed",
                message.role == :user && "ml-8 bg-white text-[#212121]",
                message.role == :assistant && "mr-8 bg-[#2F5C43]/10 text-[#212121]"
              ]}
            >
              <p class="mb-1 text-xs font-semibold uppercase tracking-wide text-[#212121]/50">
                {if message.role == :user, do: "You", else: "Plotline"}
              </p>
              <%= if message.role == :assistant do %>
                <div class="space-y-3">
                  <div :for={section <- format_summary(message.content)} class="space-y-2">
                    <h4
                      :if={section.title}
                      class="text-sm font-bold text-[#212121]"
                    >
                      {section.title}
                    </h4>
                    <p
                      :for={paragraph <- section.paragraphs}
                      class="text-sm leading-relaxed text-[#212121]/85"
                    >
                      {paragraph}
                    </p>
                    <ul
                      :if={section.items != []}
                      class="list-disc space-y-1 pl-5 text-sm leading-relaxed text-[#212121]/85"
                    >
                      <li :for={item <- section.items}>{item}</li>
                    </ul>
                  </div>
                </div>
              <% else %>
                <p class="whitespace-pre-wrap">{message.content}</p>
              <% end %>
            </div>
          </div>

          <%= if @chat_loading do %>
            <div id="assistant-loading" class="flex items-center gap-2 text-sm text-[#2F5C43]">
              <.icon name="hero-arrow-path" class="size-4 motion-safe:animate-spin" />
              Thinking…
            </div>
          <% end %>

          <form
            id="chat-form"
            phx-submit="ask"
            class="flex flex-col gap-3 sm:flex-row"
          >
            <label for="chat-message" class="sr-only">Ask about what you've read</label>
            <input
              id="chat-message"
              name="message"
              type="text"
              placeholder="e.g. Who is Mr. Darcy?"
              disabled={assistant_disabled?(@chat_loading, @user_book, @ai_enabled?)}
              class="w-full rounded-lg border-0 bg-[#F2E8CF]/50 px-4 py-3 text-[#212121] shadow-inner placeholder:text-[#212121]/40 focus:outline-none focus:ring-2 focus:ring-[#74AC8D] disabled:cursor-not-allowed disabled:opacity-60"
            />
            <Layouts.brand_submit
              type="submit"
              disabled={assistant_disabled?(@chat_loading, @user_book, @ai_enabled?)}
              class="shrink-0"
            >
              Ask
            </Layouts.brand_submit>
          </form>
        </section>

        <section id="recall-section" class="space-y-4">
          <div>
            <h2 class="text-lg font-bold text-[#212121]">
              Recall
              <%= if @user_book.current_chapter_number > 0 do %>
                <span class="text-base font-normal text-[#212121]/60">
                  — chapters 1–{@user_book.current_chapter_number}
                </span>
              <% end %>
            </h2>
            <p class="text-sm text-[#212121]/70">
              Spoiler-safe summaries for chapters you have already read.
            </p>
          </div>

          <%= cond do %>
            <% @user_book.current_chapter_number == 0 -> %>
              <p id="recall-empty" class="text-sm text-[#212121]/60">
                Set your current chapter above to see recall summaries.
              </p>
            <% @summaries == [] -> %>
              <p id="recall-missing" class="text-sm text-[#2F5C43]">
                No summaries found for this book yet.
              </p>
            <% true -> %>
              <nav
                id="chapter-jump-nav"
                class="rounded-xl bg-white p-4 shadow-md"
                aria-label="Jump to chapter summary"
              >
                <p class="mb-3 text-sm font-medium text-[#212121]">Jump to chapter</p>
                <div class="flex flex-wrap gap-2">
                  <a
                    :for={summary <- @summaries}
                    href={"#summary-chapter-#{summary.chapter_number}"}
                    class="inline-flex min-w-9 items-center justify-center rounded-lg bg-[#F2E8CF] px-2.5 py-1.5 text-sm font-semibold text-[#2F5C43] transition hover:bg-[#74AC8D]/35"
                  >
                    {summary.chapter_number}
                  </a>
                </div>
              </nav>

              <ul id="recall-list" class="space-y-4">
                <li
                  :for={summary <- @summaries}
                  id={"summary-chapter-#{summary.chapter_number}"}
                  class="scroll-mt-20 rounded-xl bg-white p-4 shadow-md"
                >
                  <div class="flex items-center justify-between gap-3">
                    <h3 class="font-semibold text-[#2F5C43]">
                      Chapter {summary.chapter_number}
                    </h3>
                    <a
                      href="#chapter-jump-nav"
                      class="text-xs font-medium text-[#2F5C43]/70 underline-offset-2 hover:text-[#2F5C43] hover:underline"
                    >
                      Back to chapters
                    </a>
                  </div>

                  <div class="mt-3 space-y-4">
                    <div :for={section <- format_summary(summary.summary_text)} class="space-y-2">
                      <h4
                        :if={section.title}
                        class="text-sm font-bold text-[#212121]"
                      >
                        {section.title}
                      </h4>
                      <p
                        :for={paragraph <- section.paragraphs}
                        class="text-sm leading-relaxed text-[#212121]/80"
                      >
                        {paragraph}
                      </p>
                      <ul
                        :if={section.items != []}
                        class="list-disc space-y-1.5 pl-5 text-sm leading-relaxed text-[#212121]/80"
                      >
                        <li :for={item <- section.items} class="pl-1">
                          <span class="font-medium text-[#212121]">{item}</span>
                        </li>
                      </ul>
                    </div>
                  </div>
                </li>
              </ul>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate_chapter", %{"user_book" => params}, socket) do
    changeset =
      socket.assigns.user_book
      |> UserBook.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :chapter_form, to_form(changeset, as: "user_book"))}
  end

  def handle_event("update_chapter", %{"user_book" => params}, socket) do
    user_book = socket.assigns.user_book

    case UserBooks.update_user_book(user_book, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:user_book, %{updated | book: user_book.book})
         |> assign(:chapter_form, chapter_form(updated))
         |> load_summaries(updated)
         |> put_flash(:info, "Progress updated to chapter #{updated.current_chapter_number}.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :chapter_form, to_form(changeset, as: "user_book"))}
    end
  end

  def handle_event("ask", %{"message" => message}, socket) do
    submit_chat(socket, message)
  end

  def handle_event("recap", _params, socket) do
    submit_chat(socket, :recap)
  end

  @impl true
  def handle_info({:ai_reply, result}, socket) do
    case result do
      {:ok, reply} ->
        {:noreply,
         socket
         |> assign(:chat_loading, false)
         |> append_message(:assistant, reply)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:chat_loading, false)
         |> put_flash(:error, AI.humanize_error(reason))}
    end
  end

  defp submit_chat(socket, :recap) do
    if socket.assigns.chat_loading do
      {:noreply, socket}
    else
      user_book = socket.assigns.user_book
      parent = self()

      Task.start(fn ->
        send(parent, {:ai_reply, AI.recap(user_book)})
      end)

      {:noreply,
       socket
       |> assign(:chat_loading, true)
       |> append_message(:user, "Recap what I've read so far")}
    end
  end

  defp submit_chat(socket, message) do
    message = String.trim(message)

    cond do
      message == "" ->
        {:noreply, socket}

      socket.assigns.chat_loading ->
        {:noreply, socket}

      true ->
        user_book = socket.assigns.user_book
        parent = self()

        Task.start(fn ->
          send(parent, {:ai_reply, AI.chat(user_book, message)})
        end)

        {:noreply,
         socket
         |> assign(:chat_loading, true)
         |> append_message(:user, message)}
    end
  end

  defp append_message(socket, role, content) do
    update(socket, :chat_messages, fn messages ->
      messages ++ [%{role: role, content: content}]
    end)
  end

  defp assistant_disabled?(loading, user_book, ai_enabled?) do
    loading or not ai_enabled? or user_book.current_chapter_number == 0
  end

  defp chapter_form(user_book) do
    user_book
    |> UserBook.changeset(%{})
    |> to_form(as: "user_book")
  end

  defp load_summaries(socket, user_book) do
    summaries =
      if user_book.current_chapter_number > 0 do
        Summaries.get_summaries_up_to(user_book.book_id, user_book.current_chapter_number)
      else
        []
      end

    assign(socket, :summaries, summaries)
  end

  defp format_summary(text), do: Format.to_sections(text)
end
