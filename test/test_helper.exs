Mox.defmock(RestApiMock, for: RestApiBase)
Application.put_env(:trading_bot_ex, :mexc_rest_api, RestApiMock)

Application.ensure_all_started(:mox)
ExUnit.start()
