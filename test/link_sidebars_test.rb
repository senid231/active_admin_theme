# Browser test (headless Chrome): related_records_sidebar and
# external_links_sidebar on the customer show page, and their page object.
require_relative "page_objects_helper"

class LinkSidebarsTest < PageObjectsTestCase
  Sidebars = ActiveAdminTheme::LinkSidebars

  def show(id)
    Pages::CustomerShow.new.tap { |show| show.load(id: id) }
  end

  def link_list(show, title)
    Theme::LinkList.find_in(show.sidebar.panel(title).body)
  end

  def test_related_records_are_plain_links_with_a_count
    show = show(1)
    assert_includes show.sidebar.titles, "Related records"
    links = link_list(show, "Related records").links
    assert_equal ["Orders", "Paid orders"], links.map(&:label)
    assert_equal [Order.where(customer_id: 1).count, nil], links.map(&:count)
    assert_equal [false, false], links.map(&:external?)
    assert links.first.href.end_with?("/admin/orders?q%5Bcustomer_id_eq%5D=1")
    assert_no_selector "#related-records_sidebar_section a[target]"
  end

  def test_external_links_open_in_a_new_tab
    show = show(1)
    links = link_list(show, "External links").links
    assert_equal ["Billing", "Mail"], links.map(&:label)
    assert_equal "https://billing.example/customers/1", links.first.href
    assert_equal "https://mail.example/search?q=customer1%40example.com", links.last.href
    assert links.all?(&:external?)
    assert_equal ["noopener noreferrer"], all("#external-links_sidebar_section a", minimum: 1).map { |link| link[:rel] }.uniq
  end

  def test_a_link_whose_condition_is_false_is_left_out
    show = show(2)
    assert_equal ["Orders"], link_list(show, "Related records").links.map(&:label)
  end

  def test_a_sidebar_with_no_links_is_not_rendered
    assert show(1).sidebar.has_no_panel?("Closed accounts")
    show = show(4)
    assert show.sidebar.has_panel?("Closed accounts")
    assert_equal ["Archive"], link_list(show, "Closed accounts").links.map(&:label)
  end

  def test_the_sidebars_show_on_the_show_page_only
    index = Pages::CustomerIndex.new
    index.load
    assert index.sidebar.has_no_panel?("Related records")
    assert index.sidebar.has_no_panel?("External links")
  end

  def test_clicking_a_link_follows_it
    show = show(3)
    link_list(show, "Related records").click("Orders")
    assert_selector "table.data-table tbody tr", count: Order.where(customer_id: 3).count
    assert_includes page.current_url, "q%5Bcustomer_id_eq%5D=3"
  end

  def test_the_title_comes_from_i18n
    original = I18n.t("active_admin_theme.sidebars.external_links")
    I18n.backend.store_translations(:en, active_admin_theme: {sidebars: {external_links: "Elsewhere"}})
    show = show(1)
    assert show.sidebar.has_panel?("Elsewhere")
    assert show.sidebar.has_no_panel?("External links")
  ensure
    I18n.backend.store_translations(:en, active_admin_theme: {sidebars: {external_links: original}})
  end

  def test_the_sidebar_is_a_panel_with_a_list_of_links
    visit "/admin/customers/1"
    assert_selector "[data-aat-sidebar] .panel .panel-body ul.aat-link-list > li > a", minimum: 4
  end

  def test_a_sidebar_shows_on_the_show_page_by_default_and_passes_the_options_on
    block = proc { link "A", "/a" }
    config = Struct.new(:sidebar_sections).new([])
    Sidebars.add(config, :related_records, nil, {}, block)
    Sidebars.add(config, :external_links, "Mine", {except: :index, priority: 3}, block)
    assert_equal [[:show], nil], config.sidebar_sections.map { |section| section.options[:only] }
    assert_equal [nil, [:index]], config.sidebar_sections.map { |section| section.options[:except] }
    assert_equal ["Related records", "Mine"], config.sidebar_sections.map(&:display_title)
    assert_equal [10, 3], config.sidebar_sections.map(&:priority)
  end

  def test_a_sidebar_without_a_block_raises
    error = assert_raises(ArgumentError) { Sidebars.add(Struct.new(:sidebar_sections).new([]), :related_records, nil, {}, nil) }
    assert_match(/needs a block/, error.message)
  end

  def test_an_unknown_link_option_raises
    error = assert_raises(ArgumentError) { Sidebars::Collector.new(nil).link("A", "/a", badge: 1) }
    assert_match(/unknown option :badge, known options are :count, :if/, error.message)
  end
end
