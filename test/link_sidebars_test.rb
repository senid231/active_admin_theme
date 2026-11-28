# Browser test (headless Chrome): related_records_sidebar and
# external_links_sidebar on the customer show page, and their page object.
require_relative "page_objects_helper"

class LinkSidebarsTest < PageObjectsTestCase
  Sidebars = ActiveAdminTheme::LinkSidebars

  def show(id)
    Pages::CustomerShow.new.tap { |show| show.load(id: id) }
  end

  def variant(name, title)
    visit "/admin/customers/1?links=#{name}"
    link_list(Pages::CustomerShow.new, title)
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
    assert_equal [nil, nil], links.map(&:group)
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
    assert_equal [2, 3], config.sidebar_sections.map(&:priority)
  end

  def test_a_sidebar_without_a_block_raises
    error = assert_raises(ArgumentError) { Sidebars.add(Struct.new(:sidebar_sections).new([]), :related_records, nil, {}, nil) }
    assert_match(/needs a block/, error.message)
  end

  def test_more_than_five_links_in_two_groups_get_headings
    list = variant("many", "Many links")
    assert_equal %w[Shipping Billing], list.groups
    assert_selector "#many-links_sidebar_section ul.aat-link-list", count: 3
    assert_equal %w[Overview Parcels Labels Returns Invoices Payments], list.links.map(&:label)
    assert_equal [nil, "Shipping", "Shipping", "Shipping", "Billing", "Billing"], list.links.map(&:group)
    assert_equal %w[Parcels Labels Returns], list.links(group: "Shipping").map(&:label)
    assert_equal %w[Invoices Payments], list.links(group: "Billing").map(&:label)
  end

  def test_each_group_list_is_labelled_by_its_heading
    variant("many", "Many links")
    headings = all("#many-links_sidebar_section h4.aat-link-group")
    ids = headings.map { |heading| heading[:id] }
    assert_equal 2, ids.uniq.size
    lists = all("#many-links_sidebar_section ul.aat-link-list")
    assert_nil lists.first["aria-labelledby"]
    assert_equal ids, lists.drop(1).map { |list| list["aria-labelledby"] }
  end

  def test_two_groups_of_four_links_are_one_flat_list
    list = variant("few", "Few links")
    assert_equal [], list.groups
    assert_selector "#few-links_sidebar_section ul.aat-link-list", count: 1
    assert_no_selector ".aat-link-group"
    assert_equal %w[Parcels Labels Invoices Payments], list.links.map(&:label)
    assert_equal [nil] * 4, list.links.map(&:group)
  end

  def test_one_group_is_a_flat_list_however_many_links_it_has
    list = variant("single", "One group")
    assert_equal [], list.groups
    assert_equal 6, list.links.size
    assert_selector "#one-group_sidebar_section ul.aat-link-list", count: 1
  end

  def test_group_headings_true_shows_headings_for_a_few_links
    list = variant("on", "Headings on")
    assert_equal %w[Shipping Billing], list.groups
    assert_equal [nil, "Shipping", "Billing"], list.links.map(&:group)
  end

  def test_group_headings_false_keeps_declaration_order_in_one_list
    list = variant("off", "Headings off")
    assert_equal [], list.groups
    assert_selector "#headings-off_sidebar_section ul.aat-link-list", count: 1
    assert_equal ["Parcel 1", "Parcel 2", "Parcel 3", "Overview", "Invoice 1", "Invoice 2", "Invoice 3"], list.links.map(&:label)
  end

  def test_a_group_whose_links_are_all_hidden_is_left_out
    list = variant("hidden", "Hidden group")
    assert_equal ["Open"], list.groups
    assert_equal %w[Overview Door], list.links.map(&:label)
    assert_no_text "Secret"
  end

  def test_a_count_is_a_value_a_relation_or_a_lambda_returning_either
    list = variant("many", "Many links")
    counts = list.links.to_h { |link| [link.label, link.count] }
    assert_equal Order.where(customer_id: 1).count, counts["Parcels"]
    assert_equal Order.where(customer_id: 1, status: "paid").count, counts["Labels"]
    assert_equal [nil, nil, nil], counts.values_at("Overview", "Returns", "Payments")
    assert_equal 7, counts["Invoices"]
    assert_selector "#many-links_sidebar_section .aat-link-count", count: 3
  end

  def test_a_count_object_is_called_for_its_count
    view = Object.new
    count_of = ->(count) { Sidebars::Section.allocate.count_of(view, Sidebars::Link.new(count: count)) }
    assert_equal 3, count_of.call(Struct.new(:count).new(3))
    assert_equal 2, count_of.call([1, 2])
    assert_equal 4, count_of.call(-> { [1, 2, 3, 4] })
    assert_equal 5, count_of.call(5)
    assert_equal "99+", count_of.call("99+")
    assert_nil count_of.call(nil)
  end

  def test_an_unknown_group_headings_value_raises
    error = assert_raises(ArgumentError) { Sidebars.add(Struct.new(:sidebar_sections).new([]), :related_records, nil, {group_headings: :always}, proc { link "A", "/a" }) }
    assert_match(/group_headings: :always is not one of :auto, true, false/, error.message)
  end

  def test_groups_do_not_nest
    collector = Sidebars::Collector.new(nil)
    error = assert_raises(ArgumentError) { collector.group("A") { collector.group("B") { collector.link("L", "/l") } } }
    assert_match(/groups do not nest/, error.message)
    collector.group("A") { collector.link("L", "/l") }
    collector.link("M", "/m")
    assert_equal ["A", nil], collector.links.map(&:group)
  end

  def test_an_unknown_link_option_raises
    error = assert_raises(ArgumentError) { Sidebars::Collector.new(nil).link("A", "/a", badge: 1) }
    assert_match(/unknown option :badge, known options are :count, :if/, error.message)
  end

  def test_a_related_link_can_open_a_new_tab
    list = variant("tab", "New tab")
    assert_equal [false, true], list.links.map(&:new_tab?)
    assert_equal [false, false], list.links.map(&:external?)
    logs = all("a", text: "Logs").first
    assert_equal ["_blank", "noopener noreferrer"], [logs[:target], logs[:rel]]
  end

  def test_external_links_come_first_by_default
    config = Struct.new(:sidebar_sections).new([])
    block = proc { link "A", "/a" }
    Sidebars.add(config, :related_records, nil, {}, block)
    Sidebars.add(config, :external_links, nil, {}, block)
    Sidebars.add(config, :external_links, nil, {priority: 7}, block)
    assert_equal [2, 1, 7], config.sidebar_sections.map { |section| section.options[:priority] }
  end
end
