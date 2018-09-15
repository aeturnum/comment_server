defmodule CommentServer.Content.Timestamp do
  alias CommentServer.Util.H
  alias __MODULE__

  # we do this odd transform back and forth because we want to eliminate the precision that can't be
  # captured in the unix time format
  def new(), do: DateTime.utc_now() |> to_db_format() |> from_db_format()
  def now(), do: new()
  def to_db_format(timestamp), do: DateTime.to_unix(timestamp)
  def from_db_format(timestamp), do: DateTime.from_unix!(timestamp)

  def within_range(timestamp, amount, unit) do
    H.debug(
      "within_range|now: #{now()} - #{timestamp} = #{
        inspect(DateTime.diff(now(), timestamp, unit))
      } < #{amount}"
    )

    amount > DateTime.diff(now(), timestamp, unit)
  end
end
