# Demo of collapsible panels: one starts closed, one open, one is plain, and
# two share a title. One sits in the sidebar.
ActiveAdmin.register_page "Panel toggle" do
  menu false

  sidebar "Notes" do
    panel "Sidebar details", collapsible: true, collapsed: true do
      para "Inside the sidebar", id: "sidebar-body"
    end
  end

  content do
    panel "JSON", collapsible: true, collapsed: true do
      pre "{ \"id\": 1 }", id: "json-body"
    end

    panel "Open", collapsible: true do
      para "Open by default", id: "open-body"
    end

    panel "Plain" do
      para "Not collapsible", id: "plain-body"
    end

    panel "Same title", collapsible: true, collapsed: true do
      para "First"
    end

    panel "Same title", collapsible: true, collapsed: true do
      para "Second"
    end

    panel "Explicit id", collapsible: true, id: "mine" do
      para "Kept id"
    end
  end
end
