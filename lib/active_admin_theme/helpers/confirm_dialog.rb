module ActiveAdminTheme
  module Helpers
    module ConfirmDialog
      # The confirm_dialog component as an HTML string, for ERB and for blocks
      # that return one, such as `action_item`. Takes the arguments of
      # `confirm_dialog`; a block returns HTML to add after the fields.
      def confirm_dialog_tag(trigger_text = nil, **options, &block)
        arguments = [trigger_text, options].compact
        Arbre::Context.new({}, self) { confirm_dialog(*arguments, &block) }.to_s.html_safe
      end

      # A button that opens the confirm_dialog rendered with `id: dialog_id`
      # and `trigger: false`.
      def confirm_dialog_trigger(text, dialog_id, **html_options)
        html_options[:class] = ["aat-confirm-trigger", html_options[:class]].compact.join(" ")
        content_tag(:button, text, **html_options, type: "button", "aria-haspopup": "dialog",
          data: (html_options[:data] || {}).merge(modal_target: dialog_id, modal_show: dialog_id))
      end
    end
  end
end

ActiveSupport.on_load(:action_view) { include ActiveAdminTheme::Helpers::ConfirmDialog }
