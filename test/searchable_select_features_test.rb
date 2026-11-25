# Browser test (headless Chrome): what the select script does beyond the plain
# searchable select. Plain selects upgraded on their own, per-select settings,
# the lazy and load-all modes, and a three-level chain.
require_relative "capybara_boot"
require "minitest/autorun"
require "capybara/minitest"

class SearchableSelectFeaturesTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  OPTION = ".ts-dropdown-content .option[data-value]:not(.loading-more-results)".freeze

  def setup
    page.current_window.resize_to(1280, 900)
  end

  def teardown
    Capybara.reset_sessions!
  end

  # --- plain selects ---

  def test_form_selects_are_upgraded_with_a_search_box_and_a_remove_button
    visit "/admin/shipments/new"
    carrier = wrapper_for("shipment[carrier]")
    open_dropdown(carrier)
    assert_equal Shipment::CARRIERS, carrier.all(OPTION).map(&:text)
    search(carrier, "ra")
    carrier.assert_selector OPTION, count: 1
    assert_equal ["Rail"], carrier.all(OPTION).map(&:text)
    carrier.find(OPTION, text: "Rail").click
    carrier.assert_selector ".item", text: "Rail"
    assert_equal "Rail", find("select[name='shipment[carrier]']", visible: :all).value
    carrier.find(".item .remove").click
    carrier.assert_no_selector ".item"
    assert_equal "", find("select[name='shipment[carrier]']", visible: :all).value
  end

  def test_filter_selects_are_upgraded_and_filter_the_index
    visit "/admin/shipments"
    carrier = wrapper_for("q[carrier_eq]")
    assert_equal "Any", carrier.find(".ts-control input", visible: :all)[:placeholder]
    open_dropdown(carrier)
    carrier.assert_selector ".dropdown-input"
    carrier.find(OPTION, text: "Rail").click
    click_button "Filter"
    assert_selector "table.data-table tbody tr", count: Shipment.where(carrier: "Rail").count
    wrapper_for("q[carrier_eq]").assert_selector ".item", text: "Rail"
  end

  def test_boolean_filter_has_no_search_box_and_can_be_cleared
    visit "/admin/shipments"
    insured = wrapper_for("q[insured_eq]")
    assert_equal '"Any"', page.evaluate_script("getComputedStyle(document.querySelector('.filters-form-field.boolean .ts-control'), '::before').content")
    open_dropdown(insured)
    insured.assert_no_selector ".dropdown-input"
    insured.find(OPTION, text: "Yes").click
    click_button "Filter"
    assert_selector "table.data-table tbody tr", count: Shipment.where(insured: true).count
    wrapper_for("q[insured_eq]").find(".item .remove").click
    click_button "Filter"
    assert_selector "table.data-table tbody tr", count: Shipment.count
  end

  def test_predicate_select_is_upgraded_and_still_renames_the_input
    visit "/admin/shipments"
    predicate = find(".filters-form-field.string select[data-search-methods]", visible: :all).find(:xpath, "following-sibling::div[contains(@class, 'ts-wrapper')][1]")
    open_dropdown(predicate)
    predicate.assert_no_selector ".dropdown-input"
    predicate.assert_no_selector ".remove"
    predicate.find(OPTION, text: "Starts with").click
    assert_selector "input[name='q[reference_start]']"
    fill_in "q[reference_start]", with: "SHP-03"
    click_button "Filter"
    assert_selector "table.data-table tbody tr", count: 1
  end

  def test_opt_out_leaves_the_select_native
    visit "/admin/shipments/new"
    assert_selector "select[name='shipment[size]'][data-tom-select='false']", visible: :visible
    assert_no_selector :xpath, "//select[@name='shipment[size]']/following-sibling::div[contains(@class, 'ts-wrapper')]"
    select "M", from: "shipment[size]"
    visit "/admin/shipments"
    assert_selector "select[name='q[size_eq]']", visible: :visible
  end

  def test_errored_field_is_upgraded
    visit "/admin/shipments/new"
    fill_in "Reference", with: "SHP-ERR"
    click_button "Create Shipment"
    assert_selector "li.select.error .field_with_errors select[name='shipment[carrier]']", visible: :all
    carrier = wrapper_for("shipment[carrier]")
    open_dropdown(carrier)
    carrier.find(OPTION, text: "Sea").click
    click_button "Create Shipment"
    assert_text "Shipment was successfully created"
  end

  def test_selects_added_later_are_upgraded_and_templates_are_skipped
    visit "/admin/shipments/new"
    assert_no_selector "select[name*='parcels_attributes']", visible: :all
    click_link "Add New Parcel"
    kind = find("select[name*='parcels_attributes'][name$='[kind]']", visible: :all)
    wrapper = kind.find(:xpath, "following-sibling::div[contains(@class, 'ts-wrapper')][1]")
    open_dropdown(wrapper)
    wrapper.find(OPTION, text: "pallet").click
    assert_equal "pallet", kind.value

    visit "/admin/select_lab"
    assert_equal false, page.evaluate_script("Boolean(document.getElementById('lab-template').content.querySelector('select').tomselect)")
    assert_no_selector "#lab-target .ts-wrapper"
    click_button "Add a select"
    assert_selector "#lab-target .ts-wrapper"
    assert_equal false, page.evaluate_script("Boolean(document.getElementById('lab-template').content.querySelector('select').tomselect)")
  end

  def test_data_attribute_upgrades_a_select_outside_forms
    visit "/admin/select_lab"
    assert_selector "#lab-explicit .ts-wrapper"
    assert_no_selector "#lab-plain .ts-wrapper"
    assert_selector "#lab-plain select", visible: :visible
  end

  # --- per-select settings ---

  def test_create_adds_a_typed_value
    visit "/admin/shipments/new"
    fill_in "Reference", with: "SHP-TAG"
    pick_plain("shipment[carrier]", "Air")
    tag = wrapper_for("shipment[tag]")
    open_dropdown(tag)
    search(tag, "bulky")
    tag.find(".create", text: "Add bulky").click
    tag.assert_selector ".item", text: "bulky"
    click_button "Create Shipment"
    assert_text "Shipment was successfully created"
    assert_equal "bulky", Shipment.find_by!(reference: "SHP-TAG").tag

    visit "/admin/shipments"
    tag = wrapper_for("q[tag_eq]")
    open_dropdown(tag)
    search(tag, "bulky")
    tag.find(".create", text: "Add bulky").click
    click_button "Filter"
    assert_selector "table.data-table tbody tr", count: Shipment.where(tag: "bulky").count
    wrapper_for("q[tag_eq]").assert_selector ".item", text: "bulky"
  end

  def test_allow_empty_option_offers_the_blank_option_as_a_row
    visit "/admin/shipments/new"
    priority = wrapper_for("shipment[priority]")
    open_dropdown(priority)
    assert_equal %w[None low high], priority.all(OPTION, minimum: 3).map(&:text)
    priority.find(OPTION, text: "high").click
    open_dropdown(priority)
    priority.find(OPTION, text: "None").click
    priority.assert_selector ".item", text: "None"
    assert_equal "", find("select[name='shipment[priority]']", visible: :all).value
  end

  # --- lazy mode ---

  def test_lazy_select_waits_for_three_characters
    visit "/admin/shipments/new"
    product = wrapper_for("shipment[product_id]")
    open_dropdown(product)
    product.assert_selector ".not-loading", text: "Type 3 chars to search..."
    product.assert_no_selector OPTION
    search(product, "Pr")
    product.assert_selector ".not-loading"
    product.assert_no_selector OPTION
    search(product, "o")
    product.assert_selector OPTION, count: 50
    product.assert_no_selector ".not-loading"
    search(product, "zzz")
    product.assert_selector ".no-results", text: "No results matched"
  end

  def test_three_spaces_fetch_the_unfiltered_list
    visit "/admin/shipments/new"
    product = wrapper_for("shipment[product_id]")
    open_dropdown(product)
    search(product, "   ")
    product.assert_selector OPTION, count: 50
    assert_equal "Product 120 (SKU-381)", product.first(OPTION).text
  end

  def test_scrolling_loads_more_pages
    visit "/admin/shipments/new"
    product = wrapper_for("shipment[product_id]")
    open_dropdown(product)
    search(product, "Product")
    product.assert_selector OPTION, count: 50
    scroll_dropdown_to_bottom
    product.assert_selector OPTION, count: 100
    scroll_dropdown_to_bottom
    product.assert_selector OPTION, count: 120
    product.assert_selector ".no-more-results", text: "No more results"
    assert_equal "Product 001 (SKU-500)", product.all(OPTION).last.text
  end

  def test_a_new_query_replaces_the_results_and_an_earlier_query_comes_back
    visit "/admin/shipments/new"
    product = wrapper_for("shipment[product_id]")
    open_dropdown(product)
    search(product, "Product 02")
    product.assert_selector OPTION, count: 10
    search(product, "3")
    product.assert_selector OPTION, count: 1
    assert_equal "Product 023 (SKU-478)", product.find(OPTION).text
    product.find(".dropdown-input").send_keys(:backspace)
    product.assert_selector OPTION, count: 10
    # Below the minimum the results go, and typing the query again loads its first page.
    8.times { product.find(".dropdown-input").send_keys(:backspace) }
    product.assert_selector ".not-loading"
    product.assert_no_selector OPTION
    search(product, "oduct 02")
    product.assert_selector OPTION, count: 10
  end

  def test_returning_to_a_paged_query_starts_from_its_first_page
    visit "/admin/shipments/new"
    product = wrapper_for("shipment[product_id]")
    open_dropdown(product)
    search(product, "Product")
    product.assert_selector OPTION, count: 50
    6.times { product.find(".dropdown-input").send_keys(:backspace) }
    product.assert_no_selector OPTION
    search(product, "roduct")
    product.assert_selector OPTION, count: 50
    assert_equal "Product 120 (SKU-381)", product.first(OPTION).text
  end

  def test_typing_a_paged_query_again_starts_from_its_first_page
    visit "/admin/shipments/new"
    product = wrapper_for("shipment[product_id]")
    open_dropdown(product)
    search(product, "Product")
    product.assert_selector OPTION, count: 50
    # Closed and reopened: the same query is typed while its second page is still due.
    page.execute_script("document.querySelector(\"select[name='shipment[product_id]']\").tomselect.blur()")
    product.assert_no_selector ".ts-dropdown", visible: :visible
    open_dropdown(product)
    search(product, "Product")
    assert_no_selector ".ts-wrapper.loading, .ts-wrapper.searching"
    product.assert_selector OPTION, count: 50
    assert_equal "Product 120 (SKU-381)", product.first(OPTION).text
    scroll_dropdown_to_bottom
    product.assert_selector OPTION, count: 100

    # Three characters back and forth without a pause.
    input = product.find(".dropdown-input")
    input.send_keys(:backspace, :backspace, :backspace, "uct")
    assert_no_selector ".ts-wrapper.loading, .ts-wrapper.searching"
    product.assert_selector OPTION, minimum: 50
    assert_equal "Product 120 (SKU-381)", product.first(OPTION).text
  end

  def test_browsing_select_shows_its_first_page_again_after_a_pick
    visit "/admin/shipments/new"
    pick("shipment[country_id]", "Country 05")
    country = wrapper_for("shipment[country_id]")
    open_dropdown(country)
    country.assert_selector OPTION, minimum: 20
  end

  def test_selected_items_survive_a_new_query
    visit "/admin/cities"
    country = wrapper_for("q[country_id_in][]")
    country.find(".ts-control").click
    country.find(".ts-control > input").send_keys("Country 05")
    assert_no_selector ".ts-wrapper.loading, .ts-wrapper.searching"
    country.assert_selector OPTION, count: 1
    country.find(OPTION, text: "Country 05").click
    # A multiple select keeps the typed text after a pick.
    country.find(".ts-control > input").send_keys([:backspace] * 2, "06")
    assert_no_selector ".ts-wrapper.loading, .ts-wrapper.searching"
    country.assert_selector OPTION, count: 1, text: "Country 06"
    country.find(OPTION, text: "Country 06").click
    assert_equal ["Country 05", "Country 06"], country.all(".item").map { |item| item.text.delete("×").strip }
    assert_equal 2, find("select[name='q[country_id_in][]']", visible: :all).value.size
  end

  def test_per_page_is_sent_to_the_endpoint
    visit "/admin/shipments/new"
    sku = wrapper_for("shipment[product_sku]")
    open_dropdown(sku)
    search(sku, "SKU")
    sku.assert_selector OPTION, count: 10
    assert_equal "SKU-381 Product 120", sku.first(OPTION).text
  end

  def test_value_other_than_the_id_is_submitted_and_shown_again
    visit "/admin/shipments/new"
    fill_in "Reference", with: "SHP-SKU"
    pick_plain("shipment[carrier]", "Air")
    sku = wrapper_for("shipment[product_sku]")
    open_dropdown(sku)
    search(sku, "SKU-499")
    sku.find(OPTION, text: "SKU-499 Product 002").click
    click_button "Create Shipment"
    assert_text "Shipment was successfully created"
    shipment = Shipment.find_by!(reference: "SHP-SKU")
    assert_equal "SKU-499", shipment.product_sku

    visit "/admin/shipments/#{shipment.id}/edit"
    wrapper_for("shipment[product_sku]").assert_selector ".item", text: "SKU-499 Product 002"
    visit "/admin/shipments?q[product_sku_eq]=SKU-499"
    wrapper_for("q[product_sku_eq]").assert_selector ".item", text: "SKU-499 Product 002"
    assert_selector "table.data-table tbody tr", count: Shipment.where(product_sku: "SKU-499").count
  end

  # --- load-all mode and chains ---

  def test_load_all_fetches_every_page_and_filters_in_the_browser
    visit "/admin/shipments/new"
    pick("shipment[country_id]", "Country 05")
    city = wrapper_for("shipment[city_id]")
    open_dropdown(city)
    # Two per page: the three cities come from two requests.
    city.assert_selector OPTION, count: 3
    search(city, "City 2")
    city.assert_selector OPTION, count: 1
    assert_equal ["Country 05 City 2"], city.all(OPTION).map(&:text)
  end

  def test_load_all_refetches_when_the_parent_changes
    visit "/admin/shipments/new"
    pick("shipment[country_id]", "Country 05")
    city = wrapper_for("shipment[city_id]")
    open_dropdown(city)
    city.assert_selector OPTION, count: 3
    city.find(OPTION, text: "Country 05 City 2").click
    pick("shipment[country_id]", "Country 06")
    city = wrapper_for("shipment[city_id]")
    city.assert_no_selector ".item"
    open_dropdown(city)
    city.assert_selector OPTION, count: 3
    assert_equal ["Country 06 City 1", "Country 06 City 2", "Country 06 City 3"], city.all(OPTION).map(&:text).sort
  end

  def test_clearing_the_first_select_of_a_chain_resets_the_ones_below
    visit "/admin/shipments/new"
    assert_selector ".ts-wrapper.disabled", count: 2
    pick("shipment[country_id]", "Country 05")
    pick_plain("shipment[city_id]", "Country 05 City 1")
    pick_plain("shipment[street_id]", "Country 05 City 1 Street 2")
    assert_no_selector ".ts-wrapper.disabled"

    wrapper_for("shipment[country_id]").find(".item .remove").click
    assert_selector ".ts-wrapper.disabled", count: 2
    wrapper_for("shipment[city_id]").assert_no_selector ".item"
    wrapper_for("shipment[street_id]").assert_no_selector ".item"
    assert_equal ["", ""], %w[city_id street_id].map { |name| find("select[name='shipment[#{name}]']", visible: :all).value.to_s }
  end

  def test_changing_the_middle_select_resets_only_the_one_below
    visit "/admin/shipments/new"
    pick("shipment[country_id]", "Country 05")
    pick_plain("shipment[city_id]", "Country 05 City 1")
    pick_plain("shipment[street_id]", "Country 05 City 1 Street 2")
    pick_plain("shipment[city_id]", "Country 05 City 2")
    wrapper_for("shipment[country_id]").assert_selector ".item", text: "Country 05"
    street = wrapper_for("shipment[street_id]")
    street.assert_no_selector ".item"
    open_dropdown(street)
    assert_equal ["Country 05 City 2 Street 1", "Country 05 City 2 Street 2"], street.all(OPTION, count: 2).map(&:text)
  end

  def test_page_load_keeps_a_preselected_chain
    visit "/admin/shipments/1/edit"
    wrapper_for("shipment[country_id]").assert_selector ".item", text: "Country 05"
    wrapper_for("shipment[city_id]").assert_selector ".item", text: "Country 05 City 1"
    wrapper_for("shipment[street_id]").assert_selector ".item", text: "Country 05 City 1 Street 1"
    assert_no_selector ".ts-wrapper.disabled"
    # Load-all has run by now and must not have dropped the selection.
    street = wrapper_for("shipment[street_id]")
    open_dropdown(street)
    street.assert_selector OPTION, count: 2
    street.assert_selector ".item", text: "Country 05 City 1 Street 1"

    shipment = Shipment.find(1)
    visit "/admin/shipments?q[country_id_eq]=#{shipment.country_id}&q[city_id_eq]=#{shipment.city_id}&q[street_id_eq]=#{shipment.street_id}"
    wrapper_for("q[city_id_eq]").assert_selector ".item", text: "Country 05 City 1"
    wrapper_for("q[street_id_eq]").assert_selector ".item", text: "Country 05 City 1 Street 1"
    assert_no_selector ".filters-form .ts-wrapper.disabled"
    assert_selector "table.data-table tbody tr", count: Shipment.where(street_id: shipment.street_id).count
  end

  private

  def wrapper_for(name)
    find(:xpath, "//select[@name='#{name}']/following-sibling::div[contains(@class, 'ts-wrapper')][1]", visible: :all)
  end

  def search(wrapper, text)
    wrapper.find(".dropdown-input").send_keys(text)
  end

  def open_dropdown(wrapper)
    wrapper.find(".ts-control").click unless wrapper.has_css?(".ts-dropdown", visible: :visible, wait: false)
    wrapper.assert_selector ".ts-dropdown", visible: :visible
  end

  # A select that loads its options: type, then pick.
  def pick(name, text)
    wrapper = wrapper_for(name)
    open_dropdown(wrapper)
    search(wrapper, text)
    assert_no_selector ".ts-wrapper.loading, .ts-wrapper.searching"
    wrapper.assert_selector OPTION, count: 1, text: text
    wrapper.find(OPTION, text: text).click
    wrapper_for(name).assert_selector ".item", text: text
  end

  def pick_plain(name, text)
    wrapper = wrapper_for(name)
    open_dropdown(wrapper)
    wrapper.find(OPTION, exact_text: text).click
    wrapper_for(name).assert_selector ".item", text: text
  end

  def scroll_dropdown_to_bottom
    page.execute_script("const c = document.querySelector('.ts-wrapper.dropdown-active .ts-dropdown-content'); c.scrollTop = c.scrollHeight")
  end
end
