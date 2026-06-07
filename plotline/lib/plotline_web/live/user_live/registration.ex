defmodule PlotlineWeb.UserLive.Registration do
  use PlotlineWeb, :live_view

  alias Plotline.Accounts
  alias Plotline.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen flex items-center justify-center bg-slate-50 dark:bg-slate-900">
        <div class="w-full max-w-sm space-y-4">
          <h1 class="text-center text-2xl font-semibold">Register</h1>

          <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate" class="space-y-3">
            <.input field={@form[:email]} type="email" label="Email" autocomplete="username" required />
            <.input field={@form[:password]} type="password" label="Password" autocomplete="new-password" />
            <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">Create account</.button>
          </.form>

          <.link navigate={~p"/users/log-in"} class="btn btn-primary w-full">Log in</.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: PlotlineWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
