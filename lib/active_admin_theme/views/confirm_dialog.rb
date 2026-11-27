require_relative "../helpers/confirm_dialog"

module ActiveAdminTheme
  module Views
    # confirm_dialog "Reject", title: "Reject order", message: "The buyer is notified.",
    #   url: "/admin/orders/1/reject", method: :post, confirm_text: "Reject",
    #   fields: [
    #     {name: :reason, label: "Reason", as: :text, required: true},
    #     {name: :kind, as: :select, collection: [["Fraud", "fraud"], ["Other", "other"]]},
    #     {name: :notify, label: "Notify the buyer", as: :boolean, value: true}
    #   ]
    #
    # confirm_dialog title: "Reject order", url: "/admin/orders/1/reject", id: "reject-order", trigger: false
    #
    # Renders a button and a Flowbite modal (data-modal-target / data-modal-show,
    # which ActiveAdmin already loads) holding a real form that submits to `url`
    # with the CSRF token, and `_method` for put/patch/delete. A block adds
    # content after the fields. Fields also take `input_html:` attributes, and
    # `multiple: true` on a select; `scope: :reject` nests every field name as
    # reject[name]. The README lists the other options. Do not place it inside another form. Load
    # `active_admin_theme/confirm_dialog` (ActiveAdminTheme.javascripts) for focus
    # handling and field validation; texts come from
    # `active_admin_theme.confirm_dialog.*` with English defaults.
    class ConfirmDialog < ActiveAdmin::Component
      builder_method :confirm_dialog

      FIELD_TYPES = %i[string text select boolean number date].freeze

      def tag_name
        "span"
      end

      def build(trigger_text = nil, options = {})
        trigger_text, options = nil, trigger_text if trigger_text.is_a?(Hash)
        super(class: "aat-confirm")
        trigger = options.fetch(:trigger, true)
        raise ArgumentError, "confirm_dialog with trigger: false needs id:" unless trigger || options[:id]
        raise ArgumentError, "confirm_dialog needs the text of its button, or trigger: false" if trigger && trigger_text.nil?

        dialog_id = (options[:id] || "aat-confirm-#{object_id}").to_s
        get = options.fetch(:method, :post).to_s.downcase == "get"
        body = nil

        if trigger
          html = (options[:trigger_html] || {}).dup
          button trigger_text, **html, type: "button", class: ["aat-confirm-trigger", options[:class], html[:class]].compact.join(" "),
                                       "aria-haspopup": "dialog", "data-modal-target": dialog_id, "data-modal-show": dialog_id
        end
        div id: dialog_id, class: "aat-confirm-modal", tabindex: "-1", role: "dialog", "aria-modal": "true",
            "aria-hidden": "true", "aria-labelledby": "#{dialog_id}-title",
            "aria-describedby": (options[:message] ? "#{dialog_id}-message" : nil) do
          div class: "aat-confirm-panel" do
            form action: options.fetch(:url), method: (get ? "get" : "post"), class: "aat-confirm-form", "accept-charset": "UTF-8" do
              build_hidden_inputs(options) unless get
              build_params(options[:params]) if options[:params].present?
              h2 options.fetch(:title), id: "#{dialog_id}-title", class: "aat-confirm-title"
              para options[:message], id: "#{dialog_id}-message", class: "aat-confirm-message" if options[:message]
              body = div(class: "aat-confirm-body") do
                Array(options[:fields]).each { |field| build_field(dialog_id, field, options[:scope]) }
              end
              div class: "aat-confirm-actions" do
                button i18n_text(options[:confirm_text], :confirm, "Confirm"), type: "submit", class: "aat-confirm-submit"
                button i18n_text(options[:cancel_text], :cancel, "Cancel"), type: "button", class: "aat-confirm-cancel", "data-modal-hide": dialog_id
              end
            end
          end
        end
        @body = body
      end

      def add_child(child)
        @body ? @body.add_child(child) : super
      end

      private

      def i18n_text(text, key, default)
        text || I18n.t("active_admin_theme.confirm_dialog.#{key}", default: default)
      end

      def build_hidden_inputs(options)
        input type: "hidden", name: "authenticity_token", value: form_authenticity_token
        verb = options.fetch(:method, :post).to_s.downcase
        input type: "hidden", name: "_method", value: verb unless verb == "post"
      end

      # to_query flattens nested hashes and arrays into Rails' bracketed names.
      def build_params(params)
        params.to_query.split("&").each do |pair|
          name, value = pair.split("=", 2).map { |part| CGI.unescape(part.to_s) }
          input type: "hidden", name: name, value: value, "data-aat-confirm-param": ""
        end
      end

      # A scope nests the field names as Rails does: reason becomes
      # scope[reason], and a bracketed name a[b] becomes scope[a][b].
      def scoped_name(name, scope)
        scope.present? ? name.sub(/\A[^\[]+/) { |head| "#{scope}[#{head}]" } : name
      end

      # The field's input_html attributes, with the ones the component sets winning
      # and the classes joined.
      def control_attributes(field, attributes)
        extra = (field[:input_html] || {}).to_h.symbolize_keys
        extra.merge(attributes.compact) { |key, own, set| (key == :class) ? [set, own].join(" ") : set }
      end

      def build_field(dialog_id, field, scope = nil)
        type = (field[:as] || :string).to_sym
        raise ArgumentError, "confirm_dialog field type must be one of #{FIELD_TYPES.inspect}, got #{type.inspect}" unless FIELD_TYPES.include?(type)

        name = scoped_name(field.fetch(:name).to_s, scope)
        field_id = "#{dialog_id}-#{name.gsub(/[^a-zA-Z0-9]+/, "_").delete_suffix("_")}"
        text = field[:label] || field.fetch(:name).to_s[/(\w+)\]?\z/, 1].to_s.humanize
        required = field[:required] ? "required" : nil
        blank_message = required && i18n_text(nil, :required, "Please fill out this field.")

        div class: "aat-confirm-field", "data-field-type": type, "data-required": ("" if required) do
          case type
          when :boolean
            label for: field_id, class: "aat-confirm-check" do
              input type: "hidden", name: name, value: "0"
              input(**control_attributes(field, type: "checkbox", id: field_id, name: name, value: "1", required: required,
                                                checked: ("checked" if field[:value].present? && field[:value].to_s != "0")))
              span text
            end
          when :select
            label text, for: field_id, class: "aat-confirm-label"
            multiple = field[:multiple]
            select(**control_attributes(field, id: field_id, name: (multiple ? "#{name}[]" : name), required: required,
                                               multiple: ("multiple" if multiple), class: "aat-confirm-input")) do
              option "", value: "" unless multiple
              Array(field[:collection]).each do |item|
                item_text, item_value = item.is_a?(Array) ? item : [item, item]
                chosen = multiple ? Array(field[:value]).map(&:to_s).include?(item_value.to_s) : item_value.to_s == field[:value].to_s
                option item_text, value: item_value, selected: ("selected" if chosen)
              end
            end
          when :text
            label text, for: field_id, class: "aat-confirm-label"
            textarea field[:value].to_s, **control_attributes(field, id: field_id, name: name, rows: 3, required: required,
                                                                     class: "aat-confirm-input", "data-blank-message": blank_message)
          else
            label text, for: field_id, class: "aat-confirm-label"
            input(**control_attributes(field, type: ((type == :string) ? "text" : type.to_s), id: field_id, name: name, value: field[:value],
                                                required: required, class: "aat-confirm-input", autocomplete: "off",
                                                "data-blank-message": (blank_message if type == :string)))
          end
        end
      end
    end
  end
end
