defmodule PlotlineWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use PlotlineWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates("layouts/*")

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")

  attr(:current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"
  )

  slot(:inner_block, required: true)

  attr(:page_id, :string, default: "auth-page")

  def auth_page(assigns) do
    ~H"""
    <div
      id={@page_id}
      class="relative flex min-h-screen items-center justify-center overflow-hidden bg-gradient-to-b from-[#74AC8D] to-[#2F5C43] px-6 py-12"
    >
      <div
        class="pointer-events-none absolute text-[#245037] opacity-40"
        style="width: 677px; height: 677px; left: -122px; top: -370px; transform: rotate(77.56deg);"
        aria-hidden="true"
      >
        <.loops_icon />
      </div>

      <div
        class="pointer-events-none absolute text-[#245037] opacity-40"
        style="width: 677px; height: 677px; right: -60px; bottom: -340px; transform: rotate(77.56deg);"
        aria-hidden="true"
      >
        <.loops_icon />
      </div>

      <div class="relative z-10 w-full max-w-sm rounded-xl bg-[#F2E8CF] px-8 py-10 shadow-xl">
        {render_slot(@inner_block)}
      </div>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr(:flash, :map, required: true, doc: "the map of flash messages")

  attr(:current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"
  )

  slot(:inner_block, required: true)

  def app(assigns) do
    ~H"""
    <div
      id="app-shell"
      class="relative min-h-[calc(100vh-3.5rem)] overflow-hidden bg-gradient-to-b from-[#74AC8D] to-[#2F5C43]"
    >
      <div
        class="pointer-events-none absolute text-[#245037] opacity-40"
        style="width: 677px; height: 677px; left: -122px; top: -370px; transform: rotate(77.56deg);"
        aria-hidden="true"
      >
        <.loops_icon />
      </div>

      <div
        class="pointer-events-none absolute text-[#245037] opacity-40"
        style="width: 677px; height: 677px; right: -60px; bottom: -340px; transform: rotate(77.56deg);"
        aria-hidden="true"
      >
        <.loops_icon />
      </div>

      <div class="relative z-10 mx-auto max-w-3xl px-4 py-8 sm:px-6 lg:py-10">
        <div class="rounded-xl bg-[#F2E8CF] px-6 py-8 shadow-xl sm:px-8">
          {render_slot(@inner_block)}
        </div>
      </div>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr(:rest, :global)

  def loops_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" class="h-full w-full" fill="none">
      <path
        fill="none"
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M12.353 7.837a5.93 5.93 0 0 1 7.682-1.542l17.812 10.287a5.93 5.93 0 0 1 0 10.271l-18.8 10.858a2.635 2.635 0 0 1-3.954-2.282V12.575"
      />
      <path
        fill="none"
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M40.356 23.995a5.93 5.93 0 0 1-2.506 7.424L20.036 41.706a5.93 5.93 0 0 1-8.896-5.135V14.858a2.635 2.635 0 0 1 3.954-2.283l19.792 11.427"
      />
      <path
        fill="none"
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M12.362 40.171a5.93 5.93 0 0 1-5.177-5.882l.002-20.573a5.93 5.93 0 0 1 8.896-5.136l18.803 10.857a2.636 2.636 0 0 1 0 4.564L15.094 35.429"
      />
    </svg>
    """
  end

  attr(:navigate, :string, required: true)
  slot(:inner_block, required: true)
  attr(:class, :string, default: nil)
  attr(:rest, :global)

  def brand_button(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "inline-flex items-center justify-center gap-2 rounded-lg bg-[#212121] px-4 py-2.5 text-sm font-semibold text-[#F2E8CF] transition hover:bg-[#212121]/90",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr(:type, :string, default: "submit")
  slot(:inner_block, required: true)
  attr(:class, :string, default: nil)
  attr(:rest, :global, include: ~w(disabled form name value phx-disable-with phx-click phx-value-title phx-value-author id))

  def brand_submit(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex items-center justify-center gap-2 rounded-lg bg-[#212121] px-4 py-2.5 text-sm font-semibold text-[#F2E8CF] transition hover:bg-[#212121]/90 disabled:cursor-not-allowed disabled:opacity-60",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr(:navigate, :string, required: true)
  slot(:inner_block, required: true)
  attr(:class, :string, default: nil)
  attr(:rest, :global)

  def back_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "text-sm font-medium text-[#2F5C43] transition hover:text-[#212121]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:id, :string, default: "flash-group", doc: "the optional id of flash container")

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
