defmodule AlgoraWeb.Admin.LeaderboardLive do
  @moduledoc false
  use AlgoraWeb, :live_view

  import Ecto.Changeset
  import Ecto.Query

  alias Algora.Accounts
  alias Algora.Accounts.User
  alias Algora.Misc.CountryEmojis
  alias Algora.Payments.Transaction
  alias Algora.Repo

  def mount(_params, _session, socket) do
    top_earners = get_top_earners()
    {:ok, assign(socket, :top_earners, top_earners)}
  end

  def handle_event("toggle-need-avatar", %{"user-id" => user_id}, socket) do
    {:ok, _user} =
      user_id
      |> Accounts.get_user!()
      |> change()
      |> put_change(:need_avatar, true)
      |> Repo.update()

    # Refresh the data
    top_earners = get_top_earners()
    {:noreply, assign(socket, :top_earners, top_earners)}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <.header class="mb-8 text-3xl">
        Global Leaderboard
        <:subtitle>Top earners by country</:subtitle>
      </.header>

      <div class="grid grid-cols-1 gap-8">
        <%= for {country, users} <- @top_earners do %>
          <.card>
            <.card_header>
              <div class="flex items-center justify-between">
                <h3 class="text-2xl font-semibold text-gray-100">
                  {CountryEmojis.get(country)}
                  {if country, do: country, else: "Unknown Location"}
                </h3>
                <span class="font-display text-3xl font-semibold text-emerald-300">
                  {users
                  |> Enum.map(& &1.total_earned)
                  |> Enum.reduce(Money.zero(:USD), &Money.add!/2)
                  |> Money.to_string!()}
                </span>
              </div>
            </.card_header>
            <.data_table id={"leaderboard-#{country}"} rows={users}>
              <:col :let={user} label="User">
                <div class="flex items-center gap-4">
                  <input
                    type="checkbox"
                    class="h-6 w-6 rounded border-gray-300"
                    checked={user.need_avatar}
                    phx-click="toggle-need-avatar"
                    phx-value-user-id={user.id}
                  />
                  <.avatar class="h-24 w-24">
                    <.avatar_image src={user.avatar_url} alt={user.name} />
                    <.avatar_fallback class="text-lg">
                      {Algora.Util.initials(user.name)}
                    </.avatar_fallback>
                  </.avatar>
                  <div>
                    <div class="text-2xl font-semibold text-gray-100">{user.name}</div>
                    <div class="text-lg font-medium text-gray-300">@{User.handle(user)}</div>
                    <div class="font-mono text-lg font-medium text-indigo-400">{user.id}</div>
                  </div>
                </div>
              </:col>
              <:col :let={user} label="Earnings" align="right">
                <span class="font-display text-3xl font-semibold text-emerald-300">
                  {Money.to_string!(user.total_earned)}
                </span>
              </:col>
              <:col :let={user} label="Bounties" align="right">
                <span class="font-display text-3xl font-semibold text-cyan-300">
                  {user.transaction_count}
                </span>
              </:col>
            </.data_table>
          </.card>
        <% end %>
      </div>
    </div>
    """
  end

  defp get_top_earners do
    # First get the totals per user
    user_totals =
      from u in Accounts.User,
        join: t in Transaction,
        on: t.user_id == u.id and not is_nil(t.succeeded_at) and t.type == :credit,
        group_by: [u.id, u.name, u.provider_login, u.avatar_url, u.country, u.need_avatar],
        select: %{
          id: u.id,
          name: coalesce(u.name, u.handle),
          provider_login: u.provider_login,
          avatar_url: u.avatar_url,
          country: u.country,
          need_avatar: u.need_avatar,
          total_earned: sum(t.net_amount),
          transaction_count: count(t.id)
        }

    # Then get top 10 per country using a lateral join
    query =
      from u1 in subquery(user_totals),
        join: u2 in subquery(user_totals),
        on: u1.country == u2.country and u2.total_earned >= u1.total_earned,
        group_by: [
          u1.id,
          u1.name,
          u1.provider_login,
          u1.avatar_url,
          u1.country,
          u1.need_avatar,
          u1.total_earned,
          u1.transaction_count
        ],
        having: count(u2.id) <= 10,
        select: u1

    users = Repo.all(query)

    users
    |> Enum.group_by(& &1.country)
    |> Enum.map(fn {country, users} ->
      {country, Enum.sort_by(users, & &1.total_earned, {:desc, Money})}
    end)
    |> Enum.sort_by(
      fn {_country, users} ->
        users
        |> Enum.map(& &1.total_earned)
        |> Enum.reduce(Money.zero(:USD), &Money.add!/2)
      end,
      {:desc, Money}
    )
  end
end
