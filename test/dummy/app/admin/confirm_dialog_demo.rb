# Demo of the confirm_dialog component. Every dialog submits to the echo action
# below, which prints the verb and the submitted fields instead of changing data.
ActiveAdmin.register_page "Confirm dialog" do
  menu parent: "Demo pages", priority: 6

  # confirm_dialog_tag builds the component outside an Arbre view; its block
  # body uses Arbre tags as confirm_dialog's does.
  action_item :suspend do
    confirm_dialog_tag "Suspend customer", id: "action-confirm", title: "Suspend customer?", url: "/admin/confirm_dialog/echo",
                                           class: "action-item-button" do
      para "The customer cannot sign in until reactivated.", class: "suspend-note"
    end
  end
  action_item(:export) { link_to "Export customers", "#", class: "action-item-button" }
  action_item(:history) { link_to "Open history", "#", class: "action-item-button" }
  action_item(:notes) { link_to "Customer notes", "#", class: "action-item-button" }

  page_action :echo, method: [:get, :post, :delete] do
    submitted = params.to_unsafe_h.except("authenticity_token", "_method", "controller", "action")
    render plain: "#{request.request_method} #{submitted.to_json}"
  end

  content do
    panel "Plain confirm" do
      confirm_dialog "Archive customer", id: "plain-confirm", title: "Archive customer?",
                                         message: "The customer is hidden from the lists.",
                                         url: "/admin/confirm_dialog/echo", confirm_text: "Archive"
    end

    panel "Confirm with a link" do
      confirm_dialog "Close account", id: "link-confirm", title: "Close account?", url: "/admin/confirm_dialog/echo" do
        a "Read the closing policy", href: "#policy", class: "policy-link"
      end
    end

    panel "Confirm with fields" do
      confirm_dialog "Flag customer", id: "fields-confirm", title: "Flag customer", url: "/admin/confirm_dialog/echo",
                                      confirm_text: "Send",
                                      fields: [
                                        {name: :reason, label: "Reason", as: :text, required: true},
                                        {name: :title, label: "Short title", as: :string},
                                        {name: :priority, label: "Priority", as: :select, collection: [["Low", "low"], ["High", "high"]]},
                                        {name: :notify, label: "Notify customer", as: :boolean}
                                      ]
    end

    panel "Confirm with body controls" do
      confirm_dialog "Reject template", id: "body-confirm", title: "Reject template?", url: "/admin/confirm_dialog/echo" do
        label "Preset", for: "reject-preset"
        select id: "reject-preset", name: "preset" do
          option "Spam", value: "spam"
          option "Abuse", value: "abuse"
        end
        textarea "", name: "reason", required: true, "aria-label": "Reason"
      end
    end

    panel "Submit with a method" do
      confirm_dialog "Delete customer", id: "delete-confirm", title: "Delete customer?",
                                        message: "This cannot be undone.",
                                        url: "/admin/confirm_dialog/echo", method: :delete, confirm_text: "Delete"
    end

    panel "Opened from elsewhere" do
      text_node confirm_dialog_trigger("Merge customers", "external-confirm", id: "external-trigger")
      confirm_dialog id: "external-confirm", trigger: false, title: "Merge customers?", url: "/admin/confirm_dialog/echo",
                     params: {source: "list", ids: [3, 4], options: {keep: "newest"}}
      confirm_dialog "Search customers", id: "get-confirm", title: "Search?", url: "/admin/confirm_dialog/echo", method: :get,
                                         params: {scope: "active"}
    end
  end
end
