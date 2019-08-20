defmodule HTTPoisonTest do

  def post(url, request, headers, opts \\ [])

  def post("https://api.anti-captcha.com/createTask", _request, _headers, _opts) do
    :timer.sleep 40
    { :ok,
      %HTTPoison.Response{  body: ~S({"errorId":0,"taskId":1234567}),
                            headers: httpoison_headers(),
                            status_code: 200}
    }
  end
  def post("https://api.anti-captcha.com/getTaskResult", _request, _headers, _opts) do
    :timer.sleep 10
    { :ok,
      %HTTPoison.Response{  body: response(),
                            headers: httpoison_headers(),
                            status_code: 200}
    }
  end

  def response do
    ~S({"errorId":0,"status":"ready","solution":{"text":"deditur","url":"http://61.39.233.233/1/147220556452507.jpg"},"cost":"0.000700","ip":"46.98.54.221","createTime":1472205564,"endTime":1472205570,"solveCount":"0"})
  end

  def httpoison_headers do
    [  {"Server", "nginx/1.10.2"},
       {"Date", "Sun, 05 Feb 2017 16:26:54 GMT"},
       {"Content-Type", "application/json; charset=utf-8"},
       {"Transfer-Encoding", "chunked"},
       {"Connection", "keep-alive"},
       {"X-Powered-By", "PHP/5.4.45"},
       {"Access-Control-Allow-Origin", "*"},
       {"Access-Control-Allow-Headers",
        "Overwrite, Destination, Content-Type, Depth, User-Agent, X-File-Size, X-Requested-With, If-Modified-Since, X-File-Name, Cache-Control"}
      ]
  end

end
