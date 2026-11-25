# Browser test (headless Chrome): the base gem's select fields and filters
# drive the Tom Select widget of an upgraded select, and the native select of
# one left alone. The searchable select classes add the widget's own API.
require_relative "page_objects_helper"

class PageObjectsSelectControlTest < PageObjectsTestCase
  PO = ActiveAdminPageObjects

  def new_shipment
    Pages::ShipmentForm.new.tap { |form_page| form_page.load(action: "new") }.form
  end

  def shipments
    Pages::ShipmentIndex.new.tap(&:load)
  end

  def test_plain_select_field_goes_through_the_widget
    form = new_shipment
    carrier = form.field(:carrier)
    assert_instance_of PO::Form::SelectField, carrier
    assert_selector "#shipment_carrier_input .ts-wrapper"
    assert_equal Shipment::CARRIERS, carrier.options
    assert_nil carrier.selected
    carrier.fill("Rail")
    assert_equal "Rail", carrier.selected
    assert_selector "#shipment_carrier_input .ts-control .item", text: "Rail"
    assert_no_selector "#shipment_carrier_input .ts-dropdown", visible: true
    assert form.has_enabled_field?(:carrier)
  end

  def test_opted_out_select_field_stays_native
    form = new_shipment
    size = form.field(:size)
    assert_no_selector "#shipment_size_input .ts-wrapper"
    size.fill("M")
    assert_equal "M", size.selected
    assert_equal Shipment::SIZES, size.options
  end

  def test_form_fill_submits_plain_and_searchable_selects
    form = new_shipment
    form.fill(reference: "SHP-PO-1", carrier: "Sea", size: "L", product: "Product 042 (SKU-459)")
    form.submit
    shipment = Shipment.find_by!(reference: "SHP-PO-1")
    assert_equal ["Sea", "L", "Product 042"], [shipment.carrier, shipment.size, shipment.product.name]
  end

  def test_plain_select_filter_goes_through_the_widget
    index = shipments
    carrier = index.filters.filter(:carrier)
    assert_instance_of PO::SelectFilter, carrier
    assert carrier.has_option?("Road")
    assert carrier.has_no_option?("Boat")
    carrier.select_option("Road")
    assert carrier.has_selected?("Road")
    assert carrier.has_item?("Road")
    assert carrier.has_no_disabled?
    index.filters.submit
    assert index.table.has_rows?(count: Shipment.where(carrier: "Road").count)
    assert index.filters.filter(:carrier).has_selected?("Road")
  end

  def test_opted_out_select_filter_stays_native
    index = shipments
    size = index.filters.filter(:size)
    size.select_option("M")
    assert size.has_selected?("M")
    index.filters.submit
    assert index.table.has_rows?(count: Shipment.where(size: "M").count)
  end

  def test_boolean_filter_goes_through_the_widget
    index = shipments
    insured = index.filters.filter(:insured)
    insured.select_option("Yes")
    index.filters.submit
    assert index.table.has_rows?(count: Shipment.where(insured: true).count)
  end

  def test_predicate_filter_picks_its_predicate_in_the_widget
    index = shipments
    reference = index.filters.filter(:reference)
    reference.fill_in(with: "SHP-03", predicate: :start)
    assert_equal "Starts with", reference.predicate
    index.filters.submit
    assert index.table.has_rows?(count: 1)
    assert index.filters.filter(:reference).has_value?("SHP-03", predicate: :start)
  end

  def test_searchable_classes_drive_a_plain_select_too
    page_class = Class.new(PO::Page) do
      set_url "/admin/shipments/new"
      section :form, PO::Form do
        field :carrier, "Carrier", ActiveAdminTheme::PageObjects::SearchableSelectField
        field :tag, "Tag", ActiveAdminTheme::PageObjects::SearchableSelectField
      end
    end
    form = page_class.new.tap(&:load).form
    carrier = form.field(:carrier)
    carrier.search("ra")
    assert carrier.has_no_option?("Air")
    assert_equal ["Rail"], carrier.options
    carrier.fill("Rail", search: false)
    assert_equal ["Rail"], carrier.chosen
    carrier.remove("Rail")
    assert_empty carrier.chosen

    tag = form.field(:tag)
    tag.create_option("bulky")
    assert_equal ["bulky"], tag.chosen
    assert_equal "bulky", tag.selected
  end

  def test_lazy_select_shows_its_messages_and_loads_more
    product = new_shipment.field(:product)
    assert_instance_of Theme::SearchableSelectField, product
    product.open
    assert_equal "Type 3 chars to search...", product.message
    product.search("zzz")
    assert product.has_message?("No results matched")
    product.close

    product.search("   ")
    assert_equal 50, product.options.size
    assert_equal 100, product.load_more.size
    assert_equal 120, product.load_more.size
    assert_equal "No more results", product.message
    product.fill("Product 001 (SKU-500)", search: false)
    assert_equal "Product 001 (SKU-500)", product.selected
  end

  def test_filter_with_create_adds_a_value
    page_class = Class.new(PO::Page) do
      set_url "/admin/shipments"
      section :filters, PO::Filters do
        filter :tag_eq, "Tag", ActiveAdminTheme::PageObjects::SearchableSelectFilter
      end
    end
    filters = page_class.new.tap(&:load).filters
    filters.filter(:tag_eq).create_option("rare")
    assert filters.filter(:tag_eq).has_item?("rare")
    filters.submit
    assert_text "No Shipments found"
    assert_equal ["rare"], page_class.new.filters.filter(:tag_eq).chosen
  end

  def test_chain_of_dependent_fields
    form = new_shipment
    assert form.has_disabled_field?(:city)
    assert form.has_disabled_field?(:street)
    form.fill(country: "Country 05", city: "Country 05 City 2", street: "Country 05 City 2 Street 1")
    assert_equal "Country 05 City 2 Street 1", form.field(:street).selected
    form.field(:country).clear
    assert form.has_disabled_field?(:city)
    assert form.has_disabled_field?(:street)
    assert_nil form.field(:street).selected
  end
end
