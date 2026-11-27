# Two tabs components with the same titles, and a numeric title: the generated
# ids stay unique and usable as CSS selectors.
ActiveAdmin.register_page "Tabs" do
  menu false

  content do
    2.times do |index|
      tabs do
        tab("Summary") { para "Summary #{index + 1}" }
        tab(2024) { para "Year #{index + 1}" }
        tab("Explicit", id: "explicit-#{index + 1}") { para "Explicit #{index + 1}" }
      end
    end
    tabs do
      tab(:flow_links) { para "Flow links" }
    end
  end
end
