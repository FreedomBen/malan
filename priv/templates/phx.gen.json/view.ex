defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>View do
  use <%= inspect context.web_module %>, :view
  alias <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>View

  def render("index.json", %{code: code, page_num: page_num, page_size: page_size, <%= schema.plural %>: <%= schema.plural %>}) do
    %{
      ok: true,
      code: code,
      page_num: page_num,
      page_size: page_size,
      data: render_many(<%= schema.plural %>, <%= inspect schema.alias %>View, "<%= schema.singular %>.json")
    }
    %{data: render_many(<%= schema.plural %>, <%= inspect schema.alias %>View, "<%= schema.singular %>.json")}
  end

  def render("show.json", %{code: code, <%= schema.singular %>: <%= schema.singular %>}) do
    %{ok: true, code: code, data: render_one(<%= schema.singular %>, <%= inspect schema.alias %>View, "<%= schema.singular %>.json")}
  end

  def render("<%= schema.singular %>.json", %{<%= schema.singular %>: <%= schema.singular %>}) do
    %{
<%= [{:id, :id} | schema.attrs] |> Enum.map(fn {k, _} -> "      #{k}: #{schema.singular}.#{k}" end) |> Enum.join(",\n")  %>
    }
  end
end
