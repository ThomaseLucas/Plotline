defmodule PlotlineWeb.UserLive.Registration do
  use PlotlineWeb, :live_view

  alias Plotline.Accounts
  alias Plotline.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-[calc(100vh-5rem)] bg-slate-50 dark:bg-slate-900">
        <div class="mx-auto grid min-h-[calc(100vh-5rem)] max-w-4xl items-center gap-8 px-4 py-12 sm:px-6 lg:grid-cols-[1fr_420px] lg:px-8">
          <section class="space-y-4">
            <span class="badge badge-outline">Plotline</span>
            <div class="space-y-3">
              <h1 class="text-2xl font-semibold tracking-tight sm:text-3xl text-slate-900 dark:text-slate-100">
                Create your demo account
              </h1>
              <p class="max-w-lg text-sm leading-6 text-slate-600 dark:text-slate-300">
                Use a work or demo email and you'll receive a confirmation to get started quickly.
              </p>
            </div>

            <div class="grid gap-3 text-sm text-base-content/70 sm:grid-cols-2">
              <div class="rounded-box border border-base-300 bg-base-200/60 p-4">
                Minimal sign-up flow.
              </div>
              <div class="rounded-box border border-base-300 bg-base-200/60 p-4">
                Designed for a fast live demo.
              </div>
            </div>
          </section>

          <section class="rounded-xl border border-slate-100 bg-white dark:bg-slate-800/70 p-6 shadow-sm">
            <div class="text-center">
              <.header>
                Register for an account
                <:subtitle>
                  Already registered?
                  <.link navigate={~p"/users/log-in"} class="font-semibold text-slate-700 dark:text-slate-200 hover:underline">
                    Log in
                  </.link>
                  to your account now.
                </:subtitle>
              </.header>
            </div>

            <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
              <.input field={@form[:email]} type="email" label="Email" autocomplete="username" spellcheck="false" required phx-mounted={JS.focus()} />

              <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">Create account</.button>
            </.form>
          </section>
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
