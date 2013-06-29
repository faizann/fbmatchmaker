-module(fbmatchmaker_shortcuts).
-compile(export_all).

render_ok(Req, TemplateModule, Params) ->
    {ok, Output} = TemplateModule:render(Params),
    % Here we use mochiweb_request:ok/1 to render a reponse
    Req:ok({"text/html", Output}).
