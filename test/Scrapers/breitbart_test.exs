defmodule CommentServerTest.Scrapers.Breitbart do
  use ExUnit.Case
  alias CommentServer.Scrapers.Breitbart
  @moduletag :external

  test "scrape" do
    {:ok, article} =
      Article.create(
        "http://www.breitbart.com/big-government/2018/05/09/disney-world-cancels-night-joy-christian-music-festival/"
      )

    {:ok, article} = Article.insert(article)
    Breitbart.scrape(article)
  end
end
