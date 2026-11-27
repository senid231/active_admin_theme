# Browser test (headless Chrome): the page objects of the theme's components.
require_relative "page_objects_helper"

class PageObjectsComponentsTest < PageObjectsTestCase
  def customer_show(id = 2)
    Pages::CustomerShow.new.tap { |show| show.load(id: id) }
  end

  def test_status_tag_text_and_kind
    index = Pages::CustomerIndex.new
    index.load
    tag = Theme::StatusTag.find_in(index.table.row(2).cell(:status))
    assert_equal "Pending", tag.text
    assert tag.has_text?("PENDING")
    assert tag.has_text?("pend")
    assert tag.has_text?("pending", exact: true)
    refute tag.has_text?("pend", exact: true, wait: 0)
    assert tag.has_no_text?("active")
    refute tag.has_no_text?("pending", wait: 0)
    assert tag.has_text?(/PEND/)
    assert_equal "pending", tag.kind
    assert_nil tag.color
    assert_equal "active", Theme::StatusTag.find_in(customer_show(1).attributes_table.row(:status)).kind

    components = Pages::Components.new
    components.load
    tags = Theme::StatusTag.all_in(components.panel("Status tags").body)
    assert_equal %w[ok warning error info empty yes shipped unstyled green orange red blue no late], tags.map(&:kind)
    assert_equal "#b91c1c", tags.last.color
  end

  def test_warning_flash_renders_and_is_found_by_type
    visit "/admin/components/warning"
    flashes = Pages::Components.new.flashes
    assert flashes.has_flash?(:warning, "Check the dates")
    assert flashes.has_flash?(:notice, "Saved")
    assert_equal ["Check the dates\nbefore you export"], flashes.messages(:warning)
    color = page.evaluate_script("getComputedStyle(document.querySelector('.aat-flash[data-flash=warning]')).backgroundColor")
    assert_equal "rgb(189, 188, 69)", color
    assert_raises(ArgumentError) { flashes.has_flash?(:unregistered) }
  end

  def test_unknown_flash_type_renders_gray_and_can_be_registered
    visit "/admin/components/warning?extra=info"
    color = page.evaluate_script("getComputedStyle(document.querySelector('.aat-flash[data-flash=info]')).backgroundColor")
    assert_equal "rgb(112, 118, 129)", color
    ActiveAdminTheme::PageObjects.register_flash_type(:info)
    assert Pages::Components.new.flashes.has_flash?(:info, "For your information")
  end

  def test_attributes_table_of_one_record_has_table_roles
    customer_show
    assert_selector ".attributes-table > table[role=table] tr[role=row][data-row=name] > th[role=rowheader] + td[role=cell]"
  end

  def test_truncate_text_reads_the_full_text
    index = Pages::CustomerIndex.new
    index.load
    note = Theme::TruncateText.find_in(index.table.row(2).cell(:notes))
    assert_equal "Note for customer...", note.text
    assert_equal Customer.find(2).notes.strip, note.full_text.strip
    assert note.cut?

    components = Pages::Components.new
    components.load
    refute Theme::TruncateText.find_in(components.find("#truncate-default")).cut?
  end

  def test_truncate_text_tells_when_css_clips_it
    components = Pages::Components.new
    components.load
    narrow = Theme::TruncateText.find_in(components.find("#truncate-narrow"))
    refute narrow.cut?
    assert narrow.clipped?
    refute Theme::TruncateText.find_in(components.find("#truncate-length")).clipped?
    assert Theme::TruncateText.find_in(components.find("#truncate-popup")).clipped?
  end

  def test_truncate_text_reads_and_shows_its_popup
    components = Pages::Components.new
    components.load
    plain = Theme::TruncateText.find_in(components.find("#truncate-default"))
    refute plain.popup?
    text = Theme::TruncateText.find_in(components.find("#truncate-popup"))
    assert text.popup?
    assert_match(/so it is cut\.\z/, text.full_text)
    assert text.has_no_popup?(wait: false)
    assert_equal text.full_text, text.show_popup
    assert text.has_popup?
  end

  def test_confirm_dialog_without_a_trigger_is_found_by_its_id
    dialogs = Pages::ConfirmDialogs.new
    dialogs.load
    dialog = dialogs.confirm_dialog(dialog: "external-confirm")
    assert_equal "external-confirm", dialog.dialog_id
    assert_equal({"source" => "list", "ids[]" => "4", "options[keep]" => "newest"}, dialog.params)
    assert_equal "Merge customers", dialog.trigger_text
    dialog.open
    assert_equal "Merge customers?", dialog.title
    dialog.cancel
    assert dialog.has_no_open?
  end

  def test_secret_reveal_shows_and_hides_the_value
    secret = Theme::SecretReveal.find_in(customer_show.attributes_table.row(:token))
    refute secret.revealed?
    assert_nil secret.value
    assert_equal "••••••••", secret.mask
    assert_equal "token-2", secret.reveal
    assert secret.revealed?
    assert_equal "token-2", secret.value
    secret.hide
    refute secret.revealed?
    assert_equal secret.mask, secret.text
  end

  def test_secret_reveal_reports_a_failed_request
    components = Pages::Components.new
    components.load
    page.execute_script("document.querySelector('#secret [data-aat-secret-reveal]').dataset.url = '/admin/components/forbidden'")
    secret = Theme::SecretReveal.find_in(components.panel("Secret reveal"))
    error = assert_raises(Capybara::ExpectationNotMet) { secret.reveal }
    assert_match(/Could not load the value/, error.message)
    assert_match(/HTTP 403/, secret.error)
    refute secret.revealed?
  end

  def test_tooltip_reads_the_plain_and_the_html_tooltip
    balance = Theme::Tooltip.find_in(customer_show.attributes_table.row(:balance))
    assert_equal "137.5", balance.text
    assert_equal "Current balance", balance.tooltip
    refute balance.html?

    components = Pages::Components.new
    components.load
    rich = Theme::Tooltip.find_in(components.find("#tooltip-html"))
    assert rich.html?
    assert_match(/\ARich tooltip/, rich.tooltip)
    assert rich.hover.has_shown?
  end

  def test_pre_wrap_keeps_the_lines
    show = customer_show
    show.tabs.select("Raw")
    lines = Theme::PreWrap.find_in(show.tabs.content).lines
    assert_includes lines, "name: Customer 2"
    assert_includes lines, "email: customer2@example.com"
  end

  def test_columns
    show = customer_show
    assert_equal [1, 2], show.columns.weights
    assert_equal 2, show.columns.columns.size
    assert show.columns.columns.first.has_css?(".attributes-table")
    assert show.columns.columns.last.has_css?(".aat-tabs")

    demo = Pages::ColumnsDemo.new
    demo.load
    rows = Theme::Columns.all_in(demo)
    assert_equal [[1, 3], [1, 1], [1, 1, 1], [2, 1], [1, 1, 1, 1, 1, 1]], rows.map(&:weights)
  end

  def test_confirm_dialog_opens_and_cancels
    dialogs = Pages::ConfirmDialogs.new
    dialogs.load
    dialog = dialogs.confirm_dialog("Archive customer")
    assert_equal "Archive customer", dialog.trigger_text
    refute dialog.open?
    dialog.open
    assert dialog.has_open?
    assert_equal "Archive customer?", dialog.title
    assert_equal "The customer is hidden from the lists.", dialog.message
    assert_empty dialog.field_labels
    dialog.cancel
    assert dialog.has_no_open?
    assert_equal "/admin/confirm_dialog", page.current_path
  end

  def test_confirm_dialog_fills_its_fields_and_submits
    dialogs = Pages::ConfirmDialogs.new
    dialogs.load
    dialog = dialogs.confirm_dialog("Flag customer").open
    assert_equal ["Reason", "Short title", "Priority", "Notify customer"], dialog.field_labels
    assert_nil dialog.message
    dialog.confirm
    assert dialog.has_open?, "a required field keeps the dialog open"

    dialog.fill("Reason" => "Chargeback", "Short title" => "Fraud", "Priority" => "High", "Notify customer" => true)
    dialog.confirm
    assert_text 'POST {"reason":"Chargeback","title":"Fraud","priority":"high","notify":"1"}'
  end

  def test_confirm_dialog_drives_the_controls_of_its_body
    dialogs = Pages::ConfirmDialogs.new
    dialogs.load
    dialog = dialogs.confirm_dialog("Reject template").open
    assert_empty dialog.field_labels
    dialog.fill("Preset" => "Abuse")
    dialog.confirm
    assert dialog.has_open?, "the required textarea keeps the dialog open"
    dialog.confirm(validate: false)
    assert_text 'POST {"preset":"abuse","reason":""}'

    dialogs.load
    dialog = dialogs.confirm_dialog("Reject template").open
    dialog.fill("reason" => "Spam text", "reject-preset" => "Spam")
    assert_equal "Spam text", dialog.field("reason").value
    dialog.confirm
    assert_text 'POST {"preset":"spam","reason":"Spam text"}'
  end

  def test_confirm_dialog_submits_with_its_method
    dialogs = Pages::ConfirmDialogs.new
    dialogs.load
    dialogs.confirm_dialog("Delete customer").open.confirm
    assert_text "DELETE {}"
    dialogs.load
    assert_raises(Capybara::Ambiguous) { dialogs.confirm_dialog }
    assert_equal "Suspend customer", dialogs.confirm_dialog(dialog: "action-confirm").trigger_text
  end
end
