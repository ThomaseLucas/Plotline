defmodule PlotlineWeb.UserLive.Login do
  use PlotlineWeb, :live_view

  alias Plotline.Accounts

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
                Welcome back
              </h1>
              <p class="max-w-lg text-sm leading-6 text-slate-600 dark:text-slate-300">
                Sign in to continue. Use your email to receive a login link or sign in with a password.
              </p>
            </div>

            <div class="grid gap-3 text-sm text-base-content/70 sm:grid-cols-2">
              <div class="rounded-box border border-base-300 bg-base-200/60 p-4">
                Fast access for returning users.
              </div>
              <div class="rounded-box border border-base-300 bg-base-200/60 p-4">
                New here? Create an account in a few seconds.
              </div>
            </div>
          </section>

          <section class="rounded-xl border border-slate-100 bg-white dark:bg-slate-800/70 p-6 shadow-sm sm:p-8">
            <div class="space-y-4">
              <div class="text-center">
                <.header>
                  <p>Log in</p>
                  <:subtitle>
                    <%= if @current_scope do %>
                      You need to reauthenticate to perform sensitive actions on your account.
                    <% else %>
                      Don't have an account? <.link
                        navigate={~p"/users/register"}
                        class="font-semibold text-brand hover:underline"
                        phx-no-format
                      >Sign up</.link> for an account now.
                    <% end %>
                  </:subtitle>
                </.header>
              </div>

              <div :if={local_mail_adapter?()} class="alert alert-info">
                <.icon name="hero-information-circle" class="size-6 shrink-0" />
                <div>
                  <p class="font-medium">Local mail is enabled.</p>
                  <p>
                    Check <.link href="/dev/mailbox" class="underline">the mailbox page</.link> for sent emails.
                  </p>
                </div>
              </div>

              <.form :let={f} for={@form} id="login_form_magic" action={~p"/users/log-in"} phx-submit="submit_magic">
                <.input readonly={!!@current_scope} field={f[:email]} type="email" label="Email" autocomplete="username" spellcheck="false" required phx-mounted={JS.focus()} />
                <.button class="btn btn-primary w-full">Send login link</.button>
              </.form>

              <div class="divider my-0 text-sm text-base-content/50">or</div>

              <.form :let={f} for={@form} id="login_form_password" action={~p"/users/log-in"} phx-submit="submit_password" phx-trigger-action={@trigger_submit}>
                <.input readonly={!!@current_scope} field={f[:email]} type="email" label="Email" autocomplete="username" spellcheck="false" required />
                <.input field={@form[:password]} type="password" label="Password" autocomplete="current-password" spellcheck="false" />
                <.button class="btn btn-outline w-full mt-2" name={@form[:remember_me].name} value="true">Sign in</.button>
              </.form>
            </div>
          </section>
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

    form = to_form(%{"email" => email}, as: "user")

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

  defp local_mail_adapter? do
    Application.get_env(:plotline, Plotline.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
