# Browser test (headless Chrome): a select whose search box was typed into
# stays closed, and leaves the focus alone, once its dropdown has closed.
require_relative "page_objects_helper"

class SearchableSelectFocusTest < PageObjectsTestCase
  CARRIER = "#shipment_carrier_input".freeze
  PRIORITY = "#shipment_priority_input".freeze
  # Tom Select refreshes the options 300 ms after the last keystroke.
  REFRESH_THROTTLE = 0.5

  class ShipmentForm < ActiveAdminPageObjects::Page
    set_url "/admin/shipments/new"

    section :form, ActiveAdminPageObjects::Form do
      field :carrier, "Carrier", ActiveAdminTheme::PageObjects::SearchableSelectField
      field :priority, "Priority", ActiveAdminTheme::PageObjects::SearchableSelectField
    end
  end

  def test_typing_then_picking_the_chosen_option_again_leaves_the_next_select_open
    visit "/admin/shipments/new"
    open_and_pick(CARRIER, "Rail")
    open_and_pick(CARRIER, "Rail", type: "Rail")
    find("#{PRIORITY} .ts-control").click
    sleep REFRESH_THROTTLE
    assert_open PRIORITY
    assert_closed CARRIER
    assert_no_focus_in CARRIER
    assert_selector "#{CARRIER} .ts-control .item", text: "Rail"
  end

  def test_typing_then_leaving_the_select_keeps_the_focus_where_the_user_put_it
    visit "/admin/shipments/new"
    find("#{CARRIER} .ts-control").click
    find("#{CARRIER} .dropdown-input").send_keys("R")
    find("#shipment_reference").click
    sleep REFRESH_THROTTLE
    assert_closed CARRIER
    assert_no_focus_in CARRIER
    assert_equal "shipment_reference", page.evaluate_script("document.activeElement.id")
  end

  def test_typing_then_escape_keeps_the_dropdown_closed
    visit "/admin/shipments/new"
    find("#{CARRIER} .ts-control").click
    find("#{CARRIER} .dropdown-input").send_keys("R", :escape)
    sleep REFRESH_THROTTLE
    assert_closed CARRIER
  end

  def test_lazy_select_closed_while_typing_does_not_stay_searching
    visit "/admin/orders/new"
    find("#order_customer_input .ts-control").click
    assert_selector "#order_customer_input .ts-dropdown .option", minimum: 2
    find("#order_customer_input .dropdown-input").send_keys("Cu", :escape)
    sleep REFRESH_THROTTLE
    assert_closed "#order_customer_input"
    assert_no_selector "#order_customer_input .ts-wrapper.searching", wait: false
  end

  def test_typing_still_filters_the_options
    visit "/admin/shipments/new"
    find("#{CARRIER} .ts-control").click
    find("#{CARRIER} .dropdown-input").send_keys("Rail")
    assert_selector "#{CARRIER} .ts-dropdown .option", count: 1
    assert_selector "#{CARRIER} .ts-dropdown .option", exact_text: "Rail"
  end

  def test_page_object_search_and_close_leave_the_next_select_open
    form = ShipmentForm.new.tap(&:load).form
    carrier = form.field(:carrier)
    carrier.fill("Rail")
    carrier.search("Rail")
    find("#{CARRIER} .ts-dropdown .option", exact_text: "Rail").click
    carrier.close
    find("#{PRIORITY} .ts-control").click
    sleep REFRESH_THROTTLE
    assert form.field(:priority).open?
    refute carrier.open?
    assert_open PRIORITY
  end

  def test_page_object_search_and_close_keep_the_dropdown_closed
    carrier = ShipmentForm.new.tap(&:load).form.field(:carrier)
    carrier.search("R")
    carrier.close
    sleep REFRESH_THROTTLE
    refute carrier.open?
    assert_closed CARRIER
  end

  private

  def open_and_pick(wrapper, label, type: nil)
    find("#{wrapper} .ts-control").click
    find("#{wrapper} .dropdown-input").send_keys(type) if type
    find("#{wrapper} .ts-dropdown .option", exact_text: label).click
    assert_no_selector "#{wrapper} .ts-dropdown", visible: true
  end

  def assert_open(wrapper)
    assert_selector "#{wrapper} .ts-dropdown", visible: true
    assert page.evaluate_script("document.querySelector(#{wrapper.to_json}).contains(document.activeElement)"), "focus is outside #{wrapper}"
  end

  def assert_closed(wrapper)
    assert_no_selector "#{wrapper} .ts-dropdown", visible: true, wait: false
  end

  def assert_no_focus_in(wrapper)
    refute page.evaluate_script("document.querySelector(#{wrapper.to_json}).contains(document.activeElement)"), "focus is inside #{wrapper}"
  end
end
