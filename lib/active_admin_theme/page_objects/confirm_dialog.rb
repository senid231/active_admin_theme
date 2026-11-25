module ActiveAdminTheme
  module PageObjects
    # The `confirm_dialog` component: a trigger button and its modal form.
    # Needs a JavaScript driver.
    #
    #   dialog = page_object.confirm_dialog("Flag customer")
    #   dialog.open
    #   dialog.fill("Reason" => "Chargeback", "Notify customer" => true)
    #   dialog.confirm
    class ConfirmDialog < Component
      selector_key :confirm_dialog

      class << self
        # The dialog inside +scope+ whose trigger button reads +trigger+
        # (case-insensitive), or the only dialog when +trigger+ is nil.
        def find_in(scope, trigger = nil, **options)
          return super(scope, **options) if trigger.nil?

          node = scope.find(*default_search_arguments, **options) do |dialog|
            button = dialog.first(:active_admin, :confirm_dialog_trigger, minimum: 0, wait: false)
            button && ActiveAdminPageObjects.same_text?(button.text, trigger)
          end
          new(scope, node)
        end
      end

      # The text of the trigger button.
      # @return [String]
      def trigger_text
        find(:active_admin, :confirm_dialog_trigger).text.strip
      end

      # Clicks the trigger and waits for the dialog.
      def open
        find(:active_admin, :confirm_dialog_trigger).click unless open?
        modal
        self
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
