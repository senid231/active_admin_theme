# Browser test (headless Chrome): a panel built with collapsible: true has a
# button for a title that shows and hides the body. The demo page loads the
# opt-in active_admin_theme/panel_toggle script.
require_relative "page_objects_helper"

module Pages
  class PanelToggleDemo < PO::Page
    set_url "/admin/panel_toggle"
  end
end

class PanelToggleTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def setup
    page.current_window.resize_to(1280, 900)
    visit "/admin/panel_toggle"
  end

  def teardown
    Capybara.reset_sessions!
  end

  def render_view(&block)
    Arbre::Context.new({}, ActionView::Base.empty, &block).to_s
  end

  def toggle(title, index = 0)
    all("button.aat-panel-toggle", text: title, exact_text: true)[index]
  end

  def demo
    Pages::PanelToggleDemo.new.tap(&:load)
  end

  def test_the_title_is_a_button_that_controls_the_body
    button = toggle("JSON")
    assert_equal "button", button.tag_name
    assert_equal "false", button["aria-expanded"]
    assert_equal "json-body", find("##{button["aria-controls"]} pre", visible: :all)[:id]
    assert_equal "h3", button.find(:xpath, "..").tag_name
  end

  def test_collapsed_starts_with_the_body_hidden_and_open_with_it_shown
    assert_no_selector "#json-body"
    assert_selector "#json-body", visible: :all
    assert_equal "true", toggle("Open")["aria-expanded"]
    assert_selector "#open-body", text: "Open by default"
  end

  def test_a_click_shows_and_hides_the_body
    toggle("JSON").click
    assert_selector "#json-body", text: "\"id\": 1"
    assert_equal "true", toggle("JSON")["aria-expanded"]
    toggle("JSON").click
    assert_no_selector "#json-body"
    assert_equal "false", toggle("JSON")["aria-expanded"]
  end

  # Enter and Space come from the browser for a native button; Cuprite's key
  # events do not trigger that activation, so check the element instead.
  def test_the_title_is_a_native_button
    assert_equal "button", toggle("JSON").tag_name
    assert_equal "button", toggle("JSON")[:type]
  end

  def test_the_event_bubbles_with_the_panel_and_the_state
    page.execute_script(<<~JS)
      window.toggles = []
      document.addEventListener("aat:panel:toggle", (e) => {
        window.toggles.push([e.detail.panel.querySelector(".panel-title").textContent.trim(), e.detail.expanded])
      })
    JS
    toggle("JSON").click
    toggle("JSON").click
    assert_equal [["JSON", true], ["JSON", false]], page.evaluate_script("window.toggles")
  end

  def test_a_plain_panel_is_unchanged
    assert_selector ".panel-title", text: "Plain", exact_text: true
    assert_no_selector "button.aat-panel-toggle", text: "Plain"
    assert_selector "#plain-body"
  end

  def test_collapsed_without_collapsible_leaves_the_panel_unchanged
    html = render_view { panel("x", collapsed: true) { para "Body" } }
    refute_includes html, "collapsed"
    refute_includes html, "<button"
    refute_includes html, "hidden"
  end

  def test_panels_with_the_same_title_get_their_own_ids
    first = toggle("Same title")
    second = toggle("Same title", 1)
    refute_equal first[:id], second[:id]
    refute_equal first["aria-controls"], second["aria-controls"]
    second.click
    assert_selector "##{second["aria-controls"]}", text: "Second"
    assert_no_selector "##{first["aria-controls"]}"
  end

  def test_an_explicit_id_is_kept_and_names_the_ids_of_the_parts
    assert_selector "#mine"
    assert_equal "mine-toggle", toggle("Explicit id")[:id]
    assert_equal "mine-body", toggle("Explicit id")["aria-controls"]
  end

  def test_a_panel_in_the_sidebar_toggles
    within("[data-aat-sidebar]") do
      assert_no_selector "#sidebar-body"
      toggle("Sidebar details").click
      assert_selector "#sidebar-body", text: "Inside the sidebar"
    end
  end

  def test_the_server_renders_the_state_and_escapes_the_title
    html = render_view { panel("Raw <b>", collapsible: true, collapsed: true) { para "Body" } }
    assert_includes html, %(aria-expanded="false")
    assert_includes html, "aat-panel-collapsible"
    assert_match(/<div class="panel-body"[^>]* hidden=""/, html)
    assert_includes html, "Raw &lt;b&gt;"
  end

  def test_the_page_object_reads_and_changes_the_state
    json = demo.panel("JSON")
    assert json.collapsible?
    refute json.expanded?
    assert_same json, json.expand
    assert json.expanded?
    assert_equal "{ \"id\": 1 }", json.body.text
    json.collapse
    refute json.expanded?
    json.toggle
    assert json.expanded?
  end

  def test_the_page_object_treats_a_plain_panel_as_open
    plain = demo.panel("Plain")
    refute plain.collapsible?
    assert plain.expanded?
    error = assert_raises(ArgumentError) { plain.collapse }
    assert_match(/not collapsible/, error.message)
  end
end
