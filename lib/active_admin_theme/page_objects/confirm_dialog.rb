module ActiveAdminTheme
  module PageObjects
    # The `confirm_dialog` component: a trigger button and its modal form.
    # Needs a JavaScript driver.
    #
    #   dialog = page_object.confirm_dialog("Flag customer")
    #   dialog.open
    #   dialog.fill("Reason" => "Chargeback", "Notify customer" => true)
    #   dialog.confirm
    #
    # A dialog rendered with `trigger: false` is found by its id, and `open`
    # clicks the element of the page that points at it:
    #
    #   page_object.confirm_dialog(dialog: "reject-order").open
    class ConfirmDialog < Component
      selector_key :confirm_dialog

      class << self
        # The dialog inside +scope+ whose trigger button reads +trigger+
        # (case-insensitive), the one whose modal has the id +dialog+, or the
        # only dialog when both are nil.
        def find_in(scope, trigger = nil, dialog: nil, **options)
          return super(scope, **options) if trigger.nil? && dialog.nil?

          node = scope.find(*default_search_arguments, **options) do |root|
            next root.has_css?("#{ActiveAdminPageObjects.selector(:confirm_dialog_modal)}[id='#{dialog}']", visible: :all, wait: false) if dialog

            button = root.first(:active_admin, :confirm_dialog_trigger, minimum: 0, wait: false)
            button && ActiveAdminPageObjects.same_text?(button.text, trigger)
          end
          new(scope, node)
        end
      end

      # The text of the trigger button.
      # @return [String]
      def trigger_text
        trigger.text.strip
      end

      # The id of the modal.
      # @return [String]
      def dialog_id
        find(:active_admin, :confirm_dialog_modal, visible: :all)[:id]
      end

      # The button that opens the dialog: the component's own, or with
      # `trigger: false` the element of the page that points at the modal.
      def trigger
        own = first(:active_admin, :confirm_dialog_trigger, minimum: 0, wait: false)
        own || root_element.session.find("[data-modal-show='#{dialog_id}'], [data-modal-toggle='#{dialog_id}']")
      end

      # Clicks the trigger and waits for the dialog.
      def open
        trigger.click unless open?
        modal
        self
      end

      # The hidden fields of `params:`, by name.
      # @return [Hash{String => String}]
      def params
        all(:active_admin, :confirm_dialog_param, visible: :all, wait: false).to_h { |input| [input[:name], input.value] }
      end

      # True when the dialog is on screen. Does not wait.
      def open?
        has_css?(sel(:confirm_dialog_modal), visible: true, wait: false)
      end

      # True when the dialog is on screen.
      def has_open?(**options)
        has_css?(sel(:confirm_dialog_modal), visible: true, **options)
      end

      # Waits until the dialog is closed.
      def has_no_open?(**options)
        has_no_css?(sel(:confirm_dialog_modal), visible: true, **options)
      end

      # The dialog title.
      # @return [String]
      def title
        modal.find(:active_admin, :confirm_dialog_title).text.strip
      end

      # The dialog message, or nil when it has none.
      # @return [String, nil]
      def message
        modal.first(:active_admin, :confirm_dialog_message, minimum: 0, wait: false)&.text&.strip
      end

      # The labels of the dialog fields in document order.
      # @return [Array<String>]
      def field_labels
        modal.all(:active_admin, :confirm_dialog_field, wait: false).map { |field| field.find("label").text.strip }
      end

      # Sets the fields by label: text for a string or text field, the option
      # text for a select, true or false for a boolean.
      def fill(values)
        values.each { |label, value| fill_field(label, value) }
        self
      end

      # Clicks the confirm button, which submits the dialog's form. The
      # browser keeps the dialog open while a required field is empty.
      def confirm
        modal.find(:active_admin, :confirm_dialog_submit).click
      end

      # Clicks the cancel button and waits for the dialog to close.
      def cancel
        modal.find(:active_admin, :confirm_dialog_cancel).click
        has_no_open?
      end

      private

      def modal
        find(:active_admin, :confirm_dialog_modal, visible: true)
      end

      def fill_field(label, value)
        field = modal.find(:active_admin, :confirm_dialog_field) { |node| same_text?(node.find("label").text, label) }
        case field["data-field-type"]
        when "boolean" then field.find("input[type=checkbox]").set(value)
        when "select" then field.find("select").select(value.to_s)
        else field.find("input, textarea").set(value)
        end
      end
    end
  end
end
