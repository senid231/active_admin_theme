# Browser test (headless Chrome): the page objects of the searchable select
# wait for a dependent select that is still loading, and type into a multiple
# select without closing it.
require_relative "page_objects_helper"

class PageObjectsSearchableSelectReadyTest < PageObjectsTestCase
  LOADING = "select[data-searchable-select-loading]".freeze

  class Lab < ActiveAdminPageObjects::Page
    set_url "/admin/dependent_lab"

    section :several, ActiveAdminPageObjects::Form, "#lab-several"
    section :auto, ActiveAdminPageObjects::Form, "#lab-auto"
    section :chain, ActiveAdminPageObjects::Form, "#lab-chain"
  end

  # Cuprite 0.17 and older click an input that has the focus and no selection
  # before they type. The locked version types straight away.
  module ClickBeforeTyping
    class << self
      attr_accessor :on
    end

    def send_keys(*keys)
      return super unless ClickBeforeTyping.on

      click
      driver.browser.keyboard.type(keys)
    end
  end
  Capybara::Cuprite::Node.prepend(ClickBeforeTyping)

  def teardown
    ClickBeforeTyping.on = false
    super
  end

  def lab
    Lab.new.tap(&:load)
  end

  # Every request the page makes from now on answers +seconds+ later.
  def slow_fetch(seconds)
    page.execute_script(<<~JS, seconds * 1000)
      const original = window.fetch
      const delay = arguments[0]
      window.fetch = (...args) => new Promise((resolve) => setTimeout(resolve, delay)).then(() => original(...args))
    JS
  end

  def test_child_is_picked_while_its_parent_still_loads_and_picks_itself
    form = lab.chain
    slow_fetch(1)
    form.field(:country).fill("Country 05")
    form.field(:street).fill("Country 05 City 1 Street 2")
    assert_equal "Country 05 City 1", form.field(:city).selected
    assert_equal "Country 05 City 1 Street 2", form.field(:street).selected
  end

  def test_auto_selected_option_is_picked_again_right_after_the_parent
    form = lab.auto
    slow_fetch(1)
    form.field(:country).fill("Country 05")
    form.field(:city).fill("Country 05 City 1")
    assert_equal "Country 05 City 1", form.field(:city).selected
    refute form.field(:city).open?
  end

  def test_wait_until_ready_waits_for_the_auto_select
    form = lab.auto
    city = form.field(:city)
    assert city.ready?
    slow_fetch(2)
    form.field(:country).fill("Country 05")
    refute city.ready?
    assert_same city, city.wait_until_ready
    assert city.ready?
    assert_equal "Country 05 City 1", city.selected
  end

  def test_child_is_not_ready_while_its_parent_loads
    form = lab.chain
    street = form.field(:street)
    slow_fetch(1)
    form.field(:country).fill("Country 05")
    refute street.ready?
    street.wait_until_ready
    refute street.disabled?
    assert_equal ["Country 05 City 1 Street 1", "Country 05 City 1 Street 2"], street.options
  end

  def test_wait_until_ready_raises_when_the_select_stays_loading
    form = lab.auto
    slow_fetch(3)
    form.field(:country).fill("Country 05")
    assert_raises(Capybara::ExpectationNotMet) { form.field(:city).wait_until_ready(wait: 0.2) }
  end

  def test_loading_attribute_follows_the_fetch
    form = lab.chain
    assert_no_selector LOADING, visible: :all
    slow_fetch(1)
    form.field(:country).fill("Country 05")
    assert_selector "#lab-chain #{LOADING}", visible: :all, count: 2
    assert_no_selector LOADING, visible: :all
    # An emptied parent leaves the children waiting for it, with nothing to load.
    form.field(:country).clear
    assert form.field(:city).disabled?
    assert_no_selector LOADING, visible: :all, wait: false
  end

  def test_loading_attribute_goes_when_the_parent_is_emptied_before_the_fetch_starts
    form = lab.auto
    page.execute_script(<<~JS, Country.find_by!(name: "Country 05").id.to_s)
      const country = document.querySelector("select[name='order[country_id]']").tomselect
      country.addOption({id: arguments[0], text: "Country 05"})
      country.setValue(arguments[0])
      country.clear()
    JS
    assert form.field(:city).disabled?
    # Tom Select starts a load 300 ms after it was asked to.
    sleep 0.6
    assert_no_selector LOADING, visible: :all, wait: false
    assert form.field(:city).ready?
  end

  def test_dropdown_opens_when_the_select_is_enabled_after_the_first_click
    form = Pages::OrderForm.new.tap { |form_page| form_page.load(action: "new") }.form
    page.execute_script(<<~JS)
      const status = document.querySelector("select[name='order[status]']").tomselect
      status.disable()
      setTimeout(() => status.enable(), 1000)
    JS
    form.field(:status).fill("paid")
    assert_equal "paid", form.field(:status).selected
  end

  def test_loading_attribute_goes_when_the_request_fails
    form = lab.auto
    page.execute_script(<<~JS)
      const original = window.fetch
      window.fetch = (url, ...rest) => {
        if (!String(url).includes("capitals_options")) return original(url, ...rest)
        return new Promise((resolve, reject) => setTimeout(() => reject(new Error("down")), 500))
      }
    JS
    form.field(:country).fill("Country 05")
    assert_selector "#lab-auto #{LOADING}", visible: :all
    form.field(:city).wait_until_ready
    assert_nil form.field(:city).selected
  end

  def test_multiple_select_takes_the_typed_text_when_the_driver_clicks_first
    ClickBeforeTyping.on = true
    country = lab.several.field(:country)
    country.search("Country 05")
    assert country.open?
    assert_equal ["Country 05"], country.options
  end

  def test_multiple_select_is_filled_when_the_driver_clicks_first
    ClickBeforeTyping.on = true
    country = lab.several.field(:country)
    country.fill(["Country 05", "Country 06"])
    assert_equal ["Country 05", "Country 06"], country.chosen
  end

  def test_single_select_is_filled_when_the_driver_clicks_first
    ClickBeforeTyping.on = true
    form = lab.auto
    form.field(:customer).fill("Customer 17")
    assert_equal "Customer 17", form.field(:customer).selected
    form.field(:country).fill("Country 05")
    assert_equal "Country 05", form.field(:country).selected
  end
end
