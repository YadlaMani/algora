defmodule AlgoraWeb.Components.UI.StatCard do
  @moduledoc false
  use AlgoraWeb.Component

  import AlgoraWeb.CoreComponents

  attr :href, :string, default: nil
  attr :navigate, :string, default: nil
  attr :patch, :string, default: nil
  attr :replace, :boolean, default: false
  attr :title, :string
  attr :value, :string, default: nil
  attr :subtext, :string, default: nil
  attr :icon, :string, default: nil

  slot :inner_block

  def stat_card(assigns) do
    ~H"""
    <%= if link?(assigns) do %>
      <.link href={@href} navigate={@navigate} patch={@patch} replace={@replace}>
        <.stat_card_content {assigns} />
      </.link>
    <% else %>
      <.stat_card_content {assigns} />
    <% end %>
    """
  end

  defp stat_card_content(assigns) do
    ~H"""
    <div class={
      classes([
        "group/card relative rounded-lg border bg-card text-card-foreground transition-colors duration-75",
        link?(assigns) && "hover:bg-accent"
      ])
    }>
      <div class="flex flex-row items-center justify-between space-y-0 p-6 pb-2">
        <h3 class="text-sm font-medium tracking-tight">{@title}</h3>
        <.icon :if={@icon} name={@icon} class="h-6 w-6 text-muted-foreground" />
      </div>
      <div class="p-6 pt-0">
        <div class="text-2xl font-bold font-display">
          <%= if @value do %>
            {@value}
          <% else %>
            {render_slot(@inner_block)}
          <% end %>
        </div>
        <p :if={@subtext} class="text-xs text-muted-foreground">
          {if @subtext == "", do: {:safe, "&nbsp;"}, else: @subtext}
        </p>
      </div>
    </div>
    """
  end

  defp link?(assigns) do
    Enum.any?([assigns[:href], assigns[:navigate], assigns[:patch]])
  end
end
