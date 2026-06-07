defmodule PlotlineWeb.UserLive.Login do
  use PlotlineWeb, :live_view

  alias Plotline.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen flex items-center justify-center bg-slate-50 dark:bg-slate-900">
        <div class="w-full max-w-sm space-y-4">
          <h1 class="text-center text-2xl font-semibold text-black">Log in</h1>

          <%= if @current_scope && @current_scope.user do %>
            <p class="text-center text-sm text-slate-600 dark:text-slate-300">
              You need to reauthenticate to perform sensitive actions on your account.
            </p>
          <% else %>
            <p class="text-center text-sm text-slate-600 dark:text-slate-300">
              Enter your email and password to sign in.
            </p>
          <% end %>

          <.form
            :let={f}
            for={@form}
            id="login_form_magic"
            action={~p"/users/log-in"}
            phx-submit="submit_magic"
            class="space-y-3"
          >
            <.input
              readonly={!!(@current_scope && @current_scope.user)}
              field={f[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              required
              phx-mounted={JS.focus()}
            />
            <.button class="btn btn-primary w-full">Log in with email</.button>
          </.form>

          <div class="divider">or</div>

          <.form
            :let={f}
            for={@form}
            id="login_form_password"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
            class="space-y-3"
          >
            <.input
              readonly={!!(@current_scope && @current_scope.user)}
              field={f[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              required
            />
            <.input field={@form[:password]} type="password" label="Password" autocomplete="current-password" />
            <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
              Log in
            </.button>
          </.form>

          <%= unless @current_scope && @current_scope.user do %>
            <.link navigate={~p"/users/register"} class="btn btn-primary w-full">Register</.link>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email, "remember_me" => false}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end
end
