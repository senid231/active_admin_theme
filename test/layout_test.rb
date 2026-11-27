# Browser test (headless Chrome): the layout behaves as the visual contract says.
require_relative "capybara_boot"
require "minitest/autorun"
require "capybara/minitest"

class LayoutTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def setup
    page.current_window.resize_to(1280, 900)
  end

  def teardown
    Capybara.reset_sessions!
  end

  def test_desktop_has_top_menu_and_no_drawer
    visit "/admin/customers"
    assert_selector "#site-header nav a", text: "Customers"
    assert_no_selector "#main-menu", visible: :visible
  end

  def test_top_menu_breakpoint_is_768
    page.current_window.resize_to(768, 900)
    visit "/admin/customers"
    assert_selector "#site-header nav a", text: "Customers"
  end

  def test_menu_group_opens_on_hover
    visit "/admin/customers"
    assert_no_selector "#top-menu-demo_pages", visible: :visible
    find("#site-header nav a", text: "Demo pages").hover
    assert_selector "#top-menu-demo_pages a", text: "Wide table", visible: :visible
  end

  def test_nested_submenus_fly_out_on_hover
    visit "/admin/customers"
    find("#site-header nav a", text: "Demo pages").hover
    find("#top-menu-demo_pages a", text: "More demos").hover
    find("#top-menu-demo_pages a", text: "Even more").hover
    find("#top-menu-demo_pages a", text: "Deeper page").click
    assert_text "Fourth menu level."
    assert_selector "#site-header nav > ul > li > a.selected", text: "Demo pages"
  end

  def test_drawer_opens_the_branch_of_the_current_page
    page.current_window.resize_to(390, 800)
    visit "/admin/deeper_page"
    find("#site-header button[data-drawer-show='main-menu']").click
    assert_selector "#main-menu a", text: "Deeper page", visible: :visible
    find("#main-menu [data-item-id='even_more'] > [data-menu-button] button").click
    assert_no_selector "#main-menu a", text: "Deeper page", visible: :visible
  end

  def test_mobile_menu_opens_in_a_drawer
    page.current_window.resize_to(390, 800)
    visit "/admin/customers"
    assert_no_selector "#site-header nav a", text: "Customers"
    find("#site-header button[data-drawer-show='main-menu']").click
    assert_selector "#main-menu a", text: "Customers", visible: :visible
  end

  def test_filters_sit_left_of_the_table_on_desktop_and_above_on_mobile
    visit "/admin/customers"
    filters = page.evaluate_script("document.querySelector('[data-aat-sidebar]').getBoundingClientRect().toJSON()")
    table = page.evaluate_script("document.querySelector('table.data-table').getBoundingClientRect().toJSON()")
    assert_operator filters["right"], :<=, table["left"]

    page.current_window.resize_to(390, 800)
    visit "/admin/customers"
    filters = page.evaluate_script("document.querySelector('[data-aat-sidebar]').getBoundingClientRect().toJSON()")
    table = page.evaluate_script("document.querySelector('table.data-table').getBoundingClientRect().toJSON()")
    assert_operator filters["bottom"], :<=, table["top"]
  end

  def test_filters_collapse_and_the_table_takes_the_width
    visit "/admin/customers"
    before = page.evaluate_script("document.querySelector('.paginated-collection').getBoundingClientRect().width")
    find("[data-aat-sidebar-toggle]").click
    assert_no_selector "[data-aat-sidebar]", visible: :visible
    after = page.evaluate_script("document.querySelector('.paginated-collection').getBoundingClientRect().width")
    assert_operator after, :>, before + 200
    find("[data-aat-sidebar-toggle]").click
    assert_selector "[data-aat-sidebar]", visible: :visible
  end

  def test_wide_index_tables_scroll_inside_their_wrapper_not_the_page
    page.current_window.resize_to(390, 800)
    visit "/admin/customers"
    scroll = page.evaluate_script("document.documentElement.scrollWidth")
    assert_operator scroll, :<=, 390
    assert page.evaluate_script("(() => { const w = document.querySelector('.index-as-table'); return w.scrollWidth > w.clientWidth })()")
  end

  def test_index_cells_stay_on_one_line_and_other_tables_wrap
    visit "/admin/customers"
    assert_equal "nowrap", page.evaluate_script("getComputedStyle(document.querySelector('table.data-table tbody td')).whiteSpace")
    visit "/admin/components"
    assert_equal "normal", page.evaluate_script("getComputedStyle(document.querySelector('#table-for td')).whiteSpace")
  end

  def test_server_clock_renders_and_ticks
    visit "/admin/customers"
    assert_selector "[data-server-clock] .clock-time", text: /\A\d{2}:\d{2}:\d{2}\s+\S+\z/
    first = find("[data-server-clock] .clock-time").text
    assert_no_selector "[data-server-clock] .clock-time", text: first, wait: 3
    data = find("[data-server-clock] [data-servertime-epoch]", visible: :all)
    assert_equal Time.zone.tzinfo.identifier, data["data-servertime-zone"]
  end

  def test_server_clock_without_a_zone_keeps_the_server_text
    visit "/admin/customers"
    assert_selector "[data-server-clock] .clock-time", text: /\d{2}:\d{2}:\d{2}/
    execute_script(<<~JS)
      document.querySelector("[data-servertime]").removeAttribute("data-servertime-zone")
      document.querySelector("[data-server-clock] .clock-time").textContent = "12:00:00 SRV"
      document.dispatchEvent(new Event("turbo:load"))
    JS
    sleep 1.5
    assert_equal "12:00:00 SRV", find("[data-server-clock] .clock-time").text
  end

  def test_header_has_user_and_logout
    visit "/admin/customers"
    assert_selector "[data-test-current-user]", text: "Demo Admin"
    assert_selector "#site-header a.aat-logout"
  end

  def test_action_items_are_buttons
    visit "/admin/customers"
    background = page.evaluate_script("getComputedStyle(document.querySelector('[data-test-action-items] a')).backgroundColor")
    refute_equal "rgba(0, 0, 0, 0)", background
  end

  def test_crisscross_marks_row_and_column
    visit "/admin/customers"
    cells = all("table.data-table tbody tr:nth-child(2) td")
    cells[3].click
    assert_selector "table.data-table td[data-selected-cell]", count: 1
    assert_selector "table.data-table tbody td[data-selected]", minimum: 30
    assert_no_selector "table.data-table tbody tr.selected"
  end

  def test_tabs_switch_panels
    visit "/admin/customers/1"
    assert_selector "[role=tab]", count: 2
    assert_selector "#notes", visible: :visible
    assert_no_selector "#raw", visible: :visible
    find("[role=tab]", text: "Raw").click
    assert_selector "#raw", visible: :visible
    assert_no_selector "#notes", visible: :visible
  end

  def test_tabs_ids_are_unique_and_start_with_a_letter
    visit "/admin/tabs"
    ids = all("[id]", visible: :all).map { |element| element[:id] }
    assert_equal ids.uniq, ids
    assert_equal %w[summary tab-2024 explicit-1 summary-2 tab-2024-2 explicit-2 flow-links], all(".aat-tab-panel", visible: :all).map { |panel| panel[:id] }
    assert_selector "#flow-links-tab", text: "Flow Links"
    assert_empty all("[role=tab]", visible: :all).map { |tab| tab["data-tabs-target"] }.reject { |target| target.match?(/\A#[a-z]/) }
    second = all(".aat-tabs")[1]
    second.find("[role=tab]", text: "2024").click
    assert_selector "#tab-2024-2", text: "Year 2", visible: :visible
    assert_selector "#summary", text: "Summary 1", visible: :visible
    assert_no_selector "#summary-2", visible: :visible
  end

  def test_columns_split_by_ratio_and_stack_on_mobile
    visit "/admin/columns"
    widths = page.evaluate_script("[...document.querySelectorAll('.aat-columns')[0].children].map(c => c.getBoundingClientRect().width)")
    assert_in_delta 3.0, widths[1] / widths[0], 0.4
    page.current_window.resize_to(390, 800)
    visit "/admin/columns"
    tops = page.evaluate_script("[...document.querySelectorAll('.aat-columns')[0].children].map(c => c.getBoundingClientRect().top)")
    assert_operator tops[1], :>, tops[0]
    side = page.evaluate_script("[...document.querySelectorAll('.aat-columns')[1].children].map(c => c.getBoundingClientRect().top)")
    assert_equal side[0], side[1]
  end

  def test_columns_wrap_instead_of_clipping
    visit "/admin/columns"
    lines = page.evaluate_script("new Set([...document.querySelectorAll('.aat-columns')[4].children].map(c => Math.round(c.getBoundingClientRect().top))).size")
    assert_operator lines, :>, 1
  end

  def test_action_items_sit_below_the_title_on_a_phone_and_beside_it_on_a_desktop
    rect = ->(selector) { page.evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().toJSON()") }
    page.current_window.resize_to(390, 800)
    visit "/admin/confirm_dialog"
    assert_selector "#action-items > *", count: 4
    title = rect.call("#page-header h2")
    items = rect.call("#action-items")
    assert_operator items["top"], :>=, title["bottom"]
    assert_operator rect.call("#page-header > div")["width"], :>, 350
    assert page.evaluate_script("(() => { const e = document.querySelector('#page-header h2'); return e.scrollWidth <= e.clientWidth })()")
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, 390

    page.current_window.resize_to(1280, 900)
    visit "/admin/confirm_dialog"
    title = rect.call("#page-header h2")
    items = rect.call("#action-items")
    assert_operator items["left"], :>, title["right"]
    assert_operator items["top"], :<, title["bottom"]
    assert_in_delta 1280 - 16, items["right"], 20
  end

  def test_sidebar_title_keeps_a_string_name_and_titlecases_a_symbol
    I18n.backend.store_translations(:en, active_admin: {sidebars: {translated_one: "From I18n"}})
    visit "/admin/shipments/1"
    assert_equal ["Estimated spend", "Quick Notes", "From I18n"], all("[data-aat-sidebar] .panel .panel-title").map(&:text)
    visit "/admin/shipments"
    assert_selector "[data-aat-sidebar] .panel .panel-title", exact_text: "Filters"
  ensure
    I18n.backend.reload!
  end

  def test_show_page_and_sidebar_are_panels
    visit "/admin/customers/1"
    assert_selector ".panel .panel-title", text: "Customer Details"
    assert_selector "[data-aat-sidebar] .panel .panel-title", text: "Help"
  end
end
