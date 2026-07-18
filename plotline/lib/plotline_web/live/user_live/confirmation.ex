defmodule PlotlineWeb.UserLive.Confirmation do
  use PlotlineWeb, :live_view

  alias Plotline.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth_page flash={@flash} page_id="confirmation-page">
      <h1 class="text-center text-2xl font-bold text-[#212121]">{@page_heading}</h1>

      <p class="mt-3 text-center text-sm leading-relaxed text-[#212121]/70">
        {@page_subheading}
      </p>

      <.form
        :if={!@user.confirmed_at}
        for={@form}
        id="confirmation_form"
        phx-mounted={JS.focus_first()}
        phx-submit="submit"
        action={~p"/users/log-in?_action=confirmed"}
        phx-trigger-action={@trigger_submit}
        class="mt-8 space-y-3"
      >
        <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <button
          type="submit"
          name={@form[:remember_me].name}
          value="true"
          phx-disable-with="Confirming..."
          class="w-full rounded-lg bg-[#212121] px-4 py-3.5 text-base font-semibold text-[#F2E8CF] transition hover:bg-[#212121]/90"
        >
          Confirm and stay logged in
        </button>
        <button
          type="submit"
          phx-disable-with="Confirming..."
          class="w-full rounded-lg border border-[#2F5C43] bg-white px-4 py-3.5 text-base font-semibold text-[#2F5C43] transition hover:bg-[#2F5C43]/10"
        >
          Confirm and log in only this time
        </button>
      </.form>

      <.form
        :if={@user.confirmed_at}
        for={@form}
        id="login_form"
        phx-submit="submit"
        phx-mounted={JS.focus_first()}
        action={~p"/users/log-in"}
        phx-trigger-action={@trigger_submit}
        class="mt-8 space-y-3"
      >
        <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <%= if @current_scope && @current_scope.user do %>
          <button
            type="submit"
            phx-disable-with="Logging in..."
            class="w-full rounded-lg bg-[#212121] px-4 py-3.5 text-base font-semibold text-[#F2E8CF] transition hover:bg-[#212121]/90"
          >
            Log in
          </button>
        <% else %>
          <button
            type="submit"
            name={@form[:remember_me].name}
            value="true"
            phx-disable-with="Logging in..."
            class="w-full rounded-lg bg-[#212121] px-4 py-3.5 text-base font-semibold text-[#F2E8CF] transition hover:bg-[#212121]/90"
          >
            Keep me logged in on this device
          </button>
          <button
            type="submit"
            phx-disable-with="Logging in..."
            class="w-full rounded-lg border border-[#2F5C43] bg-white px-4 py-3.5 text-base font-semibold text-[#2F5C43] transition hover:bg-[#2F5C43]/10"
          >
            Log me in only this time
          </button>
        <% end %>
      </.form>

      <p :if={!@user.confirmed_at} class="mt-6 text-center text-sm text-[#212121]/70">
        Tip: You can set a password later in Settings if you prefer signing in that way.
      </p>

      <p class="mt-6 text-center text-sm text-[#212121]/70">
        <.link
          navigate={~p"/users/log-in"}
          class="font-medium text-[#212121] underline underline-offset-2"
        >
          Back to log in
        </.link>
      </p>
    </Layouts.auth_page>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")
      {heading, subheading} = page_copy(user, socket.assigns[:current_scope])

      {:ok,
       assign(socket,
         user: user,
         form: form,
         trigger_submit: false,
         page_heading: heading,
         page_subheading: subheading
       ), temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end

  defp page_copy(%{confirmed_at: nil, email: email}, _scope) do
    {"Confirm your account", "Welcome #{email}. Click below to finish setting up Plotline."}
  end

  defp page_copy(%{email: email}, %{user: %{id: _user_id}} = scope)
       when not is_nil(scope.user) do
    {"Welcome back", "You're already signed in as #{email}. Click below to continue."}
  end

  defp page_copy(%{email: email}, _scope) do
    {"Welcome back", "Signed in as #{email}. Choose how long to stay logged in on this device."}
  end
end
