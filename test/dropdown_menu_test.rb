# Browser test (headless Chrome): the dropdown_menu component opens, closes and follows its links.
# The aria-expanded, Escape and arrow-key tests need the active_admin_theme/dropdown_menu script.
require_relative "page_objects_helper"

module Pages
  class DropdownMenuDemo < PO::Page
    set_url "/admin/dropdown_menu"
  end
end

class DropdownMenuTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  PAGE = "/admin/dropdown_menu".freeze

  def setup
    page.current_window.resize_to(1280, 900)
    visit PAGE
  end

  def teardown
    Capybara.reset_sessions!
  end

  def toggle(label, index = 0)
    all("button.aat-dropdown-toggle", text: label, exact_text: true)[index]
  end

  def menu_of(toggle)
    find("##{toggle["aria-controls"]}", visible: :all)
  end

  def style(node, property)
    page.evaluate_script("getComputedStyle(arguments[0]).#{property}", node)
  end

  def test_markup_has_menu_roles_and_ids_unique_per_label
    first = toggle("Export")
    second = toggle("Export", 1)
    assert_equal "menu", first["aria-haspopup"]
    assert_equal "false", first["aria-expanded"]
    refute_equal first["data-dropdown-toggle"], second["data-dropdown-toggle"]
    assert_equal first["aria-controls"], first["data-dropdown-toggle"]
    assert_equal "menu", menu_of(first)[:role]
    assert_equal first[:id], menu_of(first)["aria-labelledby"]
    assert_equal ["menuitem"], menu_of(first).all("a", visible: :all).map { |link| link["role"] }.uniq
  end

  def test_the_list_is_closed_until_the_button_is_clicked
    assert_no_selector ".aat-dropdown-menu", visible: :visible
    toggle("More").click
    assert_selector "##{toggle("More")["aria-controls"]}", visible: :visible
    assert_link "Archive"
  end

  def test_an_outside_click_closes_the_list
    toggle("More").click
    assert_link "Archive"
    find("h2").click
    assert_no_selector ".aat-dropdown-menu", visible: :visible
  end

  def test_opening_one_dropdown_leaves_the_other_closed
    toggle("Export").click
    assert_selector ".aat-dropdown-menu", visible: :visible, count: 1
    assert_link "CSV"
    assert_no_link "XML"
  end

  def test_aria_expanded_follows_the_list
    button = toggle("More")
    button.click
    assert_selector "button.aat-dropdown-toggle[aria-expanded=true]", text: "More"
    button.click
    assert_selector "button.aat-dropdown-toggle[aria-expanded=false]", text: "More"
  end

  def test_escape_closes_the_list_and_returns_focus_to_the_button
    toggle("More").click
    assert_link "Archive"
    page.send_keys(:escape)
    assert_no_selector ".aat-dropdown-menu", visible: :visible
    assert_selector "button.aat-dropdown-toggle:focus", text: "More"
  end

  def test_arrow_keys_move_through_the_links
    toggle("More").send_keys(:down)
    assert_selector "a[role=menuitem]:focus", text: "Archive"
    page.send_keys(:down)
    assert_selector "a[role=menuitem]:focus", text: "Delete"
    page.send_keys(:up)
    assert_selector "a[role=menuitem]:focus", text: "Archive"
  end

  def test_text_is_escaped_and_a_link_follows
    toggle("Export").click
    click_link "Fish & Chips"
    assert_text 'GET {"to":"fish"}'
  end

  def test_a_link_with_a_method_and_confirm_asks_first
    toggle("More").click
    assert_equal "Delete it?", accept_confirm { click_link "Delete" }
    assert_text "DELETE"
  end

  def test_declining_the_confirm_stays_on_the_page
    toggle("Export").click
    dismiss_confirm { click_link "Purge" }
    assert_current_path PAGE
  end

  def test_the_block_form_and_the_builder_in_the_page_body_work
    toggle("Export", 1).click
    assert_link "XML"
    toggle("Panel menu").click
    assert_link "Open"
    assert_equal "panel-menu", toggle("Panel menu")["aria-controls"]
  end

  def test_no_items_renders_nothing
    assert_no_selector "button.aat-dropdown-toggle", text: "Empty"
  end

  def test_the_button_looks_like_an_action_item
    plain = find("#action-items a", text: "Plain")
    %w[backgroundColor color fontSize fontWeight borderRadius paddingTop paddingLeft].each do |property|
      assert_equal style(plain, property), style(toggle("More"), property), property
    end
  end

  def test_the_open_list_is_on_top_and_in_the_viewport
    toggle("Export").click
    link = find("a", text: "CSV")
    top_element = page.evaluate_script(<<~JS, link)
      (function(link) {
        const box = link.getBoundingClientRect()
        const hit = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2)
        return hit === link || link.contains(hit)
      })(arguments[0])
    JS
    assert top_element
    right = page.evaluate_script("arguments[0].getBoundingClientRect().right", link)
    assert_operator right, :<=, 1280
  end
end

class DropdownMenuPageObjectTest < PageObjectsTestCase
  def demo
    @demo ||= Pages::DropdownMenuDemo.new.tap(&:load)
  end

  def test_find_by_label_from_the_action_items
    more = demo.action_items.dropdown("More")
    assert_equal "More", more.label
    assert_equal %w[Archive Delete], more.items
    assert more.has_item?("archive")
    assert more.has_no_item?("Purge", wait: 0)
  end

  def test_open_close_and_open_state
    more = demo.dropdown_menu("More")
    refute more.open?
    more.open
    assert more.open?
    assert more.has_open?
    more.close
    assert more.has_no_open?
    refute more.open?
  end

  def test_click_opens_the_list_and_follows_the_link
    demo.action_items.dropdown("More").click("Archive")
    assert_text 'GET {"to":"archive"}'
  end

  def test_an_unknown_item_raises
    error = assert_raises(Capybara::ElementNotFound) { demo.action_items.dropdown("More").click("Nope") }
    assert_match(/no dropdown item "Nope"/, error.message)
  end

  def test_all_in_lists_every_dropdown_of_the_scope
    labels = Theme::DropdownMenu.all_in(demo.action_items).map(&:label)
    assert_equal %w[Export Export More], labels
  end

  def test_the_page_dropdown_is_found_without_a_label_when_alone_in_its_scope
    panel = demo.panel("Dropdown in the page")
    assert_equal %w[Open Close], Theme::DropdownMenu.find_in(panel).items
  end

  def test_two_dropdowns_with_one_label_are_ambiguous
    assert_raises(Capybara::Ambiguous) { demo.action_items.dropdown("Export") }
  end
end
