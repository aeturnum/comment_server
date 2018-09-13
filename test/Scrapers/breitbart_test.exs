defmodule CommentServerTest.Scrapers.Breitbart do
  use ExUnit.Case
  alias CommentServer.Scrapers.Breitbart
  @moduletag :external

  test "scrape" do
    Breitbart.scrape(
      "http://www.breitbart.com/big-government/2018/05/09/disney-world-cancels-night-joy-christian-music-festival/"
    )
  end
end
