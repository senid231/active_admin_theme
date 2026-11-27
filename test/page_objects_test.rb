# Browser test (headless Chrome): the sections of active_admin_page_objects
# work on theme pages, with the theme's patches for the menus, tabs and sidebar.
require_relative "page_objects_helper"

class PageObjectsTest < PageObjectsTestCase
  def test_layout_elements
    index = Pages::CustomerIndex.new
    index.load
    assert_equal "ActiveAdmin Theme Demo", index.site_title.text
    assert index.has_page_title?(text: "Customers")
    assert index.has_dark_mode_toggle?
    assert index.has_no_user_menu_button?
    assert_equal "Demo Admin", index.current_user.text
    assert index.has_logout_link?
    assert index.has_server_clock?
    assert index.has_no_blank_slate?
  end

  def test_breadcrumbs_and_action_items
    show = Pages::CustomerShow.new
    show.load(id: 1)
    assert show.breadcrumbs.has_labels?("Admin", "Customers")
    assert_equal ["Edit Customer", "Delete Customer"], show.action_items.labels
    show.action_items.click("Edit Customer")
    assert Pages::CustomerForm.new.has_page_title?(text: "Edit Customer")
  end

  def test_top_menu_reads_nested_levels
    index = Pages::CustomerIndex.new
    index.load
    menu = index.main_menu
    assert_equal ["Dashboard", "Customers", "Demo pages"], menu.labels
    assert_includes menu.labels("Demo pages"), "More demos"
    assert_equal ["Deep page", "Even more"], menu.labels("Demo pages", "More demos")
    assert_equal ["Deeper page"], menu.labels("Demo pages", "More demos", "Even more")
    assert menu.has_item?("Demo pages", "More demos", "Even more", "Deeper page")
    assert menu.has_no_item?("Demo pages", "Deeper page")
    assert_equal ["Customers"], menu.current_labels
  end

  def test_top_menu_clicks_through_the_flyouts
    index = Pages::CustomerIndex.new
    index.load
    index.main_menu.click("Demo pages", "More demos", "Even more", "Deeper page")
    assert_text "Fourth menu level."
    assert_equal ["Demo pages", "More demos", "Even more", "Deeper page"], Pages::DeeperPage.new.main_menu.current_labels
  end

  def test_top_menu_goes_to_a_nested_item
    index = Pages::CustomerIndex.new
    index.load
    index.main_menu.go("Demo pages", "More demos", "Deep page")
    assert_text "Third menu level."
    error = assert_raises(ArgumentError) { index.main_menu.go("Demo pages") }
    assert_match(/has no link/, error.message)
  end

  def test_drawer_reads_and_clicks_nested_levels
    phone
    index = Pages::CustomerIndex.new
    index.load
    menu = index.main_menu
    assert_equal ["Dashboard", "Customers", "Demo pages"], menu.labels
    assert_equal ["Deep page", "Even more"], menu.labels("Demo pages", "More demos")
    assert_equal ["Customers"], menu.current_labels
    menu.click("Demo pages", "More demos", "Even more", "Deeper page")
    assert_text "Fourth menu level."
    assert_equal ["Demo pages", "More demos", "Even more", "Deeper page"], Pages::DeeperPage.new.main_menu.current_labels
  end

  def test_drawer_clicks_a_top_level_item
    phone
    deeper = Pages::DeeperPage.new
    deeper.load
    assert deeper.has_main_menu_button?
    deeper.main_menu.click("Customers")
    assert Pages::CustomerIndex.new.has_page_title?(text: "Customers")
  end

  def test_menu_without_javascript
    Capybara.using_driver(:rack_test) do
      index = Pages::CustomerIndex.new
      index.load
      assert_equal ["Deep page", "Even more"], index.main_menu.labels("Demo pages", "More demos")
      index.main_menu.click("Demo pages", "More demos", "Deep page")
      assert_text "Third menu level."
    end
  end

  def test_table
    index = Pages::CustomerIndex.new
    index.load
    table = index.table
    assert table.has_exact_columns?
    assert table.has_rows?(count: 30)
    row = table.row(1)
    assert_equal "1", row.record_id
    assert row.has_cell?(:name, exact_text: "Customer 1")
    assert table.has_no_row?(99_999)
    assert_equal %w[CSV XML JSON], index.download_links.formats
  end

  def test_filters_and_blank_slate
    index = Pages::CustomerIndex.new
    index.load
    filters = index.filters
    filters.filter(:name).fill_in(with: "Customer 12", predicate: "Equals")
    filters.filter(:status).select_option("closed")
    filters.submit
    assert index.table.has_rows?(count: 1)
    assert index.table.row(12).has_cell?(:name, exact_text: "Customer 12")
    assert index.filters.filter(:status).has_selected?("closed")

    index.filters.filter(:name).fill_in(with: "Nobody")
    index.filters.submit
    assert index.has_blank_slate?(text: "No Customers found")
    index.filters.clear
    assert index.table.has_rows?(count: 30)
  end

  def test_scopes
    index = Pages::CustomerIndex.new
    index.load
    assert_equal %w[All Active], index.scopes.labels
    assert index.scopes.has_selected?("All")
    index.scopes.select("Active")
    assert index.scopes.has_selected?("Active")
    assert_equal Customer.where(status: "active").count, index.scopes.count("Active")
  end

  def test_pagination
    index = Pages::OrderIndex.new
    index.load
    assert index.pagination.has_current_page?(1)
    index.pagination.next_page
    assert index.pagination.has_current_page?(2)
    index.pagination.go_to(1)
    assert_equal 1, index.pagination.current_page
  end

  def test_form_flashes_and_batch_actions
    form_page = Pages::CustomerForm.new
    form_page.load(action: "new")
    form = form_page.form
    form.submit
    assert form.has_field_error?(:name, "can't be blank")
    assert form.has_exact_field_errors?(name: "can't be blank")

    form.fill(name: "Batch Me", email: "batch@example.com", status: "pending")
    assert_equal "pending", form.field(:status).selected
    form.submit
    show = Pages::CustomerShow.new
    assert show.flashes.has_flash?(:notice, "Customer was successfully created.")
    assert_equal "Batch Me", show.attributes_table.value(:name)

    id = Customer.find_by!(name: "Batch Me").id
    index = Pages::CustomerIndex.new
    index.load
    index.table.row(id).select
    assert index.batch_actions.has_action?("Delete Selected")
    index.batch_actions.apply(:destroy)
    assert index.flashes.has_flash?(:notice, "Successfully deleted 1 customer")
    assert index.table.has_no_row?(id)
  end

  def test_show_page_panel_and_attributes_table
    show = Pages::CustomerShow.new
    show.load(id: 2)
    details = show.panel("Customer Details")
    assert_equal "Customer Details", details.title
    assert details.body.has_css?(".attributes-table")
    table = show.attributes_table
    assert table.has_row?(:email, exact_text: "customer2@example.com")
    assert_equal "Customer 2", table.value(:name)
    assert show.panel("Notes").body.has_text?("Note for customer 2.")
  end

  def test_sidebar_sections_are_panels
    show = Pages::CustomerShow.new
    show.load(id: 2)
    assert_equal ["Help"], show.sidebar.titles
    assert_equal "Sidebar content shows inside a panel.", show.sidebar.panel("Help").body.text
    assert show.sidebar.has_no_panel?("Filters")

    index = Pages::CustomerIndex.new
    index.load
    assert index.sidebar.has_panel?("Filters")
    assert Pages::Dashboard.new.tap(&:load).has_no_sidebar?
  end

  def test_sidebar_collapses_and_expands
    index = Pages::CustomerIndex.new
    index.load
    refute index.sidebar_collapsed?
    index.collapse_sidebar
    assert index.sidebar_collapsed?
    assert index.has_no_sidebar?
    index.expand_sidebar
    assert index.has_sidebar?
  end

  def test_tabs
    show = Pages::CustomerShow.new
    show.load(id: 2)
    tabs = show.tabs
    assert_equal %w[Notes Raw], tabs.titles
    assert tabs.has_tab?("Raw")
    assert tabs.has_no_tab?("History")
    assert_equal "Notes", tabs.selected
    assert tabs.content.has_text?("Note for customer 2.")

    tabs.select("Raw")
    assert tabs.has_selected?("Raw")
    assert tabs.has_no_selected?("Notes")
    assert tabs.content.has_text?("name: Customer 2")
    assert_match(/Note for customer 2/, tabs.content("Notes").text(:all))
    assert_raises(Capybara::ElementNotFound) { tabs.select("History") }
  end

  def test_tabs_take_a_regexp_title
    show = Pages::CustomerShow.new
    show.load(id: 2)
    tabs = show.tabs
    assert tabs.has_tab?(/\ARa/)
    assert tabs.has_no_tab?(/History/)
    assert tabs.has_selected?(/\ANotes\z/)
    assert tabs.has_no_selected?(/Raw/)
    tabs.select_matching(/raw/i)
    assert tabs.has_selected?(/\ARaw/)
    assert tabs.has_no_selected?(/Notes/)
    assert tabs.content(/\ANotes/).has_text?(:all, "Note for customer 2.")
    tabs.select(/\ANotes/)
    assert tabs.has_selected?("notes")
    assert_raises(Capybara::ElementNotFound) { tabs.select_matching(/History/) }
  end

  def test_declared_sidebar_section_is_found_by_title
    show = Pages::CustomerShow.new
    show.load(id: 2)
    assert_equal "Sidebar content shows inside a panel.", show.help.body.text
    assert show.has_selector?(:active_admin_sidebar, /\AHel/)
    assert show.has_no_selector?(:active_admin_sidebar, "Notes")
    assert show.has_selector?(:active_admin_panel, "Notes", visible: :all)
    assert show.sidebar.has_panel?(/\Ahelp\z/i)
    assert show.sidebar.has_no_panel?("Notes")
  end
end
