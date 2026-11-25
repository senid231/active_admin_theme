# Browser test (headless Chrome): with ActiveAdminTheme.searchable_select_all
# off, only the selects that ask for the widget get it. Its own process: the
# dummy app reads SEARCHABLE_SELECT_ALL once, at boot.
ENV["SEARCHABLE_SELECT_ALL"] = "0"
require_relative "page_objects_helper"

class SearchableSelectOffTest < PageObjectsTestCase
  def test_the_setting_reaches_the_page
    visit "/admin/shipments/new"
    config = JSON.parse(find("#active-admin-theme-config", visible: :all).text(:all))
    assert_equal false, config.dig("searchableSelect", "all")
    assert_equal 3, config.dig("searchableSelect", "minChars")
    assert_equal "No results matched", config.dig("searchableSelect", "texts", "noResults")
  end

  def test_plain_selects_stay_native
    visit "/admin/shipments/new"
    assert_selector "#shipment_product_input .ts-wrapper"
    assert_no_selector "#shipment_carrier_input .ts-wrapper"
    assert_selector "select[name='shipment[carrier]']", visible: :visible
    visit "/admin/shipments"
    assert_no_selector "#q_carrier_input .ts-wrapper, .filters-form-field.boolean .ts-wrapper"
    assert_no_selector ".filters-form-field.string .ts-wrapper"
  end

  def test_tom_select_option_still_upgrades_a_select
    visit "/admin/shipments/new"
    assert_selector "#shipment_tag_input .ts-wrapper"
    assert_selector "#shipment_priority_input .ts-wrapper"
    visit "/admin/select_lab"
    assert_selector "#lab-explicit .ts-wrapper"
  end

  def test_page_objects_drive_the_native_selects
    form_page = Pages::ShipmentForm.new
    form_page.load(action: "new")
    form_page.form.fill(reference: "SHP-OFF", carrier: "Rail", tag: "fragile", product: "Product 007 (SKU-494)")
    assert_equal "Rail", form_page.form.field(:carrier).selected
    form_page.form.submit
    shipment = Shipment.find_by!(reference: "SHP-OFF")
    assert_equal ["Rail", "fragile", 7], [shipment.carrier, shipment.tag, shipment.product_id]

    index = Pages::ShipmentIndex.new
    index.load
    index.filters.filter(:carrier).select_option("Rail")
    index.filters.submit
    assert index.table.has_rows?(count: Shipment.where(carrier: "Rail").count)
  end
end
