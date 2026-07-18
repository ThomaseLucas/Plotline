defmodule PlotlineWeb.UserSessionController do
  use PlotlineWeb, :controller

  alias Plotline.Accounts
  alias PlotlineWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "User confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # email + password login (or magic link when password is blank)
  defp create(conn, %{"user" => user_params} = params, info) do
    %{"email" => email} = user_params
    password = Map.get(user_params, "password", "")
    conn = store_return_to_from_params(conn, params)
    return_to = auth_return_to(conn, params)

    cond do
      password != "" ->
        if user = Accounts.get_user_by_email_and_password(email, password) do
          conn
          |> put_flash(:info, info)
          |> UserAuth.log_in_user(user, user_params)
        else
          conn
          |> put_flash(:error, "Invalid email or password")
          |> put_flash(:email, String.slice(email, 0, 160))
          |> redirect(to: return_to)
        end

      true ->
        if user = Accounts.get_user_by_email(email) do
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )
        end

        conn
        |> put_flash(
          :info,
          "If your email is in our system, you will receive instructions for logging in shortly."
        )
        |> redirect(to: return_to)
    end
  end

  defp store_return_to_from_params(conn, params) do
    case params["return_to"] do
      "/" <> _ = path ->
        if UserAuth.valid_return_to_path?(path) do
          put_session(conn, :user_return_to, path)
        else
          conn
        end

      _ ->
        conn
    end
  end

  defp auth_return_to(_conn, %{"return_to" => "/"}), do: ~p"/"

  defp auth_return_to(conn, params) do
    case params["return_to"] do
      "/" <> _ = path when is_binary(path) ->
        if UserAuth.valid_return_to_path?(path) do
          ~p"/users/log-in?#{%{return_to: path}}"
        else
          ~p"/users/log-in"
        end

      _ ->
        case get_session(conn, :user_return_to) do
          "/" <> _ = path -> ~p"/users/log-in?#{%{return_to: path}}"
          _ -> ~p"/users/log-in"
        end
    end
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    {:ok, {_user, expired_tokens}} = Accounts.update_user_password(user, user_params)

    # disconnect all existing LiveViews with old sessions
    UserAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
