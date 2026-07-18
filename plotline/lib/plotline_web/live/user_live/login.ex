defmodule PlotlineWeb.UserLive.Login do
  use PlotlineWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth_page flash={@flash} page_id="login-page">
      <h1 class="text-center text-2xl font-bold text-[#212121]">{@page_heading}</h1>

      <p class="mt-3 text-center text-sm leading-relaxed text-[#212121]/70">
        {@page_subheading}
      </p>

      <.form
        for={@form}
        id="login_form"
        action={~p"/users/log-in"}
        phx-submit="submit"
        phx-trigger-action={@trigger_submit}
        class="mt-8 space-y-4"
      >
        <input type="hidden" name="return_to" value={@return_to} />

        <.input
          readonly={@reauthenticating?}
          field={@form[:email]}
          type="email"
          placeholder="Email"
          autocomplete="username"
          required
          phx-mounted={unless(@reauthenticating?, do: JS.focus())}
          class="w-full rounded-lg border-0 bg-white px-4 py-3.5 text-[#212121] shadow-md placeholder:text-[#212121]/40 focus:outline-none focus:ring-2 focus:ring-[#74AC8D] read-only:cursor-default read-only:bg-white/80"
        />

        <.input
          field={@form[:password]}
          type="password"
          placeholder="Password"
          autocomplete="current-password"
          required
          class="w-full rounded-lg border-0 bg-white px-4 py-3.5 text-[#212121] shadow-md placeholder:text-[#212121]/40 focus:outline-none focus:ring-2 focus:ring-[#74AC8D]"
        />

        <button
          type="submit"
          phx-disable-with="Logging in..."
          class="w-full rounded-lg bg-[#212121] px-4 py-3.5 text-base font-semibold text-[#F2E8CF] transition hover:bg-[#212121]/90"
        >
          {@submit_label}
        </button>
      </.form>

      <%= if @reauthenticating? do %>
        <p class="mt-6 text-center text-sm text-[#212121]/70">
          <.link
            navigate={~p"/library"}
            class="font-medium text-[#212121] underline underline-offset-2"
          >
            Back to library
          </.link>
        </p>
      <% else %>
        <p class="mt-6 text-center text-sm text-[#212121]/70">
          New to Plotline?
          <.link
            navigate={~p"/users/register"}
            class="font-medium text-[#212121] underline underline-offset-2"
          >
            Create an account
          </.link>
        </p>
      <% end %>
    </Layouts.auth_page>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    reauthenticating? = !!(socket.assigns.current_scope && socket.assigns.current_scope.user)

    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    return_to = normalize_return_to(params["return_to"], reauthenticating?)

    form = to_form(%{"email" => email || "", "password" => "", "remember_me" => true}, as: "user")

    {heading, subheading, submit_label} = page_copy(reauthenticating?, return_to)

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:trigger_submit, false)
     |> assign(:reauthenticating?, reauthenticating?)
     |> assign(:return_to, return_to)
     |> assign(:page_heading, heading)
     |> assign(:page_subheading, subheading)
     |> assign(:submit_label, submit_label)}
  end

  @impl true
  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  defp page_copy(true, "/users/settings") do
    {
      "Confirm it's you",
      "For your security, enter your password again to open Settings.",
      "Continue to Settings"
    }
  end

  defp page_copy(true, _return_to) do
    {
      "Confirm it's you",
      "Enter your password to continue.",
      "Continue"
    }
  end

  defp page_copy(false, _return_to) do
    {
      "Log in",
      "Welcome back. Sign in with your email and password.",
      "Log in"
    }
  end

  defp normalize_return_to(path, true) when is_binary(path) do
    if valid_return_to?(path), do: path, else: "/users/settings"
  end

  defp normalize_return_to(path, false) when is_binary(path) do
    if valid_return_to?(path), do: path, else: ""
  end

  defp normalize_return_to(_path, true), do: "/users/settings"
  defp normalize_return_to(_path, false), do: ""

  defp valid_return_to?(path) when is_binary(path) do
    String.starts_with?(path, "/") and not String.starts_with?(path, "//")
  end
end
